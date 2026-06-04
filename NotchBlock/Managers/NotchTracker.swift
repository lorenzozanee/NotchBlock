import Cocoa
import Combine

/// Manages mouse tracking at the Mac notch region.
///
/// Creates a transparent, click-through window positioned at the screen's notch area.
/// When the mouse hovers for >= 0.5s, fires the panel trigger callback.
/// When the mouse leaves for > 0.3s, fires the panel dismiss callback.
/// Disables tracking when a fullscreen app is active (AC 2.4).
final class NotchTracker: ObservableObject {
    /// Published: whether the notch panel should be visible
    @Published var isPanelVisible = false

    /// Called when the hover debounce completes — panel should show
    var onTrigger: (() -> Void)?
    /// Called when the mouse leaves the panel area — panel should hide
    var onDismiss: (() -> Void)?

    // MARK: - Constants

    private static let notchWidth: CGFloat = 180
    private static let notchHeight: CGFloat = 32
    private static let hoverDebounce: TimeInterval = 0.5   // AC 2.1
    private static let leaveDebounce: TimeInterval = 0.5   // V2: slower, gentler dismissal

    // MARK: - State

    private var trackingWindow: NSWindow?
    private var hoverTimer: Timer?
    private var leaveTimer: Timer?
    private var mouseInNotch = false
    private var mouseInPanel = false
    private var isFullscreenActive = false

    /// Set by NotchBlockApp to prevent panel from showing when main window is open.
    var isMainWindowOpen = false

    private var cancellables = Set<AnyCancellable>()
    private var fullscreenCheckTimer: Timer?

    // MARK: - Lifecycle

    init() {
        setupFullscreenDetection()
    }

    deinit { teardown() }

    func start() {
        guard trackingWindow == nil else { return }
        createTrackingWindow()
        startFullscreenPolling()
        observeScreenChanges()
    }

    func teardown() {
        trackingWindow?.close()
        trackingWindow = nil
        hoverTimer?.invalidate()
        leaveTimer?.invalidate()
        fullscreenCheckTimer?.invalidate()
        cancellables.removeAll()
    }

    // MARK: - Tracking Window

    private func createTrackingWindow() {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.frame
        let screenWidth = screenFrame.width

        let notchOriginX = (screenWidth - Self.notchWidth) / 2
        let notchOriginY = screenFrame.height - Self.notchHeight

        let trackingRect = NSRect(
            x: screenFrame.origin.x + notchOriginX,
            y: screenFrame.origin.y + notchOriginY,
            width: Self.notchWidth,
            height: Self.notchHeight
        )

        let window = NSWindow(
            contentRect: trackingRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .statusBar
        window.ignoresMouseEvents = false // must receive mouse events for NSTrackingArea
        window.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        window.isMovable = false

        let trackingView = NotchTrackingView()
        trackingView.onMouseEntered = { [weak self] in self?.handleMouseEnter() }
        trackingView.onMouseExited = { [weak self] in self?.handleMouseExit() }
        window.contentView = trackingView

        let trackingArea = NSTrackingArea(
            rect: trackingView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: trackingView,
            userInfo: nil
        )
        trackingView.addTrackingArea(trackingArea)

        trackingWindow = window
        window.orderFront(nil)
    }

    // MARK: - Mouse Events

    private func handleMouseEnter() {
        guard !isFullscreenActive, !isMainWindowOpen else { return }
        mouseInNotch = true
        leaveTimer?.invalidate()
        leaveTimer = nil

        hoverTimer?.invalidate()
        hoverTimer = Timer.scheduledTimer(withTimeInterval: Self.hoverDebounce, repeats: false) { [weak self] _ in
            guard let self, self.mouseInNotch, !self.isFullscreenActive else { return }
            DispatchQueue.main.async {
                self.isPanelVisible = true
                self.onTrigger?()
            }
        }
    }

    private func handleMouseExit() {
        mouseInNotch = false
        hoverTimer?.invalidate()
        hoverTimer = nil
        if isPanelVisible && !mouseInPanel {
            scheduleLeaveDebounce()
        }
    }

    func setMouseInPanel(_ inPanel: Bool) {
        mouseInPanel = inPanel
        if !inPanel && !mouseInNotch && isPanelVisible {
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
                guard !self.mouseInNotch, !self.mouseInPanel else { return }
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

    private func observeScreenChanges() {
        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                // Recreate tracking window on the (possibly new) main screen
                DispatchQueue.main.async {
                    self?.trackingWindow?.close()
                    self?.trackingWindow = nil
                    self?.createTrackingWindow()
                }
            }
            .store(in: &cancellables)
    }

    private func startFullscreenPolling() {
        fullscreenCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkFullscreenState()
        }
    }

    private func checkFullscreenState() {
        // NSScreen.main is main-thread-only — hoist before dispatch.
        guard let screen = NSScreen.main else { return }
        let screenBounds = screen.frame

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let newState = Self.detectFullscreenActive(screenBounds: screenBounds)
            DispatchQueue.main.async {
                guard let self else { return }
                let wasFullscreen = self.isFullscreenActive
                self.isFullscreenActive = newState
                if newState && !wasFullscreen {
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

// MARK: - Tracking View

private final class NotchTrackingView: NSView {
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?

    override func mouseEntered(with event: NSEvent) { onMouseEntered?() }
    override func mouseExited(with event: NSEvent) { onMouseExited?() }
}
