import Foundation

/// What pressing/releasing the trigger does on key-up.
public enum ShortcutReleaseAction: String, Codable, CaseIterable, Sendable {
    case focusOnRelease
    case doNothingOnRelease
    case searchOnRelease
}

/// A named trigger profile: the held modifier + advance key that summon the
/// switcher, plus the window filter (and later appearance) it uses. Indou
/// supports several independent profiles (e.g. "all windows" on ⌥Tab,
/// "current app" on ⌥`).
public struct ShortcutProfile: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var enabled: Bool

    /// Modifier(s) held to keep the switcher open (released → commit).
    public var holdModifiers: ModifierFlags
    /// Key that advances to the next window while held (Tab by default).
    public var nextKey: UInt16
    /// Extra modifier that reverses direction (Shift by default).
    public var reverseModifier: ModifierFlags
    public var releaseAction: ShortcutReleaseAction

    public var filter: WindowFilterCriteria

    public init(
        id: UUID = UUID(),
        name: String,
        enabled: Bool = true,
        holdModifiers: ModifierFlags = .option,
        nextKey: UInt16 = KeyCode.tab,
        reverseModifier: ModifierFlags = .shift,
        releaseAction: ShortcutReleaseAction = .focusOnRelease,
        filter: WindowFilterCriteria = .init()
    ) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.holdModifiers = holdModifiers
        self.nextKey = nextKey
        self.reverseModifier = reverseModifier
        self.releaseAction = releaseAction
        self.filter = filter
    }

    /// The default two profiles mirroring the classic ⌥Tab (all windows) plus a
    /// current-app cycle on ⌥`. Fixed ids so defaults are deterministic across
    /// launches (stable persistence + id-based updates).
    public static var defaults: [ShortcutProfile] {
        [
            ShortcutProfile(id: UUID(uuidString: "00000000-0000-0000-0000-0000000A11A0")!,
                            name: "All windows", holdModifiers: .option, nextKey: KeyCode.tab,
                            filter: WindowFilterCriteria(appsToShow: .all)),
            ShortcutProfile(id: UUID(uuidString: "00000000-0000-0000-0000-00000AC71E00")!,
                            name: "Current app", holdModifiers: .option, nextKey: KeyCode.backtick,
                            filter: WindowFilterCriteria(appsToShow: .active)),
        ]
    }
}
