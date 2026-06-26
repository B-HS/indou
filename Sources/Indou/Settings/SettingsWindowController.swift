import AppKit
import IndouKit
import SwiftUI

/// Owns the single Settings window (menu-bar app, so it is created lazily and
/// reused). Hidden title bar + tiny-razer-style sidebar layout.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private let launchAtLogin = LaunchAtLogin()

    func show(store: PreferenceStore, controller: SwitcherController) {
        // Never inherit a stale "recording" gate from a previous Settings visit.
        controller.isRecordingShortcut = false
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let root = SettingsRootView(store: store, launchAtLogin: launchAtLogin, controller: controller)
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Indou"
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 780, height: 560))
        window.center()
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        self.window = window
        // Closing the window can't deliver SwiftUI .onDisappear (the view is
        // retained), so clear the recording gate here too as a safety net.
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak controller] _ in
            MainActor.assumeIsolated { controller?.isRecordingShortcut = false }
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
