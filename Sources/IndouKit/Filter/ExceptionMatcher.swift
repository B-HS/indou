import Foundation

/// When an app's windows are hidden from the switcher.
public enum HideMode: String, Codable, CaseIterable, Sendable {
    case never
    case always
    case whenNoOpenWindow
    case whenTitleMatches
}

/// When Indou yields its trigger shortcut back to the native ⌘⇥ behaviour for an
/// app (useful for games, VMs, remote-desktop clients that need the raw keys).
public enum IgnoreShortcutMode: String, Codable, CaseIterable, Sendable {
    case never
    case always
    case whenFullscreen
}

/// A per-app blacklist / passthrough rule. Matched by bundle-id prefix so a single
/// rule can cover a whole vendor namespace.
public struct ExceptionRule: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var bundleIDPrefix: String
    public var titleContains: String?
    public var hide: HideMode
    public var ignoreShortcut: IgnoreShortcutMode

    public init(
        id: UUID = UUID(),
        bundleIDPrefix: String,
        titleContains: String? = nil,
        hide: HideMode = .never,
        ignoreShortcut: IgnoreShortcutMode = .never
    ) {
        self.id = id
        self.bundleIDPrefix = bundleIDPrefix
        self.titleContains = titleContains
        self.hide = hide
        self.ignoreShortcut = ignoreShortcut
    }
}

/// Resolves blacklist rules against windows and apps. Pure and order-independent;
/// the first matching rule wins.
public struct ExceptionMatcher: Sendable {
    public let rules: [ExceptionRule]

    public init(rules: [ExceptionRule] = []) {
        self.rules = rules
    }

    private func rule(forBundleID bundleID: String?) -> ExceptionRule? {
        guard let bundleID, !bundleID.isEmpty else { return nil }
        return rules.first { !$0.bundleIDPrefix.isEmpty && bundleID.hasPrefix($0.bundleIDPrefix) }
    }

    /// Whether a window should be removed from the switcher list.
    /// `appWindowCount` is how many windows that window's app currently has.
    public func shouldHide(_ window: WindowState, appWindowCount: Int) -> Bool {
        guard let rule = rule(forBundleID: window.appBundleID) else { return false }
        switch rule.hide {
        case .never:
            return false
        case .always:
            return true
        case .whenNoOpenWindow:
            return appWindowCount == 0
        case .whenTitleMatches:
            guard let needle = rule.titleContains, !needle.isEmpty else { return false }
            return window.title.localizedCaseInsensitiveContains(needle)
        }
    }

    /// Whether Indou should let the native shortcut through for this app instead
    /// of opening the switcher.
    public func shouldIgnoreShortcut(bundleID: String?, isFullscreen: Bool) -> Bool {
        guard let rule = rule(forBundleID: bundleID) else { return false }
        switch rule.ignoreShortcut {
        case .never: return false
        case .always: return true
        case .whenFullscreen: return isFullscreen
        }
    }
}
