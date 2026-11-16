import AppKit
import SwiftUI
import XCTest
@testable import NotchBlock

final class UIThemeTests: XCTestCase {
    @MainActor
    private func makeIsolatedStore() -> (store: TimeBlockStore, cleanup: () -> Void) {
        let suiteName = "com.notchblock.tests.ui.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = TimeBlockStore(userDefaults: defaults, storageKey: "test.ui.blocks")
        return (store, { defaults.removePersistentDomain(forName: suiteName) })
    }

    // MARK: - Palette Verification

    func test_darkModePaletteIsBlackAndDeepPurple() {
        let dark = NSAppearance(named: .darkAqua)!
        var canvasRGBA: (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var accentFillRGBA: (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var accentOnFillRGBA: (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)

        dark.performAsCurrentDrawingAppearance {
            let canvas = BrandColors.canvasNS.usingColorSpace(.sRGB)!
            canvasRGBA = (canvas.redComponent, canvas.greenComponent, canvas.blueComponent, canvas.alphaComponent)

            let fill = BrandColors.accentFillNS.usingColorSpace(.sRGB)!
            accentFillRGBA = (fill.redComponent, fill.greenComponent, fill.blueComponent, fill.alphaComponent)

            let onFill = BrandColors.accentOnFillNS.usingColorSpace(.sRGB)!
            accentOnFillRGBA = (onFill.redComponent, onFill.greenComponent, onFill.blueComponent, onFill.alphaComponent)
        }

        // Obsidian black background
        XCTAssertLessThan(canvasRGBA.0, 0.08)
        XCTAssertLessThan(canvasRGBA.1, 0.08)
        XCTAssertLessThan(canvasRGBA.2, 0.10)

        // Deep purple primary accent: blue dominant over red, red dominant over green
        XCTAssertGreaterThan(accentFillRGBA.2, accentFillRGBA.0)
        XCTAssertGreaterThan(accentFillRGBA.0, accentFillRGBA.1)

        // Crisp light text on deep purple button
        XCTAssertGreaterThan(accentOnFillRGBA.0, 0.9)
        XCTAssertGreaterThan(accentOnFillRGBA.1, 0.9)
        XCTAssertGreaterThan(accentOnFillRGBA.2, 0.9)
    }

    func test_lightModePaletteIsWhiteAndPaleGreen() {
        let light = NSAppearance(named: .aqua)!
        var canvasRGBA: (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var accentFillRGBA: (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var accentOnFillRGBA: (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)

        light.performAsCurrentDrawingAppearance {
            let canvas = BrandColors.canvasNS.usingColorSpace(.sRGB)!
            canvasRGBA = (canvas.redComponent, canvas.greenComponent, canvas.blueComponent, canvas.alphaComponent)

            let fill = BrandColors.accentFillNS.usingColorSpace(.sRGB)!
            accentFillRGBA = (fill.redComponent, fill.greenComponent, fill.blueComponent, fill.alphaComponent)

            let onFill = BrandColors.accentOnFillNS.usingColorSpace(.sRGB)!
            accentOnFillRGBA = (onFill.redComponent, onFill.greenComponent, onFill.blueComponent, onFill.alphaComponent)
        }

        // Pure white background
        XCTAssertGreaterThan(canvasRGBA.0, 0.98)
        XCTAssertGreaterThan(canvasRGBA.1, 0.98)
        XCTAssertGreaterThan(canvasRGBA.2, 0.98)

        // Pale green accent: green dominant and high lightness
        XCTAssertGreaterThan(accentFillRGBA.1, accentFillRGBA.0)
        XCTAssertGreaterThan(accentFillRGBA.1, accentFillRGBA.2)
        XCTAssertGreaterThan(accentFillRGBA.1, 0.85)

        // Crisp dark forest ink on pale green fill
        XCTAssertLessThan(accentOnFillRGBA.1, 0.35)
        XCTAssertLessThan(accentOnFillRGBA.0, 0.20)
    }

    // MARK: - SwiftUI Views Layout in Light & Dark Mode

    @MainActor
    func test_allViewsLayoutInLightAndDarkAppearances() throws {
        let (store, cleanup) = makeIsolatedStore()
        defer { cleanup() }

        let emptySuite = "com.notchblock.tests.empty.\(UUID().uuidString)"
        let emptyDefaults = UserDefaults(suiteName: emptySuite)!
        let updaterSuite = "com.notchblock.tests.updater.ui.\(UUID().uuidString)"
        let updaterDefaults = UserDefaults(suiteName: updaterSuite)!
        defer {
            emptyDefaults.removePersistentDomain(forName: emptySuite)
            updaterDefaults.removePersistentDomain(forName: updaterSuite)
        }

        let emptyStore = TimeBlockStore(userDefaults: emptyDefaults, storageKey: "test.empty.blocks")
        let emptyScheduler = BlockScheduler(store: emptyStore)

        let now = Date()
        let active = TimeBlock(
            title: "深度架构设计",
            startTime: now.addingTimeInterval(-900),
            endTime: now.addingTimeInterval(2700),
            status: .pending,
            notes: "核心模块拆分"
        )
        let next = TimeBlock(
            title: "代码评审",
            startTime: now.addingTimeInterval(3300),
            endTime: now.addingTimeInterval(5100),
            status: .pending
        )
        let done = TimeBlock(
            title: "晨间规划",
            startTime: now.addingTimeInterval(-5400),
            endTime: now.addingTimeInterval(-3600),
            status: .completed
        )
        store.applyBatch { $0.append(contentsOf: [done, active, next]) }

        let scheduler = BlockScheduler(store: store)
        scheduler.checkBlocks(now: now)
        let stats = StatisticsStore(store: store)
        let notifier = WeChatNotifier()
        let updater = UpdateChecker(userDefaults: updaterDefaults)

        let views: [(String, AnyView, NSSize)] = [
            ("main-scheduler", AnyView(MainSchedulerView(store: store, scheduler: scheduler, stats: stats)), NSSize(width: 520, height: 560)),
            ("main-empty", AnyView(MainSchedulerView(store: emptyStore, scheduler: emptyScheduler, stats: stats)), NSSize(width: 520, height: 560)),
            ("timeline", AnyView(ScheduleTimelineView(blocks: store.todayBlocks(), activeBlockID: active.id, onTap: { _ in })), NSSize(width: 480, height: 480)),
            ("notch-panel", AnyView(NotchPanelView(store: store)), NSSize(width: 320, height: 300)),
            ("notch-panel-empty", AnyView(NotchPanelView(store: emptyStore)), NSSize(width: 320, height: 180)),
            ("menubar-popover", AnyView(MenuBarPopoverView(store: store, updateChecker: updater, onOpenMainWindow: {})), NSSize(width: 288, height: 360)),
            ("add-edit", AnyView(AddEditBlockView(store: store)), NSSize(width: 380, height: 340)),
            ("statistics", AnyView(StatisticsView(stats: stats)), NSSize(width: 460, height: 520)),
            ("overlay", AnyView(OverlayView(block: active, subsequentTaskCount: 1, onCompleted: {}, onAdjust: {}, onExtend: { _, _ in })), NSSize(width: 640, height: 520)),
            ("onboarding", AnyView(OnboardingView(onComplete: {})), NSSize(width: 460, height: 440)),
            ("settings", AnyView(SettingsView(weChatNotifier: notifier, updateChecker: updater)), NSSize(width: 460, height: 420)),
            ("wechat-settings", AnyView(WeChatSettingsView(notifier: notifier)), NSSize(width: 440, height: 360)),
            ("whatsnew", AnyView(WhatsNewView(version: "0.6.7", changelog: "### Fixed\n- Minimalist frosted glass UI", onDismiss: {})), NSSize(width: 480, height: 400)),
        ]

        for (modeName, appearanceName) in [("light", NSAppearance.Name.aqua), ("dark", NSAppearance.Name.darkAqua)] {
            let appearance = try XCTUnwrap(NSAppearance(named: appearanceName))
            for (name, view, size) in views {
                let hosting = NSHostingView(rootView: view)
                hosting.appearance = appearance
                hosting.frame = NSRect(origin: .zero, size: size)
                hosting.layoutSubtreeIfNeeded()

                let fitting = hosting.fittingSize
                XCTAssertGreaterThan(fitting.width, 0, "\(name) (\(modeName)) fitting width should be > 0")
                XCTAssertGreaterThan(fitting.height, 0, "\(name) (\(modeName)) fitting height should be > 0")
            }
        }
    }

    // MARK: - Window Controllers & Real-App End-to-End Flow

    @MainActor
    func test_endToEndSchedulerBreakOverlayAndControllers() {
        let (store, cleanup) = makeIsolatedStore()
        defer { cleanup() }

        let updaterSuite = "com.notchblock.tests.e2e.\(UUID().uuidString)"
        let updaterDefaults = UserDefaults(suiteName: updaterSuite)!
        defer { updaterDefaults.removePersistentDomain(forName: updaterSuite) }

        let breakScheduler = BreakScheduler(store: store)
        let scheduler = BlockScheduler(store: store)
        let stats = StatisticsStore(store: store)
        let updater = UpdateChecker(userDefaults: updaterDefaults)

        store.onDidChange = {
            breakScheduler.regenerateBreaks()
        }

        let now = Date()
        let first = TimeBlock(title: "任务一", startTime: now.addingTimeInterval(60), endTime: now.addingTimeInterval(1860))
        let second = TimeBlock(title: "任务二", startTime: now.addingTimeInterval(2460), endTime: now.addingTimeInterval(4260))
        store.add(first)
        store.add(second)

        // BreakScheduler creates a 5-minute break between the two future blocks
        XCTAssertEqual(store.blocks.filter(\.isBreak).count, 1)

        // Scheduler identifies active block during its window and triggers onBlockEnded at endTime
        var ended: [TimeBlock] = []
        scheduler.onBlockEnded = { ended.append($0) }
        scheduler.checkBlocks(now: first.startTime.addingTimeInterval(10))
        XCTAssertEqual(scheduler.activeBlockID, first.id)

        scheduler.checkBlocks(now: first.endTime.addingTimeInterval(1))
        XCTAssertEqual(ended.map(\.id), [first.id])

        // Extending first block by 10m shifts second block when shiftAllSubsequent = true
        let originalSecondStart = second.startTime
        store.extendBlock(id: first.id, by: 600, shiftAllSubsequent: true, now: first.endTime)
        let updatedSecond = store.blocks.first { $0.id == second.id }
        XCTAssertEqual(updatedSecond?.startTime.timeIntervalSince(originalSecondStart) ?? 0, 600, accuracy: 0.5)

        // Complete first block and confirm statistics reflect completion
        store.update(first.with(status: .completed))
        XCTAssertEqual(stats.todayCompleted, 1)
        XCTAssertEqual(stats.todayTotal, 2)

        // Controllers exercise cleanly on host Mac
        let panelCtrl = NotchPanelController(store: store)
        let tracker = NotchTracker()
        panelCtrl.bind(to: tracker)
        panelCtrl.show()
        panelCtrl.hide()
        tracker.teardown()

        let overlayCtrl = OverlayWindowController()
        overlayCtrl.show(for: first)
        XCTAssertTrue(overlayCtrl.isVisible)
        overlayCtrl.dismiss()
        XCTAssertFalse(overlayCtrl.isVisible)

        let mainWC = MainWindowController(store: store, scheduler: scheduler, statsStore: stats, updateChecker: updater)
        mainWC.show()
        NSApp.windows.first { $0.identifier?.rawValue == "main" }?.close()
    }
}
