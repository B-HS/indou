import CoreGraphics
import Foundation

public typealias WindowID = CGWindowID
public typealias SpaceID = Int
public typealias DisplayID = CGDirectDisplayID

/// How a window is grouped when shown — a real top-level window, or a tab folded
/// into another window's tab group.
public enum WindowKind: Sendable, Equatable {
    case window
    case tab
}

/// A single switchable window plus the metadata needed to filter, label, order,
/// and act on it. Populated by the app layer from ScreenCaptureKit + Accessibility;
/// `IndouKit` only ever reasons over these value snapshots so it stays testable.
public struct WindowState: Identifiable, Sendable, Equatable {
    public let id: WindowID
    public var title: String
    public var appName: String
    public var appBundleID: String?
    public var pid: pid_t

    public var isMinimized: Bool
    public var isFullscreen: Bool
    public var isHidden: Bool
    public var isOnScreen: Bool
    public var isOnAllSpaces: Bool
    public var kind: WindowKind

    public var spaceIDs: [SpaceID]
    public var displayID: DisplayID?
    public var frame: CGRect
    public var windowLevel: Int

    /// Monotonic counter assigned when the window was last focused (MRU order).
    public var lastFocusOrder: Int
    /// Monotonic counter assigned when the window first appeared.
    public var creationOrder: Int

    public init(
        id: WindowID,
        title: String = "",
        appName: String = "",
        appBundleID: String? = nil,
        pid: pid_t = 0,
        isMinimized: Bool = false,
        isFullscreen: Bool = false,
        isHidden: Bool = false,
        isOnScreen: Bool = true,
        isOnAllSpaces: Bool = false,
        kind: WindowKind = .window,
        spaceIDs: [SpaceID] = [],
        displayID: DisplayID? = nil,
        frame: CGRect = .zero,
        windowLevel: Int = 0,
        lastFocusOrder: Int = 0,
        creationOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.appName = appName
        self.appBundleID = appBundleID
        self.pid = pid
        self.isMinimized = isMinimized
        self.isFullscreen = isFullscreen
        self.isHidden = isHidden
        self.isOnScreen = isOnScreen
        self.isOnAllSpaces = isOnAllSpaces
        self.kind = kind
        self.spaceIDs = spaceIDs
        self.displayID = displayID
        self.frame = frame
        self.windowLevel = windowLevel
        self.lastFocusOrder = lastFocusOrder
        self.creationOrder = creationOrder
    }
}

public extension WindowState {
    /// Best-effort human label honoring the title/app fallbacks the UI needs.
    var displayTitle: String {
        title.isEmpty ? appName : title
    }
}
