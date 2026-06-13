import AppKit
import IndouKit
import Observation
import ScreenCaptureKit

/// Captures and caches per-window thumbnails via ScreenCaptureKit. The grid
/// observes `images`; each capture fills in asynchronously so the switcher shows
/// instantly (icon placeholder) and upgrades to a live thumbnail as frames land.
@MainActor
@Observable
final class ThumbnailStore {
    private(set) var images: [WindowID: NSImage] = [:]

    @ObservationIgnored private var scWindows: [WindowID: SCWindow] = [:]
    @ObservationIgnored private var inFlight: Set<WindowID> = []

    /// Refresh the SCWindow lookup once per switcher session.
    func refreshContent() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            scWindows = Dictionary(content.windows.map { ($0.windowID, $0) }, uniquingKeysWith: { a, _ in a })
        } catch {
            Log.capture.error("refreshContent failed: \(String(describing: error))")
        }
    }

    /// Request thumbnails for the visible windows at the given point size.
    func requestThumbnails(for ids: [WindowID], pointSize: CGSize, scale: CGFloat) {
        for id in ids where images[id] == nil && !inFlight.contains(id) {
            guard let window = scWindows[id] else { continue }
            inFlight.insert(id)
            Task { await capture(window, pointSize: pointSize, scale: scale) }
        }
    }

    func clear() {
        images.removeAll(keepingCapacity: true)
        inFlight.removeAll(keepingCapacity: true)
    }

    private func capture(_ window: SCWindow, pointSize: CGSize, scale: CGFloat) async {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        let pixelWidth = max(1, Int(pointSize.width * scale))
        let pixelHeight = max(1, Int(pointSize.height * scale))
        config.width = pixelWidth
        config.height = pixelHeight
        config.scalesToFit = true
        config.ignoreShadowsSingleWindow = true
        config.showsCursor = false

        do {
            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            images[window.windowID] = image
        } catch {
            Log.capture.debug("capture failed for \(window.windowID): \(String(describing: error))")
        }
        inFlight.remove(window.windowID)
    }
}
