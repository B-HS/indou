import AppKit

/// Caches running-app icons by pid so the grid never re-fetches an `NSImage`
/// mid-session. Cleared when the app set changes.
@MainActor
final class IconProvider {
    static let shared = IconProvider()

    private var cache: [pid_t: NSImage] = [:]

    func icon(for pid: pid_t) -> NSImage? {
        if let cached = cache[pid] { return cached }
        guard let icon = NSRunningApplication(processIdentifier: pid)?.icon else { return nil }
        cache[pid] = icon
        return icon
    }

    func prune(keeping pids: Set<pid_t>) {
        cache = cache.filter { pids.contains($0.key) }
    }
}
