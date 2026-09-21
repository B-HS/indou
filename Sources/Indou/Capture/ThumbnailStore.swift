import AppKit
import IndouKit
import Observation
import ScreenCaptureKit

/// Captures and caches per-window thumbnails via ScreenCaptureKit. The grid
/// observes `images`; each capture fills in asynchronously so the switcher shows
/// instantly (icon placeholder) and upgrades to a live thumbnail as frames land.
/// Concurrency is bounded and a session end abandons queued and running captures.
@MainActor
@Observable
final class ThumbnailStore {
    private struct CaptureRequest {
        let id: WindowID
        let pointSize: CGSize
        let scale: CGFloat
    }

    private struct ActiveCapture {
        let task: Task<Void, Never>
    }

    private(set) var images: [WindowID: NSImage] = [:]

    @ObservationIgnored private var scWindows: [WindowID: SCWindow] = [:]
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var pending: [CaptureRequest] = []
    @ObservationIgnored private var scheduled: Set<WindowID> = []
    @ObservationIgnored private var activeTasks: [Int: ActiveCapture] = [:]
    @ObservationIgnored private var nextTaskToken = 0
    @ObservationIgnored private var concurrencyLimit = 1

    /// Refresh the SCWindow lookup once per switcher session. On failure the
    /// stale lookup is dropped so a vanished SCWindow is never captured.
    func refreshContent() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            scWindows = Dictionary(content.windows.map { ($0.windowID, $0) }, uniquingKeysWith: { a, _ in a })
        } catch {
            scWindows.removeAll(keepingCapacity: true)
            Log.capture.error("refreshContent failed: \(String(describing: error))")
        }
    }

    /// Request thumbnails for the given windows at the given point size, running
    /// at most `maxConcurrent` (clamped to 1...8) captures at a time. Request
    /// order is preserved; already cached or already scheduled ids are skipped.
    func requestThumbnails(for ids: [WindowID], pointSize: CGSize, scale: CGFloat, maxConcurrent: Int) {
        concurrencyLimit = min(8, max(1, maxConcurrent))
        for id in ids where images[id] == nil && !scheduled.contains(id) {
            guard scWindows[id] != nil else { continue }
            scheduled.insert(id)
            pending.append(CaptureRequest(id: id, pointSize: pointSize, scale: scale))
        }
        startQueuedCaptures()
    }

    /// Abandon the current session's queued and running captures while keeping
    /// the image cache. Running tasks are cancelled but stay counted until they
    /// actually finish, so a following session cannot exceed the concurrency
    /// limit while ScreenCaptureKit ignores the cancellation.
    func cancelPendingCaptures() {
        generation += 1
        pending.removeAll(keepingCapacity: true)
        scheduled.removeAll(keepingCapacity: true)
        for capture in activeTasks.values {
            capture.task.cancel()
        }
    }

    func clear() {
        cancelPendingCaptures()
        images.removeAll(keepingCapacity: true)
        scWindows.removeAll(keepingCapacity: true)
    }

    private func startQueuedCaptures() {
        while activeTasks.count < concurrencyLimit, !pending.isEmpty {
            let request = pending.removeFirst()
            let token = nextTaskToken
            nextTaskToken += 1
            let taskGeneration = generation
            let task = Task { await self.capture(request, token: token, generation: taskGeneration) }
            activeTasks[token] = ActiveCapture(task: task)
        }
    }

    private func capture(_ request: CaptureRequest, token: Int, generation taskGeneration: Int) async {
        guard !Task.isCancelled, let window = scWindows[request.id] else {
            finishCapture(token: token, id: request.id, generation: taskGeneration, image: nil)
            return
        }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        let pixelWidth = max(1, Int(request.pointSize.width * request.scale))
        let pixelHeight = max(1, Int(request.pointSize.height * request.scale))
        config.width = pixelWidth
        config.height = pixelHeight
        config.scalesToFit = true
        config.ignoreShadowsSingleWindow = true
        config.showsCursor = false

        do {
            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            guard !Task.isCancelled else {
                finishCapture(token: token, id: request.id, generation: taskGeneration, image: nil)
                return
            }
            let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            finishCapture(token: token, id: request.id, generation: taskGeneration, image: image)
        } catch {
            if !(error is CancellationError), !Task.isCancelled {
                Log.capture.debug("capture failed for \(request.id): \(String(describing: error))")
            }
            finishCapture(token: token, id: request.id, generation: taskGeneration, image: nil)
        }
    }

    private func finishCapture(token: Int, id: WindowID, generation taskGeneration: Int, image: NSImage?) {
        activeTasks.removeValue(forKey: token)
        if taskGeneration == generation {
            scheduled.remove(id)
            if let image {
                images[id] = image
            }
        }
        startQueuedCaptures()
    }
}
