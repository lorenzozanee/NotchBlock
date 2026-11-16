import Cocoa
import Observation
import SwiftUI

/// Manages the floating dropdown panel anchored below the notched display's menu bar.
@MainActor
final class NotchPanelController {
    @Observable
    @MainActor
    final class PresentationState {
        var isVisible = false

        init(isVisible: Bool = false) {
            self.isVisible = isVisible
        }
    }

    private var panel: NSPanel?
    private var hostingView: NSHostingView<NotchPanelView>?
    private weak var tracker: NotchTracker?
    private let store: TimeBlockStore
    private let presentation = PresentationState()
    private var hideGeneration = 0

    var onOpenMainWindow: (() -> Void)?

    private static let panelWidth: CGFloat = 320
    private static let showDuration: TimeInterval = 0.35
    private static let hideDuration: TimeInterval = 0.25

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
        hideGeneration += 1
        presentation.isVisible = true
        if panel == nil { createPanel() }
        guard let panel else { return }

        layoutAndPositionPanel()
        if panel.isVisible && panel.alphaValue > 0.99 {
            return
        }

        panel.alphaValue = 0
        panel.orderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Self.showDuration
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.1, 0.9, 0.2, 1.0)
            panel.animator().alphaValue = 1.0
        }
    }

    func hide() {
        guard let panel, presentation.isVisible else { return }
        presentation.isVisible = false
        tracker?.notifyPanelDismissed()
        let gen = hideGeneration
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = Self.hideDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.hideGeneration == gen else { return }
                self.panel?.orderOut(nil)
            }
        })
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
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        window.isMovable = false
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.animationBehavior = .none

        let trackingView = PanelTrackingView()
        trackingView.onMouseEntered = { [weak self] in self?.tracker?.setMouseInPanel(true) }
        trackingView.onMouseExited = { [weak self] in self?.tracker?.setMouseInPanel(false) }

        let panelView = NotchPanelView(store: store, presentation: presentation) { [weak self] in
            self?.hide()
            self?.onOpenMainWindow?()
        }

        let hosting = NSHostingView(rootView: panelView)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        trackingView.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: trackingView.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: trackingView.bottomAnchor),
            hosting.leadingAnchor.constraint(equalTo: trackingView.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: trackingView.trailingAnchor),
        ])

        let trackingArea = NSTrackingArea(
            rect: trackingView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect, .enabledDuringMouseDrag],
            owner: trackingView,
            userInfo: nil
        )
        trackingView.addTrackingArea(trackingArea)

        window.contentView = trackingView
        self.hostingView = hosting
        self.panel = window
    }

    private func layoutAndPositionPanel() {
        guard let panel,
              let hostingView,
              let screen = NSScreen.notched ?? NSScreen.main
        else { return }

        hostingView.layoutSubtreeIfNeeded()
        let fittingHeight = max(hostingView.fittingSize.height, 120)
        let sf = screen.frame
        let px = sf.origin.x + (sf.width - Self.panelWidth) / 2
        let py = sf.maxY - screen.topMenuBarHeight - fittingHeight
        panel.setFrame(NSRect(x: px, y: py, width: Self.panelWidth, height: fittingHeight), display: true, animate: false)
    }
}

// MARK: - Tracking View

private final class PanelTrackingView: NSView {
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?

    override func mouseEntered(with event: NSEvent) { onMouseEntered?() }
    override func mouseExited(with event: NSEvent) { onMouseExited?() }
}
