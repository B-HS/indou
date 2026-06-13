import Foundation

/// Which applications' windows a shortcut profile collects.
public enum AppsToShow: String, Codable, CaseIterable, Sendable {
    case all
    case active
    case nonActive
}

/// Which Spaces a shortcut profile collects windows from.
public enum SpacesToShow: String, Codable, CaseIterable, Sendable {
    case all
    case visible
    case nonVisible
}

/// Which displays a shortcut profile collects windows from.
public enum ScreensToShow: String, Codable, CaseIterable, Sendable {
    case all
    case showingSwitcher
}

/// How a category of windows (minimized / hidden / fullscreen / windowless) is treated.
public enum ShowHow: String, Codable, CaseIterable, Sendable {
    case show
    case hide
    case showAtTheEnd
}

/// Ordering of the collected windows in the switcher.
public enum WindowOrder: String, Codable, CaseIterable, Sendable {
    case recentlyFocused
    case recentlyCreated
    case alphabetical
    case space
}

/// Whether tabs folded into one window appear as separate entries.
public enum GroupTabs: String, Codable, CaseIterable, Sendable {
    case combined
    case separate
}

/// What text label each cell shows.
public enum ShowTitles: String, Codable, CaseIterable, Sendable {
    case windowTitle
    case appName
    case appNameAndWindowTitle
}

/// Where a too-long title is truncated.
public enum TitleTruncation: String, Codable, CaseIterable, Sendable {
    case start
    case middle
    case end
}

/// The overall visual style of the switcher.
public enum AppearanceStyle: String, Codable, CaseIterable, Sendable {
    case thumbnails
    case appIcons
    case titles
}

/// The cell sizing strategy. `manual` uses `AppearanceSettings.manualCellHeight`.
public enum AppearanceSize: String, Codable, CaseIterable, Sendable {
    case small
    case medium
    case large
    case auto
    case manual
}

/// Light / dark / follow-system theming.
public enum AppearanceTheme: String, Codable, CaseIterable, Sendable {
    case light
    case dark
    case system
}

/// Which display the switcher overlay itself appears on.
public enum ShowOnScreen: String, Codable, CaseIterable, Sendable {
    case active
    case includingMouse
    case includingMenubar
}

/// App language. `system` follows the OS preferred languages.
public enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case system
    case ko
    case en
    case ja
}
