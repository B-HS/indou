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

    func enumerate(includeBackgroundApps: Bool) async -> [LiveWindow] {
        let scWindows = await fetchShareableWindows()
        let apps = runningRegularApps()
        let axByWindowID = await Self.collectAccessibilityWindows(apps: apps)
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

        // 3. Optional: a stand-in entry per running regular app that has no window
        //    at all (background / all-windows-closed processes — what Force Quit
        //    lists but a window switcher normally omits).
        if includeBackgroundApps {
            let pidsWithWindow = Set(merged.values.map { $0.state.pid })
            for app in apps where !pidsWithWindow.contains(app.pid) {
                let id = Self.appEntryWindowID(for: app.pid)
                guard merged[id] == nil else { continue }
                var state = WindowState(
                    id: id,
                    title: app.name,
                    appName: app.name,
                    appBundleID: app.bundleID,
                    pid: app.pid,
                    isOnScreen: false,
                    isAppEntry: true
                )
                state.creationOrder = creation(for: id)
                merged[id] = LiveWindow(state: state, axElement: nil)
            }
        }

        return Array(merged.values)
    }

    /// A synthetic CGWindowID for an app stand-in: the pid with the high bit set so
    /// it can never collide with a real window id (those are assigned from low
    /// numbers and never approach 2^31).
    private static func appEntryWindowID(for pid: pid_t) -> WindowID {
        0x8000_0000 | (WindowID(UInt32(bitPattern: pid)) & 0x7FFF_FFFF)
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

    private struct AppSnapshot: Sendable {
        let pid: pid_t
        let name: String
        let bundleID: String?
    }

    private struct AXWindowInfo: Sendable {
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

    private func runningRegularApps() -> [AppSnapshot] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != ownPID }
            .map { AppSnapshot(pid: $0.processIdentifier, name: $0.localizedName ?? "", bundleID: $0.bundleIdentifier) }
    }

    // The cross-process AX pass does one messaging round-trip per app and window,
    // each with a 0.5s timeout, so it can stall for a while when apps are busy. The
    // global event tap shares the main run loop and would be disabled by timeout if
    // this blocked the main thread, so it runs off the main actor (the AX C API is
    // thread-safe). Only Sendable snapshots cross the boundary.
    nonisolated private static func collectAccessibilityWindows(apps: [AppSnapshot]) async -> [WindowID: AXWindowInfo] {
        var result: [WindowID: AXWindowInfo] = [:]
        for app in apps {
            let axApp = AXUIElementCreateApplication(app.pid)
            axApp.setMessagingTimeout(0.5)
            guard let windows = axApp.axWindows else { continue }

            for window in windows {
                guard let id = WindowServerInfo.windowID(for: window) else { continue }
                var frame: CGRect?
                if let origin = window.axPosition, let size = window.axSize {
                    frame = CGRect(origin: origin, size: size)
                }
                result[id] = AXWindowInfo(
                    element: window,
                    pid: app.pid,
                    appName: app.name,
                    bundleID: app.bundleID,
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
