import AppKit
import IndouKit

/// Relaunch support. Runtime language switching is not officially supported by
/// macOS for the full UI (menus/system dialogs), so a language change prompts a
/// relaunch instead, which cleanly re-reads the chosen `.lproj`.
@MainActor
enum AppRelaunch {
    /// The language the app actually started with — compared against the current
    /// setting to decide whether a relaunch is needed.
    static var languageAtLaunch: AppLanguage = .system

    /// Persist the chosen UI language into `AppleLanguages`, which macOS reads at
    /// launch to pick the bundle `.lproj`. Takes effect on the next launch.
    static func applyLanguage(_ language: AppLanguage) {
        if language == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
    }

    static func relaunch() {
        let path = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.4; open \"\(path)\""]
        try? task.run()
        NSApp.terminate(nil)
    }
}
