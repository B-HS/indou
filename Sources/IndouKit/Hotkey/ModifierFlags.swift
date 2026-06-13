import Foundation

/// OS-independent modifier set. Raw values match the device-independent
/// `NSEvent.ModifierFlags` masks so the app layer can bridge without a lookup
/// table, while `IndouKit` stays free of AppKit.
public struct ModifierFlags: OptionSet, Codable, Sendable, Hashable {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    public static let capsLock = ModifierFlags(rawValue: 1 << 16)
    public static let shift = ModifierFlags(rawValue: 1 << 17)
    public static let control = ModifierFlags(rawValue: 1 << 18)
    public static let option = ModifierFlags(rawValue: 1 << 19)
    public static let command = ModifierFlags(rawValue: 1 << 20)
    public static let function = ModifierFlags(rawValue: 1 << 23)

    /// Only the four modifiers that can act as a hold trigger (ignores capsLock/fn).
    public static let triggerMask: ModifierFlags = [.shift, .control, .option, .command]

    public var triggerModifiers: ModifierFlags {
        intersection(.triggerMask)
    }

    /// A short, stable glyph string ("⌥⇧") for display.
    public var symbolString: String {
        var s = ""
        if contains(.control) { s += "⌃" }
        if contains(.option) { s += "⌥" }
        if contains(.shift) { s += "⇧" }
        if contains(.command) { s += "⌘" }
        return s
    }
}
