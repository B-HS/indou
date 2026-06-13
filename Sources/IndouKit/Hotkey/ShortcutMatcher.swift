import Foundation

/// Pure predicates that map observed key state to shortcut semantics. The app
/// layer feeds it the modifiers/keyCode from Carbon/CGEventTap; the matcher
/// decides whether a profile triggers, reverses, or whether the hold ended.
public enum ShortcutMatcher {
    /// A profile triggers when its hold modifiers are all down and the advance
    /// key is pressed. Extra trigger modifiers beyond the profile's are rejected
    /// so ⌥Tab and ⌥⇧Tab stay distinguishable from ⌥⌘Tab.
    public static func isTrigger(_ profile: ShortcutProfile, modifiers: ModifierFlags, keyCode: UInt16) -> Bool {
        guard profile.enabled, keyCode == profile.nextKey else { return false }
        let active = modifiers.triggerModifiers
        let allowed = profile.holdModifiers.triggerModifiers.union(profile.reverseModifier.triggerModifiers)
        guard active.isSuperset(of: profile.holdModifiers.triggerModifiers) else { return false }
        return allowed.isSuperset(of: active)
    }

    /// Whether the advance is in reverse (Shift held with the trigger).
    public static func isReverse(_ profile: ShortcutProfile, modifiers: ModifierFlags) -> Bool {
        !profile.reverseModifier.isEmpty &&
            modifiers.triggerModifiers.isSuperset(of: profile.reverseModifier.triggerModifiers)
    }

    /// The hold has ended once the profile's hold modifiers are no longer all down.
    public static func holdReleased(_ profile: ShortcutProfile, currentModifiers: ModifierFlags) -> Bool {
        !currentModifiers.triggerModifiers.isSuperset(of: profile.holdModifiers.triggerModifiers)
    }

    /// The first enabled profile whose trigger matches, if any.
    public static func firstMatch(in profiles: [ShortcutProfile], modifiers: ModifierFlags, keyCode: UInt16) -> ShortcutProfile? {
        profiles.first { isTrigger($0, modifiers: modifiers, keyCode: keyCode) }
    }
}
