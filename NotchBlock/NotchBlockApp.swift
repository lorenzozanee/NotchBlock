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
    private let onboardingWC = OnboardingWindowController()
    private let updateChecker = UpdateChecker()
    private var petController: PetWindowController?
    @State private var showWeChatSettings = false
    @State private var showWhatsNew = false
    @State private var whatsNewVersion = ""
    @State private var whatsNewChangelog = ""
    @State private var quickAddTitle = ""
    @AppStorage("menuBarIconStyle") private var iconStyle = "timer"
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("showTimeInMenuBar") private var showTimeInMenuBar = true

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

        // 5. Initialize desktop pet if enabled
        let petPrefs = PetPreferences()
        if petPrefs.isEnabled {
            let petSM = PetStateMachine(store: store, preferences: petPrefs)
            let petAP = PetAnimationPlayer()
            let petWC = PetWindowController(
                store: store,
                stateMachine: petSM,
                animationPlayer: petAP,
                preferences: petPrefs
            )
            petWC.onOpenNotchPanel = { [weak panelCtrl] in
                panelCtrl?.show()
            }
            petWC.onHidePet = {
                var prefs = PetPreferences()
                prefs.isEnabled = false
            }
            petWC.onSwitchPet = { petID in
                var prefs = PetPreferences()
                prefs.selectedPet = petID
                // reload will happen next launch or via settings
            }
            petWC.show()
            petWC.startWatchdog()
            petController = petWC
        }
        overlayController.scheduleDailySummary(stats: stats)
        updateChecker.startAutoCheck()

        // 4. Show onboarding if first launch, then hide the main window.
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            onboardingWC.show(store: store)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else { return }
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

        overlayCtrl.subsequentTaskCountProvider = {
            let today = store.todayBlocks().sorted { $0.startTime < $1.startTime }
            return today.filter { $0.startTime >= (today.first?.endTime ?? Date()) }.count
        }

        overlayCtrl.onAdjustSchedule = {
            NotificationCenter.default.post(name: .openMainWindow, object: nil)
        }

        overlayCtrl.onExtendBlock = { block, seconds, shiftAll in
            let extendedEnd = block.endTime.addingTimeInterval(seconds)
            store.update(block.withEndTime(extendedEnd).with(status: .pending))

            let today = store.todayBlocks().sorted { $0.startTime < $1.startTime }
            if shiftAll {
                for next in today where next.startTime >= block.endTime && next.id != block.id {
                    store.update(next.withStartTime(next.startTime.addingTimeInterval(seconds))
                                     .withEndTime(next.endTime.addingTimeInterval(seconds)))
                }
            } else if let next = today.first(where: { $0.startTime >= block.endTime && $0.id != block.id }) {
                store.update(next.withStartTime(next.startTime.addingTimeInterval(seconds))
                                 .withEndTime(next.endTime.addingTimeInterval(seconds)))
            }
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
                    if let changelog = updateChecker.checkWhatsNew() {
                        whatsNewVersion = updateChecker.currentVersion
                        whatsNewChangelog = changelog
                        showWhatsNew = true
                    }
                }
                .sheet(isPresented: $showWhatsNew) {
                    WhatsNewView(version: whatsNewVersion, changelog: whatsNewChangelog) {
                        showWhatsNew = false
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
            MenuBarIconView(store: store, iconStyle: iconStyle, showTime: showTimeInMenuBar)
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

        Button("检查更新...") {
            updateChecker.checkForUpdates(showNoUpdateAlert: true)
        }

        Divider()

        Toggle(isOn: $showTimeInMenuBar) {
            Text("菜单栏显示剩余时间")
        }

        Divider()

        Toggle(isOn: Binding(
            get: { LaunchManager.isLoginItemEnabled },
            set: { enabled in try? LaunchManager.setLoginItemEnabled(enabled) }
        )) {
            Text("开机自动启动")
        }

        Divider()

        Menu("提醒声音") {
            ForEach(OverlayWindowController.availableSounds, id: \.self) { name in
                Button {
                    UserDefaults.standard.set(name, forKey: "alertSoundName")
                } label: {
                    HStack {
                        Text(name)
                        if (UserDefaults.standard.string(forKey: "alertSoundName") ?? "Glass") == name {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }

        Divider()

        Button("退出 NotchBlock") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
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
