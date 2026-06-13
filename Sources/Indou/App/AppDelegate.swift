import AppKit
import IndouKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = PreferenceStore()
    private lazy var controller = SwitcherController(store: store)
    private var statusItem: NSStatusItem?
    private var permissionTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.info("Indou launching")
        AppRelaunch.languageAtLaunch = store.settings.general.language
        AppRelaunch.applyLanguage(store.settings.general.language)
        installStatusItem()
        bootstrap()
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTask?.cancel()
        controller.restoreNativeCommandTab()
    }

    // MARK: - Bootstrap + permissions

    private func bootstrap() {
        if Permissions.hasAccessibility {
            controller.start()
        } else {
            Permissions.promptAccessibility()
            waitForAccessibility()
        }
    }

    /// Poll until Accessibility is granted, then start the key tap. (The grant
    /// often is not visible to the same process immediately.)
    private func waitForAccessibility() {
        permissionTask = Task { @MainActor in
            while !Permissions.hasAccessibility {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
            }
            controller.start()
            Log.app.info("Accessibility granted — switcher armed")
        }
    }

    // MARK: - Status item

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = menuBarImage()
        item.menu = buildMenu()
        statusItem = item
    }

    private func menuBarImage() -> NSImage? {
        if let url = Bundle.module.url(forResource: "MenuBarIcon", withExtension: "png"), let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            return image
        }
        return NSImage(systemSymbolName: "square.grid.3x3.topleft.filled", accessibilityDescription: "Indou")
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: String(localized: "Settings…"), action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Quit Indou"), action: #selector(quit), keyEquivalent: "q").target = self
        return menu
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show(store: store, controller: controller)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
