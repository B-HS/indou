import CoreGraphics
import Foundation

/// A display, in Cocoa (bottom-left origin) coordinates as reported by `NSScreen`.
public struct ScreenInfo: Identifiable, Sendable, Equatable {
    public let id: DisplayID
    public var frame: CGRect
    public var visibleFrame: CGRect
    public var isMain: Bool
    public var backingScaleFactor: CGFloat

    public init(id: DisplayID, frame: CGRect, visibleFrame: CGRect, isMain: Bool = false, backingScaleFactor: CGFloat = 2) {
        self.id = id
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.isMain = isMain
        self.backingScaleFactor = backingScaleFactor
    }
}

/// A macOS Space (desktop / fullscreen). Membership and ordering come from the
/// private window-server layer, so this is best-effort and may be empty when the
/// private APIs are unavailable.
public struct SpaceInfo: Identifiable, Sendable, Equatable {
    public let id: SpaceID
    public var index: Int
    public var displayID: DisplayID?
    public var isFullscreen: Bool
    public var isVisible: Bool

    public init(id: SpaceID, index: Int, displayID: DisplayID? = nil, isFullscreen: Bool = false, isVisible: Bool = false) {
        self.id = id
        self.index = index
        self.displayID = displayID
        self.isFullscreen = isFullscreen
        self.isVisible = isVisible
    }
}
