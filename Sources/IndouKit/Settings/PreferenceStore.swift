import Foundation
import Observation

/// Pure JSON (de)serialization for settings. The lenient `SettingsSchema`
/// decoder handles migration, so this is just transport. Unit-tested directly.
public enum SettingsCodec {
    public static func encode(_ settings: SettingsSchema) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(settings)
    }

    public static func decode(_ data: Data) throws -> SettingsSchema {
        try JSONDecoder().decode(SettingsSchema.self, from: data)
    }
}

/// Observable, file-backed settings store. SwiftUI Settings panes bind to
/// `settings`; every mutation persists. Defaults to
/// `~/Library/Application Support/com.hyunseokbyun.indou/settings.json`, but a
/// custom URL can be injected for tests.
@MainActor
@Observable
public final class PreferenceStore {
    public private(set) var settings: SettingsSchema

    private let fileURL: URL

    public init(fileURL: URL? = nil) {
        let url = fileURL ?? Self.defaultURL()
        self.fileURL = url
        if let data = try? Data(contentsOf: url), let loaded = try? SettingsCodec.decode(data) {
            settings = loaded
        } else {
            settings = SettingsSchema()
        }
    }

    /// Mutate settings in place and persist.
    public func update(_ mutate: (inout SettingsSchema) -> Void) {
        mutate(&settings)
        save()
    }

    public func reset() {
        settings = SettingsSchema()
        save()
    }

    public func exportData() throws -> Data {
        try SettingsCodec.encode(settings)
    }

    public func importData(_ data: Data) throws {
        settings = try SettingsCodec.decode(data)
        save()
    }

    private func save() {
        guard let data = try? SettingsCodec.encode(settings) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base
            .appendingPathComponent("com.hyunseokbyun.indou", isDirectory: true)
            .appendingPathComponent("settings.json", isDirectory: false)
    }
}
