import Foundation

/// App-wide preferences. Every field has a default, and every sub-struct decodes
/// missing keys to that default (`decodeIfPresent`), so older or newer JSON loads
/// without losing sibling values — forward/backward migration for free.

public struct GeneralSettings: Codable, Sendable, Equatable {
    public var launchAtLogin: Bool = false
    public var showMenubarIcon: Bool = true
    public var language: AppLanguage = .system
    public var showOnScreen: ShowOnScreen = .includingMouse
    public var showBackgroundApps: Bool = false

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var d = GeneralSettings()
        d.launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? d.launchAtLogin
        d.showMenubarIcon = try c.decodeIfPresent(Bool.self, forKey: .showMenubarIcon) ?? d.showMenubarIcon
        d.language = try c.decodeIfPresent(AppLanguage.self, forKey: .language) ?? d.language
        d.showOnScreen = try c.decodeIfPresent(ShowOnScreen.self, forKey: .showOnScreen) ?? d.showOnScreen
        d.showBackgroundApps = try c.decodeIfPresent(Bool.self, forKey: .showBackgroundApps) ?? d.showBackgroundApps
        self = d
    }
}

public struct AppearanceSettings: Codable, Sendable, Equatable {
    public var style: AppearanceStyle = .thumbnails
    public var size: AppearanceSize = .medium
    public var theme: AppearanceTheme = .system
    public var showTitles: ShowTitles = .appNameAndWindowTitle
    public var titleTruncation: TitleTruncation = .end
    public var showThumbnails: Bool = true
    public var showStatusIcons: Bool = true
    public var showSpaceNumbers: Bool = true
    public var maskTitles: Bool = false
    public var useLiquidGlass: Bool = true
    public var columns: Int = 0
    public var manualCellHeight: Int = 160

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var d = AppearanceSettings()
        d.style = try c.decodeIfPresent(AppearanceStyle.self, forKey: .style) ?? d.style
        d.size = try c.decodeIfPresent(AppearanceSize.self, forKey: .size) ?? d.size
        d.theme = try c.decodeIfPresent(AppearanceTheme.self, forKey: .theme) ?? d.theme
        d.showTitles = try c.decodeIfPresent(ShowTitles.self, forKey: .showTitles) ?? d.showTitles
        d.titleTruncation = try c.decodeIfPresent(TitleTruncation.self, forKey: .titleTruncation) ?? d.titleTruncation
        d.showThumbnails = try c.decodeIfPresent(Bool.self, forKey: .showThumbnails) ?? d.showThumbnails
        d.showStatusIcons = try c.decodeIfPresent(Bool.self, forKey: .showStatusIcons) ?? d.showStatusIcons
        d.showSpaceNumbers = try c.decodeIfPresent(Bool.self, forKey: .showSpaceNumbers) ?? d.showSpaceNumbers
        d.maskTitles = try c.decodeIfPresent(Bool.self, forKey: .maskTitles) ?? d.maskTitles
        d.useLiquidGlass = try c.decodeIfPresent(Bool.self, forKey: .useLiquidGlass) ?? d.useLiquidGlass
        d.columns = try c.decodeIfPresent(Int.self, forKey: .columns) ?? d.columns
        d.manualCellHeight = try c.decodeIfPresent(Int.self, forKey: .manualCellHeight) ?? d.manualCellHeight
        self = d
    }
}

public struct AnimationSettings: Codable, Sendable, Equatable {
    public var enabled: Bool = true
    public var respectReduceMotion: Bool = true
    public var summonDelayMs: Int = 180
    public var fadeInOut: Bool = true
    public var springSelection: Bool = true
    public var durationMs: Int = 180

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var d = AnimationSettings()
        d.enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? d.enabled
        d.respectReduceMotion = try c.decodeIfPresent(Bool.self, forKey: .respectReduceMotion) ?? d.respectReduceMotion
        d.summonDelayMs = try c.decodeIfPresent(Int.self, forKey: .summonDelayMs) ?? d.summonDelayMs
        d.fadeInOut = try c.decodeIfPresent(Bool.self, forKey: .fadeInOut) ?? d.fadeInOut
        d.springSelection = try c.decodeIfPresent(Bool.self, forKey: .springSelection) ?? d.springSelection
        d.durationMs = try c.decodeIfPresent(Int.self, forKey: .durationMs) ?? d.durationMs
        self = d
    }
}

public struct InputSettings: Codable, Sendable, Equatable {
    public var arrowKeysEnabled: Bool = true
    public var vimKeysEnabled: Bool = false
    public var mouseHoverEnabled: Bool = true
    /// Multi-select mode (marquee drag + ⌘/⇧-click batch selection). Off = single:
    /// a click acts immediately and dismisses.
    public var multiSelectEnabled: Bool = false

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var d = InputSettings()
        d.arrowKeysEnabled = try c.decodeIfPresent(Bool.self, forKey: .arrowKeysEnabled) ?? d.arrowKeysEnabled
        d.vimKeysEnabled = try c.decodeIfPresent(Bool.self, forKey: .vimKeysEnabled) ?? d.vimKeysEnabled
        d.mouseHoverEnabled = try c.decodeIfPresent(Bool.self, forKey: .mouseHoverEnabled) ?? d.mouseHoverEnabled
        d.multiSelectEnabled = try c.decodeIfPresent(Bool.self, forKey: .multiSelectEnabled) ?? d.multiSelectEnabled
        self = d
    }
}

public struct AdvancedSettings: Codable, Sendable, Equatable {
    public var usePrivateSpaceAPIs: Bool = true
    public var usePreciseFocus: Bool = true
    public var disableNativeCmdTab: Bool = false
    public var captureMinimizedWindows: Bool = false
    public var thumbnailResolutionScale: Double = 1.0
    public var maxConcurrentCaptures: Int = 8

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var d = AdvancedSettings()
        d.usePrivateSpaceAPIs = try c.decodeIfPresent(Bool.self, forKey: .usePrivateSpaceAPIs) ?? d.usePrivateSpaceAPIs
        d.usePreciseFocus = try c.decodeIfPresent(Bool.self, forKey: .usePreciseFocus) ?? d.usePreciseFocus
        d.disableNativeCmdTab = try c.decodeIfPresent(Bool.self, forKey: .disableNativeCmdTab) ?? d.disableNativeCmdTab
        d.captureMinimizedWindows = try c.decodeIfPresent(Bool.self, forKey: .captureMinimizedWindows) ?? d.captureMinimizedWindows
        d.thumbnailResolutionScale = try c.decodeIfPresent(Double.self, forKey: .thumbnailResolutionScale) ?? d.thumbnailResolutionScale
        d.maxConcurrentCaptures = try c.decodeIfPresent(Int.self, forKey: .maxConcurrentCaptures) ?? d.maxConcurrentCaptures
        self = d
    }
}

public struct SettingsSchema: Codable, Sendable, Equatable {
    public static let currentVersion = 1

    public var version: Int = currentVersion
    public var general: GeneralSettings = .init()
    public var appearance: AppearanceSettings = .init()
    public var animation: AnimationSettings = .init()
    public var input: InputSettings = .init()
    public var advanced: AdvancedSettings = .init()
    public var profiles: [ShortcutProfile] = ShortcutProfile.defaults
    public var exceptions: [ExceptionRule] = []

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var d = SettingsSchema()
        d.version = try c.decodeIfPresent(Int.self, forKey: .version) ?? d.version
        d.general = try c.decodeIfPresent(GeneralSettings.self, forKey: .general) ?? d.general
        d.appearance = try c.decodeIfPresent(AppearanceSettings.self, forKey: .appearance) ?? d.appearance
        d.animation = try c.decodeIfPresent(AnimationSettings.self, forKey: .animation) ?? d.animation
        d.input = try c.decodeIfPresent(InputSettings.self, forKey: .input) ?? d.input
        d.advanced = try c.decodeIfPresent(AdvancedSettings.self, forKey: .advanced) ?? d.advanced
        d.profiles = try c.decodeIfPresent([ShortcutProfile].self, forKey: .profiles) ?? d.profiles
        d.exceptions = try c.decodeIfPresent([ExceptionRule].self, forKey: .exceptions) ?? d.exceptions
        if d.profiles.isEmpty { d.profiles = ShortcutProfile.defaults }
        d.version = Self.currentVersion
        self = d
    }
}
