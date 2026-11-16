import Cocoa
import OSLog
import SwiftUI
import UserNotifications

private let overlayLogger = Logger(subsystem: "com.notchblock.app", category: "Overlay")

/// Borderless panel that can accept keyboard focus for custom duration input.
private final class KeyableOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Manages the hard-interrupt fullscreen overlay covering all displays when a time block ends.
@MainActor
final class OverlayWindowController {
    private var overlayPanels: [NSPanel] = []
    private var closingPanels: [UUID: [NSPanel]] = [:]
    private var currentBlock: TimeBlock?
    private var pendingQueue: [TimeBlock] = []
    nonisolated(unsafe) private var timeoutTask: Task<Void, Never>?

    var onMarkCompleted: ((TimeBlock) -> Void)?
    var onMarkMissed: ((TimeBlock) -> Void)?
    var onAdjustSchedule: (() -> Void)?
    var onExtendBlock: ((TimeBlock, TimeInterval, Bool) -> Void)?
    var subsequentTaskCountProvider: ((TimeBlock) -> Int)?

    // MARK: - Sound

    static let availableSounds = ["Glass", "Ping", "Pop", "Basso", "Funk", "Submarine"]

    static func playAlertSound() {
        let name = UserDefaults.standard.string(forKey: "alertSoundName") ?? "Glass"
        NSSound(named: name)?.play()
    }

    // MARK: - Constants

    private static let timeoutDuration: Duration = .seconds(300)

    var isVisible: Bool { !overlayPanels.isEmpty }

    deinit {
        timeoutTask?.cancel()
    }

    // MARK: - Public API

    func show(for block: TimeBlock) {
        if isVisible {
            if currentBlock?.id != block.id && !pendingQueue.contains(where: { $0.id == block.id }) {
                pendingQueue.append(block)
            }
            return
        }

        present(block: block)
    }

    func dismiss() {
        timeoutTask?.cancel()
        timeoutTask = nil
        let panelsToClose = overlayPanels
        overlayPanels.removeAll()
        currentBlock = nil
        guard !panelsToClose.isEmpty else { return }

        let token = UUID()
        closingPanels[token] = panelsToClose

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            for panel in panelsToClose {
                panel.animator().alphaValue = 0
            }
        }, completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                self?.finishClosing(token: token)
            }
        })
    }

    private func finishClosing(token: UUID) {
        guard let panels = closingPanels.removeValue(forKey: token) else { return }
        for panel in panels {
            panel.orderOut(nil)
        }
    }

    // MARK: - Presentation

    private func present(block: TimeBlock) {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        let primaryScreen = NSScreen.main ?? screens[0]
        currentBlock = block
        let subsequentCount = subsequentTaskCountProvider?(block) ?? 0
        var newPanels: [NSPanel] = []
        var primaryPanel: NSPanel?

        for screen in screens {
            let screenFrame = screen.frame
            let isPrimary = (screen == primaryScreen)
            let panel = KeyableOverlayPanel(
                contentRect: screenFrame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.level = NSWindow.Level(Int(CGShieldingWindowLevel()))
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.ignoresMouseEvents = false
            panel.isMovable = false
            panel.isReleasedWhenClosed = false
            panel.hidesOnDeactivate = false
            panel.canHide = false

            if isPrimary {
                let overlayView = OverlayView(
                    block: block,
                    subsequentTaskCount: subsequentCount,
                    onCompleted: { [weak self] in self?.handleCompleted() },
                    onAdjust: { [weak self] in self?.handleAdjust() },
                    onExtend: { [weak self] seconds, shiftAll in self?.handleExtend(seconds, shiftAll: shiftAll) }
                )
                let hosting = NSHostingView(rootView: overlayView)
                hosting.frame = NSRect(origin: .zero, size: screenFrame.size)
                hosting.autoresizingMask = [.width, .height]
                panel.contentView = hosting
                primaryPanel = panel
            } else {
                let backdropHosting = NSHostingView(rootView: SecondaryOverlayBackdrop())
                backdropHosting.frame = NSRect(origin: .zero, size: screenFrame.size)
                backdropHosting.autoresizingMask = [.width, .height]
                panel.contentView = backdropHosting
            }

            panel.alphaValue = 0
            panel.orderFrontRegardless()
            newPanels.append(panel)
        }

        overlayPanels = newPanels
        primaryPanel?.makeKey()
        Self.playAlertSound()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            for panel in newPanels {
                panel.animator().alphaValue = 1.0
            }
        }

        startTimeout(for: block)
    }

    private func showNextQueuedIfAny() {
        guard !pendingQueue.isEmpty else { return }
        let next = pendingQueue.removeFirst()
        present(block: next)
    }

    // MARK: - Actions

    private func handleCompleted() {
        guard let block = currentBlock else { return }
        dismiss()
        onMarkCompleted?(block)
        showNextQueuedIfAny()
    }

    private func handleAdjust() {
        pendingQueue.removeAll()
        dismiss()
        onAdjustSchedule?()
    }

    private func handleExtend(_ seconds: TimeInterval, shiftAll: Bool) {
        guard let block = currentBlock else { return }
        dismiss()
        onExtendBlock?(block, seconds, shiftAll)
        showNextQueuedIfAny()
    }

    // MARK: - Timeout

    private func startTimeout(for block: TimeBlock) {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: Self.timeoutDuration)
            guard !Task.isCancelled, let self, self.currentBlock?.id == block.id else { return }
            self.handleTimeout(block: block)
        }
    }

    private func handleTimeout(block: TimeBlock) {
        dismiss()
        onMarkMissed?(block)
        sendMissedNotification(for: block)
        showNextQueuedIfAny()
    }

    // MARK: - Notifications

    func scheduleDailySummary(stats: StatisticsStore, now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily-summary"])

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 21
        components.minute = 0

        guard let targetDate = calendar.date(from: components),
              targetDate > now,
              stats.todayTotal > 0
        else { return }

        let content = UNMutableNotificationContent()
        content.title = "今日 NotchBlock 统计"
        content.body = "完成 \(stats.todayCompleted)/\(stats.todayTotal) 项任务，专注 \(stats.todayFocusTime.compactDuration)"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: "daily-summary", content: content, trigger: trigger))
    }

    func requestNotificationPermission() {
        Task {
            do {
                _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                overlayLogger.error("Notification permission: \(error.localizedDescription)")
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

private struct SecondaryOverlayBackdrop: View {
    var body: some View {
        ZStack {
            VisualEffectBackdrop(material: .fullScreenUI, blendingMode: .behindWindow)
            BrandColors.overlayScrim
        }
        .ignoresSafeArea()
    }
}
