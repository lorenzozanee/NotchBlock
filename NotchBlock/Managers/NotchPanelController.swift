import Cocoa
import SwiftUI

/// Manages the floating dropdown panel that appears below the notch (V2).
///
/// Changes from V1:
/// - Dynamic panel height via `fittingSize` (no longer hardcoded 180px)
/// - Slower leave-debounce (0.5s instead of 0.3s) for gentler dismissal
/// - Timer lifecycle managed by NotchPanelView (onAppear/onDisappear)
/// - Accepts `onOpenMainWindow` callback for routing taps to main scheduler
final class NotchPanelController {
    private var panel: NSPanel?
    private weak var tracker: NotchTracker?
    private let store: TimeBlockStore
    private var hideGeneration = 0

    /// Called when user taps a task or quick-add — opens the main scheduler window.
    var onOpenMainWindow: (() -> Void)?

    // MARK: - Auto-dismiss (for pet-triggered shows)

    private var autoDismissTimer: Timer?
    private var clickOutsideMonitor: Any?
    private var isAutoDismissEnabled = false

    private static let panelWidth: CGFloat = 320
    private static let animationDuration: TimeInterval = 0.25
    private static let autoDismissTimeout: TimeInterval = 5.0

    init(store: TimeBlockStore) {
        self.store = store
    }

    func bind(to tracker: NotchTracker) {
        self.tracker = tracker
        tracker.onTrigger = { [weak self] in self?.show() }
        tracker.onDismiss = { [weak self] in self?.hide() }
    }

    // MARK: - Show / Hide

    func show() {
        hideGeneration += 1  // cancel any in-flight hide completion
        if panel == nil { createPanel() }
        guard let panel else { return }

        resizePanelToFitContent()
        updatePanelPosition()
        panel.alphaValue = 0
        panel.orderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.4
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.1, 0.9, 0.2, 1.0)
            panel.animator().alphaValue = 1.0
        }
    }

    func hide() {
        guard let panel else { return }
        let gen = hideGeneration
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = Self.animationDuration + 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, self.hideGeneration == gen else { return }
            self.panel?.orderOut(nil)
            self.teardownAutoDismiss()
        })
    }

    // MARK: - Auto-Dismiss (Pet-Triggered)

    /// Show the panel with a 5-second auto-dismiss timer and
    /// click-outside-to-dismiss via global event monitor.
    /// Used when the pet triggers the panel (no NotchTracker hover).
    func showWithAutoDismiss() {
        show()
        setupAutoDismiss()
    }

    private func setupAutoDismiss() {
        teardownAutoDismiss()
        isAutoDismissEnabled = true

        // 5-second auto-dismiss timer
        autoDismissTimer = Timer.scheduledTimer(
            withTimeInterval: Self.autoDismissTimeout,
            repeats: false
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.hide()
            }
        }

        // Click-outside-to-dismiss via global event monitor
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self,
                  let panel = self.panel,
                  self.isAutoDismissEnabled,
                  panel.isVisible
            else { return }

            let clickLocation = NSEvent.mouseLocation
            if !panel.frame.contains(clickLocation) {
                DispatchQueue.main.async {
                    self.hide()
                }
            }
        }
    }

    private func teardownAutoDismiss() {
        isAutoDismissEnabled = false
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
    }

    // MARK: - Panel Setup

    private func createPanel() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.panelWidth, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        window.isMovable = false
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none

        let trackingView = PanelTrackingView()
        trackingView.onMouseEntered = { [weak self] in self?.tracker?.setMouseInPanel(true) }
        trackingView.onMouseExited = { [weak self] in self?.tracker?.setMouseInPanel(false) }

        let panelView = NotchPanelView(store: store) { [weak self] in
            self?.onOpenMainWindow?()
        }

        let hostingView = NSHostingView(rootView: panelView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        trackingView.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: trackingView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: trackingView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: trackingView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trackingView.trailingAnchor),
        ])

        let trackingArea = NSTrackingArea(
            rect: trackingView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect, .enabledDuringMouseDrag],
            owner: trackingView,
            userInfo: nil
        )
        trackingView.addTrackingArea(trackingArea)

        window.contentView = trackingView
        panel = window
    }

    private func updatePanelPosition() {
        guard let screen = NSScreen.main, let panel else { return }
        let sf = screen.frame
        let px = sf.origin.x + (sf.width - Self.panelWidth) / 2
        let py = sf.origin.y + sf.height - 36 - panel.frame.height
        panel.setFrame(NSRect(x: px, y: py, width: Self.panelWidth, height: panel.frame.height), display: true)
    }

    /// Resizes the NSPanel to fit the SwiftUI content's intrinsic size.
    private func resizePanelToFitContent() {
        guard let panel,
              let hostingView = panel.contentView?.subviews.first(where: { $0 is NSHostingView<NotchPanelView> })
        else { return }

        hostingView.layoutSubtreeIfNeeded()
        let fittingSize = hostingView.fittingSize
        guard fittingSize.height > 0 else { return }

        let newHeight = fittingSize.height
        guard let screen = NSScreen.main else { return }
        let sf = screen.frame
        let px = sf.origin.x + (sf.width - Self.panelWidth) / 2
        let py = sf.origin.y + sf.height - 36 - newHeight
        panel.setFrame(NSRect(x: px, y: py, width: Self.panelWidth, height: newHeight), display: true, animate: false)
    }
}

// MARK: - Tracking View

private final class PanelTrackingView: NSView {
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?

    override func mouseEntered(with event: NSEvent) { onMouseEntered?() }
    override func mouseExited(with event: NSEvent) { onMouseExited?() }
}
