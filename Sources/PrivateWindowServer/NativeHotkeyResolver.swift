import CoreGraphics

/// Toggles the macOS Dock application switcher (⌘Tab / ⌘⇧Tab) via the private
/// symbolic-hotkey API, so a user who binds Indou to ⌘Tab can suppress the
/// native switcher. Always re-enable on quit to avoid leaving the system without
/// ⌘Tab. No-op when the symbol is unavailable.
public enum NativeHotkeyResolver {
    // CGS symbolic-hotkey ids for the Dock app switcher (matches AltTab).
    private static let commandTab: Int32 = 1
    private static let commandShiftTab: Int32 = 2

    public static var isSupported: Bool {
        SkyLightSymbols.shared.setSymbolicHotKeyEnabled != nil
    }

    public static func setNativeCommandTabEnabled(_ enabled: Bool) {
        guard let setEnabled = SkyLightSymbols.shared.setSymbolicHotKeyEnabled else { return }
        _ = setEnabled(commandTab, enabled)
        _ = setEnabled(commandShiftTab, enabled)
    }
}
