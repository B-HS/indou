import AppKit

/// Best-effort "is there a newer release?" check against the GitHub releases API.
/// No in-app updating — the About pane just surfaces the new version and links
/// to the releases page for a manual download.
enum UpdateChecker {
    static let releasesURL = URL(string: "https://github.com/B-HS/indou/releases/latest")!
    private static let apiURL = URL(string: "https://api.github.com/repos/B-HS/indou/releases/latest")!

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// The latest release version (e.g. "0.1.2") when it is newer than the
    /// running app, otherwise nil. Returns nil on any network/parse error.
    static func newerVersionIfAvailable() async -> String? {
        do {
            var request = URLRequest(url: apiURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 8
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else { return nil }
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            return isNewer(latest, than: currentVersion) ? latest : nil
        } catch {
            return nil
        }
    }

    /// Numeric semver comparison: "0.1.2" > "0.1.1".
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0 ..< max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
