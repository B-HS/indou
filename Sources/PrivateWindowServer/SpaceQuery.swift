import CoreGraphics
import Foundation
import IndouKit

/// Best-effort Spaces introspection via the private CGS/SkyLight connection.
/// Every entry point returns an empty / degraded result when the symbols are
/// missing so the filter layer can fall back to "current space only".
public enum SpaceQuery {
    private static let allSpacesMask: Int32 = 0x7

    /// The currently-visible Space id on each display.
    public static func visibleSpaceIDs() -> Set<SpaceID> {
        let symbols = SkyLightSymbols.shared
        guard let copy = symbols.copyManagedDisplaySpaces else { return [] }
        guard let displays = copy(symbols.connectionID)?.takeRetainedValue() as? [[String: Any]] else { return [] }

        var visible: Set<SpaceID> = []
        for display in displays {
            guard let current = display["Current Space"] as? [String: Any] else { continue }
            if let id = spaceID(from: current) {
                visible.insert(id)
            }
        }
        return visible
    }

    /// All Space ids known to the window server, with display + fullscreen hints.
    public static func allSpaces() -> [SpaceInfo] {
        let symbols = SkyLightSymbols.shared
        guard let copy = symbols.copyManagedDisplaySpaces else { return [] }
        guard let displays = copy(symbols.connectionID)?.takeRetainedValue() as? [[String: Any]] else { return [] }

        var result: [SpaceInfo] = []
        var index = 0
        for display in displays {
            let currentID = (display["Current Space"] as? [String: Any]).flatMap(spaceID(from:))
            guard let spaces = display["Spaces"] as? [[String: Any]] else { continue }
            for space in spaces {
                guard let id = spaceID(from: space) else { continue }
                let type = space["type"] as? Int ?? 0
                result.append(SpaceInfo(
                    id: id,
                    index: index,
                    displayID: nil,
                    isFullscreen: type == 4,
                    isVisible: id == currentID
                ))
                index += 1
            }
        }
        return result
    }

    /// The Space ids a single window belongs to (one call per window).
    public static func spaceIDs(forWindow windowID: CGWindowID) -> [SpaceID] {
        let symbols = SkyLightSymbols.shared
        guard let copy = symbols.copySpacesForWindows else { return [] }
        let windows = [NSNumber(value: windowID)] as CFArray
        guard let spaces = copy(symbols.connectionID, allSpacesMask, windows)?.takeRetainedValue() as? [Int] else { return [] }
        return spaces
    }

    private static func spaceID(from dict: [String: Any]) -> SpaceID? {
        if let v = dict["ManagedSpaceID"] as? Int { return v }
        if let v = dict["id64"] as? Int { return v }
        if let v = dict["ManagedSpaceID"] as? NSNumber { return v.intValue }
        if let v = dict["id64"] as? NSNumber { return v.intValue }
        return nil
    }
}
