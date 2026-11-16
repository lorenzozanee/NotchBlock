import ServiceManagement

/// Manages "Launch at Login" preference using SMAppService.
@MainActor
enum LaunchManager {
    static var isLoginItemEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setLoginItemEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
