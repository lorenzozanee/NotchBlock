import AppKit
import SwiftUI

@main
@MainActor
struct NotchBlockApp: App {
    @State private var store: TimeBlockStore
    @State private var scheduler: BlockScheduler
    @State private var weChatNotifier: WeChatNotifier
    @State private var statsStore: StatisticsStore
    @State private var updateChecker: UpdateChecker

    private let notchTracker = NotchTracker()
    private let panelController: NotchPanelController
    private let overlayController: OverlayWindowController
    private let breakScheduler: BreakScheduler
    private let onboardingController = OnboardingWindowController()
    private let mainWindowController: MainWindowController

    @AppStorage("menuBarIconStyle") private var iconStyle = MenuBarIconStyle.timer.rawValue
    @AppStorage("showTimeInMenuBar") private var showTimeInMenuBar = true

    init() {
        let store = TimeBlockStore()
        let scheduler = BlockScheduler(store: store)
        let weChatNotifier = WeChatNotifier()
        let statsStore = StatisticsStore(store: store)
        let updateChecker = UpdateChecker()

        let panelCtrl = NotchPanelController(store: store)
        let overlayCtrl = OverlayWindowController()
        let breaks = BreakScheduler(store: store)
        let mainWC = MainWindowController(
            store: store,
            scheduler: scheduler,
            statsStore: statsStore,
            updateChecker: updateChecker
        )

        _store = State(initialValue: store)
        _scheduler = State(initialValue: scheduler)
        _weChatNotifier = State(initialValue: weChatNotifier)
        _statsStore = State(initialValue: statsStore)
        _updateChecker = State(initialValue: updateChecker)

        panelController = panelCtrl
        overlayController = overlayCtrl
        breakScheduler = breaks
        mainWindowController = mainWC

        panelCtrl.bind(to: notchTracker)
        mainWC.onWindowWillShow = { [weak panelCtrl] in
            panelCtrl?.hide()
        }
        store.onDidChange = { [weak breaks, weak overlayCtrl, weak statsStore] in
            breaks?.regenerateBreaks()
            if let statsStore {
                overlayCtrl?.scheduleDailySummary(stats: statsStore)
            }
        }

        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if !isRunningTests {
            notchTracker.start()
            scheduler.start()
            overlayCtrl.requestNotificationPermission()
            overlayCtrl.scheduleDailySummary(stats: statsStore)
            updateChecker.startAutoCheck()

            if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
                onboardingController.show(store: store)
            }
        }

        panelCtrl.onOpenMainWindow = { [weak panelCtrl, weak mainWC] in
            panelCtrl?.hide()
            mainWC?.show()
        }

        overlayCtrl.onMarkCompleted = { block in
            store.update(block.with(status: .completed))
        }

        overlayCtrl.onMarkMissed = { [weak weChatNotifier] block in
            store.update(block.with(status: .missed))
            weChatNotifier?.sendMissedNotification(for: block)
        }

        overlayCtrl.subsequentTaskCountProvider = { block in
            store.todayBlocks()
                .filter { !$0.isBreak && $0.status == .pending && $0.id != block.id && $0.startTime >= block.endTime }
                .count
        }

        overlayCtrl.onAdjustSchedule = { [weak mainWC] in
            mainWC?.show()
        }

        overlayCtrl.onExtendBlock = { block, seconds, shiftAll in
            store.extendBlock(id: block.id, by: seconds, shiftAllSubsequent: shiftAll)
        }

        scheduler.onBlockEnded = { [weak overlayCtrl, weak weChatNotifier] block in
            overlayCtrl?.show(for: block)
            weChatNotifier?.sendBlockEndedNotification(for: block)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView(
                store: store,
                updateChecker: updateChecker,
                onOpenMainWindow: { mainWindowController.show() }
            )
        } label: {
            MenuBarIconView(
                store: store,
                scheduler: scheduler,
                iconStyle: iconStyle,
                showTime: showTimeInMenuBar
            )
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(
                weChatNotifier: weChatNotifier,
                updateChecker: updateChecker
            )
        }
    }
}
