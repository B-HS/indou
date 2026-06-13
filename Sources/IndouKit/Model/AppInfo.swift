import Foundation

/// Snapshot of a running application relevant to window switching. The app icon
/// lives in the app layer (it is an `NSImage`); `IndouKit` keys icons by `pid`.
public struct AppInfo: Identifiable, Sendable, Equatable {
    public let pid: pid_t
    public var bundleID: String?
    public var name: String
    public var isActive: Bool
    public var isHidden: Bool

    public var id: pid_t { pid }

    public init(pid: pid_t, bundleID: String? = nil, name: String = "", isActive: Bool = false, isHidden: Bool = false) {
        self.pid = pid
        self.bundleID = bundleID
        self.name = name
        self.isActive = isActive
        self.isHidden = isHidden
    }
}
