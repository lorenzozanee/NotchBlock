import SwiftUI
import UserNotifications

@main
struct NotchBlockApp: App {
    @StateObject private var store: TimeBlockStore
    @StateObject private var notchTracker = NotchTracker()
    private let panelController: NotchPanelController
    private let overlayController: OverlayWindowController
    private let scheduler: BlockScheduler
    private let weChatNotifier: WeChatNotifier
    @State private var showWeChatSettings = false

    init() {
        // 1. Initialize all stored properties first
        let store = TimeBlockStore()
        _store = StateObject(wrappedValue: store)

        let panelCtrl = NotchPanelController(store: store)
        let overlayCtrl = OverlayWindowController()
        let sched = BlockScheduler(store: store)
        let wechat = WeChatNotifier()

        panelController = panelCtrl
        overlayController = overlayCtrl
        scheduler = sched
        weChatNotifier = wechat

        // 2. Wire dependencies (self is now fully initialized)
        panelCtrl.bind(to: notchTracker)
        wechat.loadConfiguration()

        overlayCtrl.onMarkCompleted = { block in
            let updated = TimeBlock(
                id: block.id, title: block.title,
                startTime: block.startTime, endTime: block.endTime,
                status: .completed
            )
            store.update(updated)
        }

        overlayCtrl.onAdjustSchedule = {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.canBecomeKey {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }

        sched.onBlockEnded = { [weak overlayCtrl, weak wechat] block in
            overlayCtrl?.show(for: block)
            wechat?.sendBlockEndedNotification(for: block)
        }
    }

    var body: some Scene {
        // Main scheduler window — opened from menu bar
        WindowGroup {
            MainSchedulerView(
                store: store,
                stats: StatisticsStore(store: store)
            )
                .onAppear {
                    notchTracker.start()
                    scheduler.start()
                    overlayController.requestNotificationPermission()
                    handleFirstLaunch()
                }
                .sheet(isPresented: $showWeChatSettings) {
                    WeChatSettingsView(notifier: weChatNotifier)
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 460, height: 500)

        // Menu bar item — always visible, lightweight
        MenuBarExtra {
            menuBarContent
        } label: {
            menuBarIcon
        }
    }

    // MARK: - Menu Bar Content

    @ViewBuilder
    private var menuBarContent: some View {
        // Quick status overview
        if let active = store.activeBlock() {
            VStack(alignment: .leading, spacing: 4) {
                Text("当前任务").font(.caption).foregroundStyle(.secondary)
                Text(active.title).font(.headline)
                if let remaining = active.remainingTime {
                    Text("剩余 \(remaining.countdownString)")
                        .font(.caption.monospacedDigit())
                }
            }
            .padding(.vertical, 4)
            Divider()
        }

        Button("打开排程面板") {
            openMainWindow()
        }
        .keyboardShortcut("o")

        Divider()

        if let next = store.upcomingBlocks(after: Date(), limit: 1).first {
            Button("下一任务：\(next.title) (\(next.startTime.timeString))") {
                openMainWindow()
            }
            .disabled(true) // display-only
        }

        Divider()

        Button("微信通知设置...") {
            showWeChatSettings = true
        }

        Divider()

        Toggle(isOn: Binding(
            get: { LaunchManager.isLoginItemEnabled },
            set: { enabled in try? LaunchManager.setLoginItemEnabled(enabled) }
        )) {
            Text("开机自动启动")
        }

        Divider()

        Button("退出 NotchBlock") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    // MARK: - Menu Bar Icon

    @ViewBuilder
    private var menuBarIcon: some View {
        if let active = store.activeBlock() {
            // Show active indicator with remaining time
            if let remaining = active.remainingTime {
                let minutes = Int(remaining / 60)
                Image(systemName: "timer")
                Text("\(minutes)m")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            } else {
                Image(systemName: "timer")
            }
        } else {
            Image(systemName: "calendar.badge.clock")
        }
    }

    // MARK: - First Launch

    private let firstLaunchKey = "hasLaunchedBefore"

    private func handleFirstLaunch() {
        guard !UserDefaults.standard.bool(forKey: firstLaunchKey) else { return }
        UserDefaults.standard.set(true, forKey: firstLaunchKey)

        // Auto-show the scheduler window so users aren't confused by LSUIElement behavior
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.canBecomeKey {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }

        // Send a welcome notification to confirm the app is running
        sendWelcomeNotification()
    }

    private func sendWelcomeNotification() {
        let content = UNMutableNotificationContent()
        content.title = "NotchBlock 已就绪"
        content.body = "点击菜单栏日历图标查看排程。鼠标悬停在 Mac 刘海即可快速预览今日任务。"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "welcome-\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Helpers

    private func openMainWindow() {
        // Activate app and bring scheduler window to front
        NSApp.activate(ignoringOtherApps: true)
        // Find or open the main window
        for window in NSApp.windows where window.title.contains("排程") || window.canBecomeKey {
            window.makeKeyAndOrderFront(nil)
            return
        }
        // If no window found, open a new one via Window menu
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
