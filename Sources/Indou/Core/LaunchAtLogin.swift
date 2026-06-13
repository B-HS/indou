import Foundation
import Observation
import ServiceManagement

/// Thin wrapper around `SMAppService.mainApp` to toggle "Open at Login".
@MainActor
@Observable
final class LaunchAtLogin {
    private(set) var isEnabled: Bool

    init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Log.app.error("LaunchAtLogin toggle failed: \(String(describing: error))")
        }
        refresh()
    }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }
}
