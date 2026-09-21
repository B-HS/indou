import AppKit
import CoreImage
import CoreMedia
import IndouKit
import Observation
import ScreenCaptureKit

private final class StreamFrameReceiver: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let lock = NSLock()
    private var continuation: CheckedContinuation<CGImage?, Never>?
    private var image: CGImage?
    private var isFinished = false

    func firstFrame(timeout: Duration) async -> CGImage? {
        let timeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(for: timeout)
            } catch {
                return
            }
            self?.finish(with: nil)
        }
        let image = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                lock.lock()
                if isFinished {
                    let image = self.image
                    lock.unlock()
                    continuation.resume(returning: image)
                    return
                }
                self.continuation = continuation
                lock.unlock()
            }
        } onCancel: {
            self.finish(with: nil)
        }
        timeoutTask.cancel()
        return image
    }

    func cancel() {
        finish(with: nil)
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid, CMSampleBufferDataIsReady(sampleBuffer) else { return }
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let statusValue = attachments.first?[.status] as? Int,
              SCFrameStatus(rawValue: statusValue) == .complete,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let source = CIImage(cvPixelBuffer: pixelBuffer)
        guard let image = context.createCGImage(source, from: source.extent) else { return }
        finish(with: image)
    }

    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        finish(with: nil)
    }

    private func finish(with image: CGImage?) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        isFinished = true
        self.image = image
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(returning: image)
    }
}

@MainActor
@Observable
final class ThumbnailStore {
    private struct WindowFingerprint: Equatable {
        let pid: pid_t?
        let title: String?
        let frame: CGRect
    }

    private struct CaptureRequest {
        let id: WindowID
        let pointSize: CGSize
        let scale: CGFloat
        let fingerprint: WindowFingerprint
    }

    private static let captureDelay: Duration = .milliseconds(150)
    private static let frameTimeout: Duration = .seconds(1)
    private static let outputQueue = DispatchQueue(label: "com.hyunseokbyun.indou.thumbnail-stream", qos: .utility)

    private(set) var images: [WindowID: NSImage] = [:]

    @ObservationIgnored private var fingerprints: [WindowID: WindowFingerprint] = [:]
    @ObservationIgnored private var scWindows: [WindowID: SCWindow] = [:]
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var pending: [CaptureRequest] = []
    @ObservationIgnored private var scheduled: Set<WindowID> = []
    @ObservationIgnored private var activeTask: Task<Void, Never>?

    func updateContent(_ windows: [WindowID: SCWindow], keeping windowIDs: Set<WindowID>) {
        scWindows = windows
        let validCachedIDs = Set(images.keys).filter { id in
            guard windowIDs.contains(id), let window = windows[id], let fingerprint = fingerprints[id] else { return false }
            return fingerprint == Self.fingerprint(for: window)
        }
        images = images.filter { validCachedIDs.contains($0.key) }
        fingerprints = fingerprints.filter { validCachedIDs.contains($0.key) }
    }

    func requestThumbnails(for ids: [WindowID], pointSize: CGSize, scale: CGFloat) {
        let pixelSize = NSSize(width: max(1, Int(pointSize.width * scale)), height: max(1, Int(pointSize.height * scale)))
        for id in ids {
            guard let window = scWindows[id] else { continue }
            let fingerprint = Self.fingerprint(for: window)
            if images[id]?.size == pixelSize, fingerprints[id] == fingerprint { continue }
            images.removeValue(forKey: id)
            fingerprints.removeValue(forKey: id)
            guard !scheduled.contains(id) else { continue }
            scheduled.insert(id)
            pending.append(
                CaptureRequest(
                    id: id,
                    pointSize: pointSize,
                    scale: scale,
                    fingerprint: fingerprint
                )
            )
        }
        startWorkerIfNeeded()
    }

    func cancelPendingCaptures() {
        let tasks = invalidatePendingCaptures()
        for task in tasks { task.cancel() }
    }

    func capturesToFinishBeforeFocus() -> [Task<Void, Never>] {
        let tasks = invalidatePendingCaptures()
        for task in tasks { task.cancel() }
        return tasks
    }

    private func startWorkerIfNeeded() {
        guard activeTask == nil, !pending.isEmpty else { return }
        let taskGeneration = generation
        activeTask = Task {
            do {
                try await Task.sleep(for: Self.captureDelay)
            } catch {
                finishWorker(generation: taskGeneration)
                return
            }
            await runCaptureQueue(generation: taskGeneration)
        }
    }

    private func runCaptureQueue(generation taskGeneration: Int) async {
        while !Task.isCancelled, taskGeneration == generation, !pending.isEmpty {
            let request = pending.removeFirst()
            let image = await capture(request)
            guard !Task.isCancelled, taskGeneration == generation else { break }
            scheduled.remove(request.id)
            if let image {
                images[request.id] = image
                fingerprints[request.id] = request.fingerprint
            }
        }
        finishWorker(generation: taskGeneration)
    }

    private func finishWorker(generation taskGeneration: Int) {
        activeTask = nil
        guard taskGeneration == generation else {
            startWorkerIfNeeded()
            return
        }
        startWorkerIfNeeded()
    }

    private func invalidatePendingCaptures() -> [Task<Void, Never>] {
        generation += 1
        pending.removeAll(keepingCapacity: true)
        scheduled.removeAll(keepingCapacity: true)
        guard let activeTask else { return [] }
        return [activeTask]
    }

    private func capture(_ request: CaptureRequest) async -> NSImage? {
        guard !Task.isCancelled, let window = scWindows[request.id] else { return nil }

        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(request.pointSize.width * request.scale))
        configuration.height = max(1, Int(request.pointSize.height * request.scale))
        configuration.scalesToFit = true
        configuration.ignoreShadowsSingleWindow = true
        configuration.showsCursor = false
        configuration.queueDepth = 1

        let receiver = StreamFrameReceiver()
        let stream = SCStream(
            filter: SCContentFilter(desktopIndependentWindow: window),
            configuration: configuration,
            delegate: receiver
        )

        do {
            try stream.addStreamOutput(receiver, type: .screen, sampleHandlerQueue: Self.outputQueue)
            try await withTaskCancellationHandler {
                try await stream.startCapture()
            } onCancel: {
                receiver.cancel()
            }
            let cgImage = await receiver.firstFrame(timeout: Self.frameTimeout)
            do {
                try await stream.stopCapture()
            } catch {
                if !Task.isCancelled {
                    Log.capture.debug("stream stop failed for \(request.id): \(String(describing: error))")
                }
            }
            guard !Task.isCancelled, let cgImage else { return nil }
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        } catch {
            receiver.cancel()
            try? await stream.stopCapture()
            if !(error is CancellationError), !Task.isCancelled {
                Log.capture.debug("stream capture failed for \(request.id): \(String(describing: error))")
            }
            return nil
        }
    }

    private static func fingerprint(for window: SCWindow) -> WindowFingerprint {
        WindowFingerprint(pid: window.owningApplication?.processID, title: window.title, frame: window.frame)
    }
}
