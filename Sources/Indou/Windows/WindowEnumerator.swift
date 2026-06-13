import AppKit
import ApplicationServices
import IndouKit
import PrivateWindowServer
import ScreenCaptureKit

/// A switchable window plus the live `AXUIElement` the app layer needs for
/// focus/close/minimize actions (kept out of the pure `WindowState`).
struct LiveWindow: Sendable {
    var state: WindowState
    nonisolated(unsafe) var axElement: AXUIElement?
}

/// Collects all switchable windows by unioning ScreenCaptureKit's on-screen list
/// (accurate ids, frames, titles, owning app) with a per-app Accessibility pass
/// (minimized state, subrole, and the `AXUIElement` for actions, plus minimized
/// windows that ScreenCaptureKit omits). Deduplicated by CGWindowID.
@MainActor
final class WindowEnumerator {
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private var creationOrder: [WindowID: Int] = [:]
    private var nextCreation = 0

    func enumerate() async -> [LiveWindow] {
        let scWindows = await fetchShareableWindows()
        let axByWindowID = collectAccessibilityWindows()
        let scByID = Dictionary(scWindows.map { ($0.windowID, $0) }, uniquingKeysWith: { a, _ in a })
        let pidsWithStandardWindow = Set(axByWindowID.values.filter { $0.isStandardWindow == true }.map(\.pid))

        var merged: [WindowID: LiveWindow] = [:]

        // 1. Authoritative source: AX standard windows of regular apps (includes
        //    minimized / fullscreen / off-screen windows ScreenCaptureKit omits).
        for (id, ax) in axByWindowID {
            guard ax.isStandardWindow == true, ax.pid != ownPID else { continue }
            let sc = scByID[id]
            let scTitle = sc?.title ?? ""
            let axTitle = ax.title ?? ""
            var state = WindowState(
                id: id,
                title: scTitle.isEmpty ? axTitle : scTitle,
                appName: ax.appName,
                appBundleID: ax.bundleID,
                pid: ax.pid,
                isMinimized: ax.isMinimized,
                isFullscreen: ax.isFullscreen,
                isOnScreen: sc?.isOnScreen ?? !ax.isMinimized,
                frame: sc?.frame ?? ax.frame ?? .zero,
                windowLevel: sc?.windowLayer ?? 0
            )
            state.creationOrder = creation(for: id)
            merged[id] = LiveWindow(state: state, axElement: ax.element)
        }

        // 2. Fallback only for regular apps whose AX exposed no standard window
        //    (apps with poor AX support). Strictly gated: on-screen, titled, sized,
        //    layer-0, regular activation policy — so background agents never appear.
        for sc in scWindows {
            let id = sc.windowID
            guard merged[id] == nil, sc.windowLayer == 0, sc.isOnScreen else { continue }
            guard let app = sc.owningApplication, app.processID != ownPID else { continue }
            guard !pidsWithStandardWindow.contains(app.processID) else { continue }
            guard let running = NSRunningApplication(processIdentifier: app.processID),
                  running.activationPolicy == .regular else { continue }
            let title = sc.title ?? ""
            guard !title.isEmpty, sc.frame.width >= 80, sc.frame.height >= 80 else { continue }

            var state = WindowState(
                id: id,
                title: title,
                appName: app.applicationName,
                appBundleID: app.bundleIdentifier,
                pid: app.processID,
                isOnScreen: true,
                frame: sc.frame,
                windowLevel: sc.windowLayer
            )
            state.creationOrder = creation(for: id)
            merged[id] = LiveWindow(state: state, axElement: nil)
        }

        return Array(merged.values)
    }

    private func creation(for id: WindowID) -> Int {
        if let existing = creationOrder[id] { return existing }
        nextCreation += 1
        creationOrder[id] = nextCreation
        return nextCreation
    }

    private func fetchShareableWindows() async -> [SCWindow] {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            return content.windows
        } catch {
            Log.windows.error("SCShareableContent failed: \(String(describing: error))")
            return []
        }
    }

    // MARK: - Accessibility pass

    private struct AXWindowInfo {
        nonisolated(unsafe) let element: AXUIElement
        let pid: pid_t
        let appName: String
        let bundleID: String?
        let title: String?
        let isMinimized: Bool
        let isFullscreen: Bool
        let subrole: String?
        let frame: CGRect?
        var isStandardWindow: Bool? {
            guard let subrole else { return nil }
            return subrole == (kAXStandardWindowSubrole as String) || subrole == (kAXDialogSubrole as String)
        }
    }

    private func collectAccessibilityWindows() -> [WindowID: AXWindowInfo] {
        var result: [WindowID: AXWindowInfo] = [:]
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0.processIdentifier != ownPID }

        for app in apps {
            let pid = app.processIdentifier
            let axApp = AXUIElementCreateApplication(pid)
            axApp.setMessagingTimeout(0.5)
            guard let windows = axApp.axWindows else { continue }
            let name = app.localizedName ?? ""
            let bundleID = app.bundleIdentifier

            for window in windows {
                guard let id = WindowServerInfo.windowID(for: window) else { continue }
                var frame: CGRect?
                if let origin = window.axPosition, let size = window.axSize {
                    frame = CGRect(origin: origin, size: size)
                }
                result[id] = AXWindowInfo(
                    element: window,
                    pid: pid,
                    appName: name,
                    bundleID: bundleID,
                    title: window.axTitle,
                    isMinimized: window.axIsMinimized,
                    isFullscreen: window.axIsFullscreen,
                    subrole: window.axSubrole,
                    frame: frame
                )
            }
        }
        return result
    }
}
