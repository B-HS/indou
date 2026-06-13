import Foundation

/// Virtual key codes (`kVK_*`) for the keys Indou cares about. Kept here so the
/// pure logic can reason about keys without importing Carbon.
public enum KeyCode {
    public static let tab: UInt16 = 48
    public static let escape: UInt16 = 53
    public static let backtick: UInt16 = 50
    public static let space: UInt16 = 49
    public static let `return`: UInt16 = 36
    public static let enter: UInt16 = 76

    public static let arrowLeft: UInt16 = 123
    public static let arrowRight: UInt16 = 124
    public static let arrowDown: UInt16 = 125
    public static let arrowUp: UInt16 = 126

    public static let w: UInt16 = 13
    public static let m: UInt16 = 46
    public static let f: UInt16 = 3
    public static let q: UInt16 = 12
    public static let h: UInt16 = 4
    public static let s: UInt16 = 1

    public static let keyH: UInt16 = 4
    public static let keyJ: UInt16 = 38
    public static let keyK: UInt16 = 40
    public static let keyL: UInt16 = 37
}
