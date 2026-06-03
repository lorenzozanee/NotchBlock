import ServiceManagement

/// Manages "Launch at Login" preference using SMAppService (macOS 13+).
/// Fulfills AC 1.2: app must support auto-start on boot.
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

    @discardableResult
    static func toggle() throws -> Bool {
        let newState = !isLoginItemEnabled
        try setLoginItemEnabled(newState)
        return newState
    }
}
