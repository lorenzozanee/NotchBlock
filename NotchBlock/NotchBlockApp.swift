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
    @State private var showOnboarding = false
    @State private var quickAddTitle = ""
    @AppStorage("menuBarIconStyle") private var iconStyle = "timer"
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    enum IconStyle: String, CaseIterable {
        case timer = "timer"
        case clock = "clock"
        case hourglass = "hourglass"
        case blocks = "blocks"

        var systemImage: String {
            switch self {
            case .timer: return "timer"
            case .clock: return "calendar.badge.clock"
            case .hourglass: return "hourglass"
            case .blocks: return "square.grid.3x3.fill"
            }
        }
        var label: String {
            switch self {
            case .timer: return "计时器"
            case .clock: return "日历时钟"
            case .hourglass: return "沙漏"
            case .blocks: return "方块"
            }
        }
    }

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
                    if !hasCompletedOnboarding {
                        showOnboarding = true
                    }
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView {
                        createSampleBlocks()
                    }
                }
                .sheet(isPresented: $showWeChatSettings) {
                    WeChatSettingsView(notifier: weChatNotifier)
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 480, height: 520)

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

        Menu("菜单栏图标") {
            ForEach(IconStyle.allCases, id: \.rawValue) { s in
                Button {
                    iconStyle = s.rawValue
                } label: {
                    HStack {
                        Image(systemName: s.systemImage)
                        Text(s.label)
                        if iconStyle == s.rawValue {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
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
        let style = IconStyle(rawValue: iconStyle) ?? .timer
        if let active = store.activeBlock() {
            if let remaining = active.remainingTime {
                let minutes = Int(remaining / 60)
                Image(systemName: style.systemImage)
                Text("\(minutes)m")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            } else {
                Image(systemName: style.systemImage)
            }
        } else if pending > 0 {
            Image(systemName: style.systemImage)
            Text("\(pending)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
        } else {
            Image(systemName: style.systemImage)
        }
    }

    // MARK: - First Launch

    private func createSampleBlocks() {
        guard store.todayBlocks().isEmpty else { return }
        let cal = Calendar.current
        let now = Date()
        let start = cal.startOfDay(for: now)
        let blocks: [TimeBlock] = [
            TimeBlock(title: "晨间规划", startTime: cal.date(byAdding: .hour, value: 9, to: start)!, endTime: cal.date(byAdding: .hour, value: 9, to: start)!.addingTimeInterval(900), status: .completed),
            TimeBlock(title: "深度工作", startTime: cal.date(byAdding: .hour, value: 10, to: start)!, endTime: cal.date(byAdding: .hour, value: 12, to: start)!, status: .pending),
            TimeBlock(title: "午休", startTime: cal.date(byAdding: .hour, value: 12, to: start)!, endTime: cal.date(byAdding: .hour, value: 13, to: start)!, status: .pending),
        ]
        for b in blocks { store.add(b) }
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
