import Cocoa
import SwiftUI

/// Manages the floating dropdown panel that appears below the notch.
///
/// Creates an NSPanel with .nonactivatingPanel style so it floats above other windows
/// but doesn't steal focus. Handles slide-down/slide-up animations and mouse tracking
/// for auto-dismiss (AC 2.3).
final class NotchPanelController: ObservableObject {
    private var panel: NSPanel?
    private weak var tracker: NotchTracker?
    private let store: TimeBlockStore

    // MARK: - Constants

    private static let panelWidth: CGFloat = 320
    private static let panelHeight: CGFloat = 180
    private static let animationDuration: TimeInterval = 0.25

    init(store: TimeBlockStore) {
        self.store = store
    }

    /// Wire up to the notch tracker so panel shows/hides based on hover
    func bind(to tracker: NotchTracker) {
        self.tracker = tracker

        tracker.onTrigger = { [weak self] in
            self?.show()
        }
        tracker.onDismiss = { [weak self] in
            self?.hide()
        }
    }

    // MARK: - Show / Hide

    func show() {
        if panel == nil { createPanel() }
        guard let panel else { return }

        updatePanelPosition()
        panel.alphaValue = 0
        panel.orderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.2, 1.0)
            panel.animator().alphaValue = 1.0
        }
    }

    func hide() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = Self.animationDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel?.orderOut(nil)
        })
    }

    // MARK: - Panel Setup

    private func createPanel() {
        let contentRect = NSRect(x: 0, y: 0, width: Self.panelWidth, height: Self.panelHeight)

        let window = NSPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        window.isMovable = false
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none

        // Use a tracking-capable wrapper view for auto-dismiss (AC 2.3)
        let trackingView = PanelTrackingView()
        trackingView.onMouseEntered = { [weak self] in
            self?.tracker?.setMouseInPanel(true)
        }
        trackingView.onMouseExited = { [weak self] in
            self?.tracker?.setMouseInPanel(false)
        }

        let hostingView = NSHostingView(
            rootView: NotchPanelView(store: store)
        )
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
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: trackingView,
            userInfo: nil
        )
        trackingView.addTrackingArea(trackingArea)

        window.contentView = trackingView
        panel = window
        updatePanelPosition()
    }

    private func updatePanelPosition() {
        guard let screen = NSScreen.main, let panel else { return }
        let screenFrame = screen.frame

        let panelX = screenFrame.origin.x + (screenFrame.width - Self.panelWidth) / 2
        let panelY = screenFrame.origin.y + screenFrame.height - 36 - Self.panelHeight

        panel.setFrame(
            NSRect(x: panelX, y: panelY, width: Self.panelWidth, height: Self.panelHeight),
            display: true
        )
    }

}

// MARK: - Tracking View

/// Custom NSView that forwards mouse enter/exit to callbacks for panel auto-dismiss
private final class PanelTrackingView: NSView {
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?

    override func mouseEntered(with event: NSEvent) { onMouseEntered?() }
    override func mouseExited(with event: NSEvent) { onMouseExited?() }
}
