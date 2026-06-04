import SwiftUI
import UserNotifications
import AppKit
import OSLog

extension Notification.Name {
    static let openMainWindow = Notification.Name("com.notchblock.openMainWindow")
}

@main
struct NotchBlockApp: App {
    @StateObject private var store: TimeBlockStore
    private let notchTracker = NotchTracker()
    private let panelController: NotchPanelController
    private let overlayController: OverlayWindowController
    private let scheduler: BlockScheduler
    private let weChatNotifier: WeChatNotifier
    private let breakScheduler: BreakScheduler
    private let statsStore: StatisticsStore
    @State private var showWeChatSettings = false
    @State private var quickAddTitle = ""

    init() {
        // 1. Initialize all stored properties first
        let store = TimeBlockStore()
        _store = StateObject(wrappedValue: store)

        let panelCtrl = NotchPanelController(store: store)
        let overlayCtrl = OverlayWindowController()
        let sched = BlockScheduler(store: store)
        let wechat = WeChatNotifier()
        let breaks = BreakScheduler(store: store)
        let stats = StatisticsStore(store: store)

        panelController = panelCtrl
        overlayController = overlayCtrl
        scheduler = sched
        weChatNotifier = wechat
        breakScheduler = breaks
        statsStore = stats

        // 2. Wire dependencies (self is now fully initialized)
        panelCtrl.bind(to: notchTracker)
        store.onDidChange = { [weak breaks] in breaks?.regenerateBreaks() }
        wechat.loadConfiguration()

        // 3. Start background services immediately — NOT dependent on main window.
        notchTracker.start()
        scheduler.start()
        overlayController.requestNotificationPermission()

        // 4. SwiftUI Window scenes show by default — hide the main window after
        //    launch so notch tracking isn't permanently blocked. The window
        //    reopens on demand via menu bar "打开排程面板" or notch panel tap.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            for window in NSApp.windows where window.identifier?.rawValue == "main" {
                window.close()
            }
        }

        // Route notch panel taps to open the main window
        panelCtrl.onOpenMainWindow = { [weak panelCtrl] in
            panelCtrl?.hide()
            NotificationCenter.default.post(name: .openMainWindow, object: nil)
        }

        overlayCtrl.onMarkCompleted = { store.update($0.with(status: .completed)) }
        overlayCtrl.onMarkMissed = { store.update($0.with(status: .missed)) }

        overlayCtrl.onAdjustSchedule = {
            NotificationCenter.default.post(name: .openMainWindow, object: nil)
        }

        sched.onBlockEnded = { [weak overlayCtrl, weak wechat] block in
            overlayCtrl?.show(for: block)
            wechat?.sendBlockEndedNotification(for: block)
        }
    }

    var body: some Scene {
        // Main scheduler window — explicitly managed via id for programmatic reopen
        Window("排程面板", id: "main") {
            MainSchedulerView(store: store, stats: statsStore)
                .onAppear {
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

        // Quick-add: type name → creates 30-min block starting now
        HStack {
            TextField("快速添加任务...", text: $quickAddTitle)
                .textFieldStyle(.plain)
                .frame(width: 140)
                .onSubmit { quickAdd() }
            Button("添加") { quickAdd() }
                .disabled(quickAddTitle.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 4)

        Divider()

        OpenMainWindowButton()
            .keyboardShortcut("o")

        Divider()

        if let next = store.upcomingBlocks(after: Date(), limit: 1).first {
            Button("下一任务：\(next.title) (\(next.startTime.timeString))") {}
            .disabled(true) // display-only
        }

        Divider()

        Button("导出数据...") {
            exportData()
        }

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
        let pending = store.todayBlocks().filter { $0.status == .pending }.count
        if let active = store.activeBlock() {
            if let remaining = active.remainingTime {
                let minutes = Int(remaining / 60)
                Image(systemName: "timer")
                Text("\(minutes)m")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            } else {
                Image(systemName: "timer")
            }
        } else if pending > 0 {
            Image(systemName: "calendar.badge.clock")
            Text("\(pending)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
        } else {
            Image(systemName: "calendar.badge.clock")
        }
    }

    // MARK: - First Launch

    private let firstLaunchKey = "hasLaunchedBefore"

    private func handleFirstLaunch() {
        guard !UserDefaults.standard.bool(forKey: firstLaunchKey) else { return }
        UserDefaults.standard.set(true, forKey: firstLaunchKey)

        // Send a welcome notification — tells user the app is running and
        // explains how to access the scheduler (menu bar or notch hover).
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

    private func exportData() {
        let savePanel = NSSavePanel()
        savePanel.title = "导出时间块数据"
        savePanel.nameFieldStringValue = "NotchBlock-备份-\(Date().timeString).json"
        savePanel.allowedContentTypes = [.json]

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            do {
                let data = try encoder.encode(self.store.blocks)
                try data.write(to: url)
            } catch {
                Logger(subsystem: "com.notchblock.app", category: "Export").error("Export failed: \(error.localizedDescription)")
            }
        }
    }

    private func quickAdd() {
        let title = quickAddTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let block = TimeBlock(
            title: title,
            startTime: Date(),
            endTime: Date().addingTimeInterval(1800) // 30 min default
        )
        store.add(block)
        quickAddTitle = ""
    }

}

// MARK: - Open Main Window Button

/// Wraps the menu bar "打开排程面板" button with access to `openWindow` environment.
/// Uses `Window(id: "main")` scene to reopen the scheduler window after user closes it.
private struct OpenMainWindowButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("打开排程面板") {
            openMainWindow()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openMainWindow)) { _ in
            openMainWindow()
        }
    }

    private func openMainWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}
