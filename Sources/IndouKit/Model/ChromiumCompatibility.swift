import Foundation

public enum ChromiumCompatibility {
    private static let bundleIDs = Set(["com.google.Chrome", "com.openai.codex"])

    public static func requiresConservativeWindowHandling(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return bundleIDs.contains(bundleID)
    }
}
