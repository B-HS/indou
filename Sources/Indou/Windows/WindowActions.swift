import AppKit
import ApplicationServices
import IndouKit
import PrivateWindowServer

/// Performs window/app actions on the live AX elements. All AX mutations run on
/// the main actor; batch actions group by app so an app is asked to quit once.
@MainActor
enum WindowActions {
    static func focus(_ window: LiveWindow, usePrivateFocus: Bool) {
        // App stand-in (no window): just bring the app forward.
        if window.state.isAppEntry {
            NSRunningApplication(processIdentifier: window.state.pid)?.activate()
            return
        }
        // Restore a minimized window before raising it.
        if window.state.isMinimized {
            window.axElement?.setValue(kAXMinimizedAttribute as String, false as CFBoolean)
        }
        PreciseFocus.focus(
            windowID: window.state.id,
            pid: window.state.pid,
            axWindow: window.axElement,
            usePrivate: usePrivateFocus
        )
    }

    static func close(_ window: LiveWindow) {
        guard let ax = window.axElement else { return }
        if window.state.isFullscreen {
            ax.setValue("AXFullScreen", false as CFBoolean)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                ax.axCloseButton?.perform(kAXPressAction as String)
            }
            return
        }
        ax.axCloseButton?.perform(kAXPressAction as String)
    }

    static func setMinimized(_ window: LiveWindow, _ minimized: Bool) {
        window.axElement?.setValue(kAXMinimizedAttribute as String, minimized as CFBoolean)
    }

    static func toggleMinimized(_ window: LiveWindow) {
        setMinimized(window, !window.state.isMinimized)
    }

    static func toggleFullscreen(_ window: LiveWindow) {
        window.axElement?.setValue("AXFullScreen", !window.state.isFullscreen as CFBoolean)
    }

    static func quitApp(pid: pid_t, force: Bool = false) {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return }
        if force { app.forceTerminate() } else { app.terminate() }
    }

    static func hideApp(pid: pid_t) {
        NSRunningApplication(processIdentifier: pid)?.hide()
    }

    // MARK: - Batch (drag-multiselect → right-click)

    static func closeAll(_ windows: [LiveWindow]) {
        runSerially(windows) { close($0) }
    }

    static func minimizeAll(_ windows: [LiveWindow]) {
        runSerially(windows) { setMinimized($0, true) }
    }

    /// Quits each distinct app once, even if several of its windows are selected.
    static func quitApps(_ windows: [LiveWindow]) {
        let pids = Set(windows.map { $0.state.pid })
        for pid in pids {
            quitApp(pid: pid)
        }
    }

    /// Spaces out AX commands so fullscreen-exit delays don't pile up and drop.
    private static func runSerially(_ windows: [LiveWindow], _ body: @escaping @MainActor (LiveWindow) -> Void) {
        for (offset, window) in windows.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(offset) * 0.08) {
                body(window)
            }
        }
    }
}
