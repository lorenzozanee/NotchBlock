import Cocoa
import Combine

/// Detects mouse hover at the MacBook notch via global cursor polling.
///
/// NSTrackingArea at the menu bar / notch region is fundamentally broken on macOS 14+:
/// the Window Server permanently intercepts mouse events in the top ~37px regardless
/// of NSWindow level. Instead, we poll `NSEvent.mouseLocation` at 10 Hz — this reads
/// cursor position directly from the Window Server shared memory, bypassing the event
/// delivery pipeline entirely.
///
/// Trigger zone: top 5 px of the screen, 180 px wide centered at the notch position.
/// When the mouse stays in this zone for >= 0.5 s, the panel trigger callback fires.
/// When the mouse leaves both the zone and the panel for > 0.5 s, the dismiss fires.
/// Disables tracking when a fullscreen app is active (AC 2.4).
final class NotchTracker {
    /// Whether the notch panel should be visible (set internally, read by callbacks).
    var isPanelVisible = false

    /// Called when the hover debounce completes — panel should show
    var onTrigger: (() -> Void)?
    /// Called when the mouse leaves the panel area — panel should hide
    var onDismiss: (() -> Void)?

    // MARK: - Constants

    /// Width of the trigger zone at the top of the screen (same as notch width).
    private static let notchWidth: CGFloat = 180
    /// Height of the trigger zone at the very top edge of the screen.
    /// Narrow enough to require deliberate cursor push; 10 Hz polling gives
    /// ~5 consecutive in-zone readings within 500 ms debounce.
    private static let triggerZoneHeight: CGFloat = 5
    private static let hoverDebounce: TimeInterval = 0.5
    private static let leaveDebounce: TimeInterval = 0.5
    private static let pollInterval: TimeInterval = 0.1

    // MARK: - State

    private var pollTimer: Timer?
    private var hoverTimer: Timer?
    private var leaveTimer: Timer?
    private var mouseInTriggerZone = false
    private var mouseInPanel = false
    private var isFullscreenActive = false

    /// Computed: true when the main scheduler window is visible.
    /// Uses NSApp.windows — fast, no CGWindowList overhead.
    /// SwiftUI Window(id:"main") sets the identifier on the backing NSWindow.
    var isMainWindowOpen: Bool {
        NSApp.windows.contains { $0.isVisible && $0.identifier?.rawValue == "main" }
    }

    /// Debug: exposes internal state for testing.
    var debugDescription: String {
        "NotchTracker(polling: \(pollTimer != nil), fullscreen: \(isFullscreenActive), mainWin: \(isMainWindowOpen), inZone: \(mouseInTriggerZone), inPanel: \(mouseInPanel), panel: \(isPanelVisible))"
    }

    private var cancellables = Set<AnyCancellable>()
    private var fullscreenCheckTimer: Timer?

    // MARK: - Lifecycle

    init() {
        setupFullscreenDetection()
    }

    deinit { teardown() }

    func start() {
        guard pollTimer == nil else { return }
        // Defer timer scheduling until the run loop is active.
        // Timer.scheduledTimer in init() runs before NSApplication.run(),
        // so the timer is added to a run loop that isn't processing yet.
        // Defer timer scheduling — Timer.scheduledTimer in init() adds to a
        // run loop that hasn't started processing yet.
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) { [weak self] in
            guard let self else { return }
            self.pollTimer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
                self?.pollMousePosition()
            }
            self.pollTimer?.tolerance = 0.02
        }
        startFullscreenPolling()
    }

    func teardown() {
        pollTimer?.invalidate()
        pollTimer = nil
        hoverTimer?.invalidate()
        leaveTimer?.invalidate()
        fullscreenCheckTimer?.invalidate()
        cancellables.removeAll()
    }

    // MARK: - Mouse Position Polling

    private func pollMousePosition() {
        guard !isFullscreenActive, !isMainWindowOpen else { return }

        guard let screen = findNotchScreen() else { return }
        let mouse = NSEvent.mouseLocation  // Cocoa screen coords (origin bottom-left)
        let inZone = isMouseInTriggerZone(mouse, screen: screen)

        if inZone && !mouseInTriggerZone {
            // Mouse entered trigger zone
            mouseInTriggerZone = true
            leaveTimer?.invalidate()
            leaveTimer = nil
            scheduleHoverDebounce()
        } else if !inZone && mouseInTriggerZone {
            // Mouse left trigger zone
            mouseInTriggerZone = false
            hoverTimer?.invalidate()
            hoverTimer = nil
            if isPanelVisible, !mouseInPanel {
                scheduleLeaveDebounce()
            }
        }
    }

    /// Returns the screen that has a notch, or nil on notch-less Macs / external displays.
    private func findNotchScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
    }

    /// Checks whether the given mouse position falls within the notch trigger zone.
    ///
    /// The zone spans the top `triggerZoneHeight` pixels of the screen, centered
    /// horizontally over the notch position.
    private func isMouseInTriggerZone(_ mouse: NSPoint, screen: NSScreen) -> Bool {
        let sf = screen.frame
        let centerX = sf.origin.x + sf.width / 2
        let leftX = centerX - Self.notchWidth / 2
        let rightX = centerX + Self.notchWidth / 2
        let topY = sf.origin.y + sf.height
        let bottomY = topY - Self.triggerZoneHeight

        return mouse.x >= leftX && mouse.x <= rightX
            && mouse.y >= bottomY && mouse.y <= topY
    }

    // MARK: - Debounce Timers

    private func scheduleHoverDebounce() {
        hoverTimer?.invalidate()
        hoverTimer = Timer.scheduledTimer(withTimeInterval: Self.hoverDebounce, repeats: false) { [weak self] _ in
            guard let self, self.mouseInTriggerZone, !self.isFullscreenActive else { return }
            DispatchQueue.main.async {
                self.isPanelVisible = true
                self.onTrigger?()
            }
        }
    }

    /// Called by NotchPanelController when the mouse enters or exits the panel.
    func setMouseInPanel(_ inPanel: Bool) {
        mouseInPanel = inPanel
        if !inPanel, !mouseInTriggerZone, isPanelVisible {
            scheduleLeaveDebounce()
        } else if inPanel {
            leaveTimer?.invalidate()
            leaveTimer = nil
        }
    }

    private func scheduleLeaveDebounce() {
        leaveTimer?.invalidate()
        leaveTimer = Timer.scheduledTimer(withTimeInterval: Self.leaveDebounce, repeats: false) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                guard !self.mouseInTriggerZone, !self.mouseInPanel else { return }
                self.isPanelVisible = false
                self.onDismiss?()
            }
        }
    }

    // MARK: - Fullscreen Detection (AC 2.4)

    private func setupFullscreenDetection() {
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
            .sink { [weak self] _ in self?.checkFullscreenState() }
            .store(in: &cancellables)
    }

    private func startFullscreenPolling() {
        fullscreenCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkFullscreenState()
        }
    }

    private func checkFullscreenState() {
        guard let screen = NSScreen.main else { return }
        let screenBounds = screen.frame

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let newState = Self.detectFullscreenActive(screenBounds: screenBounds)
            DispatchQueue.main.async {
                guard let self else { return }
                let wasFullscreen = self.isFullscreenActive
                self.isFullscreenActive = newState
                if newState, !wasFullscreen {
                    self.isPanelVisible = false
                    self.onDismiss?()
                }
            }
        }
    }

    static func detectFullscreenActive(screenBounds: CGRect) -> Bool {
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
