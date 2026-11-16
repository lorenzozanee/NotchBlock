import AppKit
import CoreGraphics

/// Detects mouse hover at the MacBook hardware notch via 10 Hz cursor polling.
///
/// `NSTrackingArea` in the menu bar / notch region (~37px top edge) is intercepted
/// by the Window Server on macOS 14+. Polling `NSEvent.mouseLocation` reads cursor
/// coordinates directly, bypassing event delivery.
@MainActor
final class NotchTracker {
    var isPanelVisible = false

    var onTrigger: (() -> Void)?
    var onDismiss: (() -> Void)?

    // MARK: - Constants

    private static let notchWidth: CGFloat = 180
    private static let triggerZoneHeight: CGFloat = 5
    private static let hoverDebounce: Duration = .zero
    private static let leaveDebounce: Duration = .milliseconds(500)
    private static let pollInterval: Duration = .milliseconds(100)
    private static let fullscreenPollInterval: Duration = .seconds(2)

    // MARK: - State

    private var mouseInTriggerZone = false
    private var mouseInPanel = false
    private var isFullscreenActive = false

    nonisolated(unsafe) private var pollTask: Task<Void, Never>?
    nonisolated(unsafe) private var hoverTask: Task<Void, Never>?
    nonisolated(unsafe) private var leaveTask: Task<Void, Never>?
    nonisolated(unsafe) private var fullscreenTask: Task<Void, Never>?
    nonisolated(unsafe) private var spaceObserverTask: Task<Void, Never>?

    var isMainWindowOpen: Bool {
        NSApp.windows.contains { $0.isVisible && $0.identifier?.rawValue == "main" }
    }

    var debugDescription: String {
        "NotchTracker(polling: \(pollTask != nil), fullscreen: \(isFullscreenActive), mainWin: \(isMainWindowOpen), inZone: \(mouseInTriggerZone), inPanel: \(mouseInPanel), panel: \(isPanelVisible))"
    }

    // MARK: - Lifecycle

    deinit {
        pollTask?.cancel()
        hoverTask?.cancel()
        leaveTask?.cancel()
        fullscreenTask?.cancel()
        spaceObserverTask?.cancel()
    }

    func start() {
        guard pollTask == nil else { return }

        pollTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            while !Task.isCancelled {
                self?.pollMousePosition()
                try? await Task.sleep(for: Self.pollInterval)
            }
        }

        spaceObserverTask = Task { [weak self] in
            for await _ in Self.spaceChangeNotifications() {
                guard !Task.isCancelled else { break }
                await self?.refreshFullscreenState()
            }
        }

        fullscreenTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshFullscreenState()
                try? await Task.sleep(for: Self.fullscreenPollInterval)
            }
        }
    }

    func teardown() {
        pollTask?.cancel()
        pollTask = nil
        hoverTask?.cancel()
        hoverTask = nil
        leaveTask?.cancel()
        leaveTask = nil
        fullscreenTask?.cancel()
        fullscreenTask = nil
        spaceObserverTask?.cancel()
        spaceObserverTask = nil
    }

    func setMouseInPanel(_ inPanel: Bool) {
        mouseInPanel = inPanel
        if inPanel {
            leaveTask?.cancel()
            leaveTask = nil
        } else if !mouseInTriggerZone, isPanelVisible {
            scheduleLeaveDebounce()
        }
    }

    func dismissIfVisible() {
        hoverTask?.cancel()
        hoverTask = nil
        leaveTask?.cancel()
        leaveTask = nil
        mouseInTriggerZone = false
        mouseInPanel = false
        guard isPanelVisible else { return }
        isPanelVisible = false
        onDismiss?()
    }

    func notifyPanelDismissed() {
        isPanelVisible = false
        mouseInTriggerZone = false
        mouseInPanel = false
        hoverTask?.cancel()
        hoverTask = nil
        leaveTask?.cancel()
        leaveTask = nil
    }

    // MARK: - Mouse Position Polling

    private func pollMousePosition() {
        if isFullscreenActive || isMainWindowOpen {
            if isPanelVisible {
                dismissIfVisible()
            }
            return
        }

        guard let screen = NSScreen.notched else {
            if isPanelVisible {
                dismissIfVisible()
            }
            return
        }
        let inZone = isMouseInTriggerZone(NSEvent.mouseLocation, screen: screen)

        if inZone && !mouseInTriggerZone {
            mouseInTriggerZone = true
            leaveTask?.cancel()
            leaveTask = nil
            scheduleHoverDebounce()
        } else if !inZone && mouseInTriggerZone {
            mouseInTriggerZone = false
            hoverTask?.cancel()
            hoverTask = nil
            if isPanelVisible, !mouseInPanel {
                scheduleLeaveDebounce()
            }
        }
    }

    private func isMouseInTriggerZone(_ mouse: NSPoint, screen: NSScreen) -> Bool {
        let sf = screen.frame
        let centerX = sf.origin.x + sf.width / 2
        let leftX = centerX - Self.notchWidth / 2
        let rightX = centerX + Self.notchWidth / 2
        let topY = sf.maxY
        let bottomY = topY - Self.triggerZoneHeight

        return mouse.x >= leftX && mouse.x <= rightX
            && mouse.y >= bottomY && mouse.y <= topY
    }

    // MARK: - Debounce

    private func scheduleHoverDebounce() {
        hoverTask?.cancel()
        hoverTask = Task { [weak self] in
            if Self.hoverDebounce > .zero {
                try? await Task.sleep(for: Self.hoverDebounce)
            }
            guard !Task.isCancelled,
                  let self,
                  self.mouseInTriggerZone,
                  !self.isFullscreenActive,
                  !self.isMainWindowOpen
            else { return }
            self.isPanelVisible = true
            self.onTrigger?()
        }
    }

    private func scheduleLeaveDebounce() {
        leaveTask?.cancel()
        leaveTask = Task { [weak self] in
            try? await Task.sleep(for: Self.leaveDebounce)
            guard !Task.isCancelled,
                  let self,
                  !self.mouseInTriggerZone,
                  !self.mouseInPanel
            else { return }
            self.isPanelVisible = false
            self.onDismiss?()
        }
    }

    // MARK: - Fullscreen Detection

    private func refreshFullscreenState() async {
        guard let quartzBounds = NSScreen.notched?.quartzBounds ?? NSScreen.main?.quartzBounds else { return }
        let detected = await Task.detached(priority: .utility) {
            Self.detectFullscreenActive(screenBounds: quartzBounds)
        }.value

        let wasFullscreen = isFullscreenActive
        isFullscreenActive = detected
        if detected, !wasFullscreen, isPanelVisible {
            dismissIfVisible()
        }
    }

    nonisolated private static func spaceChangeNotifications() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                let notifications = NSWorkspace.shared.notificationCenter.notifications(
                    named: NSWorkspace.activeSpaceDidChangeNotification
                )
                for await _ in notifications {
                    continuation.yield()
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Detects whether a standard window covers the screen in Quartz global coordinates.
    nonisolated static func detectFullscreenActive(screenBounds: CGRect) -> Bool {
        let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] ?? []

        for window in windowList {
            guard let layer = window[kCGWindowLayer as String] as? Int32, layer == 0,
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let w = bounds["Width"], let h = bounds["Height"],
                  let x = bounds["X"], let y = bounds["Y"]
            else { continue }

            let rect = CGRect(x: x, y: y, width: w, height: h)
            if abs(rect.origin.x - screenBounds.origin.x) < 5,
               abs(rect.origin.y - screenBounds.origin.y) < 5,
               abs(rect.width - screenBounds.width) < 5,
               abs(rect.height - screenBounds.height) < 5 {
                return true
            }
        }
        return false
    }
}
