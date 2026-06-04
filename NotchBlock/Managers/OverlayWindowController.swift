import Cocoa
import SwiftUI
import UserNotifications

/// Manages the hard-interrupt fullscreen overlay that appears when a time block ends.
///
/// Creates an NSPanel at CGShieldingWindowLevel to cover all applications,
/// including fullscreen spaces (AC 3.4). Handles 5-minute timeout auto-mark-as-missed (AC 3.3).
final class OverlayWindowController: ObservableObject {
    private var overlayPanel: NSPanel?
    private var currentBlock: TimeBlock?
    private var timeoutTimer: Timer?

    var onMarkCompleted: ((TimeBlock) -> Void)?
    var onAdjustSchedule: (() -> Void)?

    // MARK: - Constants

    private static let overlayOpacity: CGFloat = 0.7       // AC 3.1
    private static let timeoutSeconds: TimeInterval = 300   // AC 3.3

    // MARK: - Public API

    func show(for block: TimeBlock) {
        dismiss()

        currentBlock = block
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame

        let panel = NSPanel(
            contentRect: screenFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = NSWindow.Level(Int(CGShieldingWindowLevel()))
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.ignoresMouseEvents = false // AC 3.1: block clicks underneath
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.canHide = false

        let overlayView = OverlayView(
            block: block,
            onCompleted: { [weak self] in self?.handleCompleted() },
            onAdjust: { [weak self] in self?.handleAdjust() }
        )
        let hostingView = NSHostingView(rootView: overlayView)
        hostingView.frame = screenFrame
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        overlayPanel = panel
        NSSound(named: "Glass")?.play()
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 1.0
        }

        startTimeout()
    }

    func dismiss() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        guard let panel = overlayPanel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.overlayPanel?.orderOut(nil)
            self?.overlayPanel = nil
            self?.currentBlock = nil
        })
    }

    var isVisible: Bool { overlayPanel != nil }

    // MARK: - Actions

    private func handleCompleted() {
        guard let block = currentBlock else { return }
        dismiss()
        onMarkCompleted?(block)
    }

    private func handleAdjust() {
        dismiss()
        onAdjustSchedule?()
    }

    // MARK: - Timeout (AC 3.3)

    private func startTimeout() {
        timeoutTimer?.invalidate()
        timeoutTimer = Timer.scheduledTimer(
            withTimeInterval: Self.timeoutSeconds,
            repeats: false
        ) { [weak self] _ in
            guard let self, let block = self.currentBlock else { return }
            DispatchQueue.main.async {
                self.handleTimeout(block: block)
            }
        }
    }

    private func handleTimeout(block: TimeBlock) {
        // The block is marked as missed by the caller via onMarkCompleted
        onMarkCompleted?(block)
        dismiss()
        sendMissedNotification(for: block)
    }

    // MARK: - Notifications

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("[NotchBlock] Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    private func sendMissedNotification(for block: TimeBlock) {
        let content = UNMutableNotificationContent()
        content.title = "任务超时 — \(block.title)"
        content.body = "你未在 5 分钟内响应，任务已自动标记为「未完成」。"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "missed-\(block.id.uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
