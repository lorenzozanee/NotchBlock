import XCTest
@testable import NotchBlock

final class StatisticsTests: XCTestCase {
    private static let fixedCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    private static let fixedNow: Date = fixedCalendar.date(
        from: DateComponents(year: 2026, month: 6, day: 10, hour: 15, minute: 0)
    )!

    @MainActor
    private func makeFixture() -> (store: TimeBlockStore, stats: StatisticsStore, cleanup: () -> Void) {
        let suiteName = "com.notchblock.tests.stats.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = TimeBlockStore(userDefaults: defaults, storageKey: "test.stats.blocks")
        let now = Self.fixedNow
        let stats = StatisticsStore(store: store, calendar: Self.fixedCalendar, now: { now })
        return (store, stats, { defaults.removePersistentDomain(forName: suiteName) })
    }

    private func block(daysOffset: Int, hour: Int, duration: TimeInterval, status: BlockStatus, isBreak: Bool = false) -> TimeBlock {
        let day = Self.fixedCalendar.date(byAdding: .day, value: daysOffset, to: Self.fixedCalendar.startOfDay(for: Self.fixedNow))!
        let start = Self.fixedCalendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
        return TimeBlock(
            title: isBreak ? "休息" : "Task-\(daysOffset)-\(hour)",
            startTime: start,
            endTime: start.addingTimeInterval(duration),
            status: status,
            isBreak: isBreak
        )
    }

    @MainActor
    func test_todayMetricsExcludeBreaks() {
        let (store, stats, cleanup) = makeFixture()
        defer { cleanup() }

        store.applyBatch { blocks in
            blocks.append(contentsOf: [
                block(daysOffset: 0, hour: 9, duration: 3600, status: .completed),
                block(daysOffset: 0, hour: 10, duration: 1800, status: .completed),
                block(daysOffset: 0, hour: 11, duration: 2400, status: .missed),
                block(daysOffset: 0, hour: 14, duration: 1200, status: .pending),
                block(daysOffset: 0, hour: 10, duration: 300, status: .completed, isBreak: true),
            ])
        }

        XCTAssertEqual(stats.todayTotal, 4)
        XCTAssertEqual(stats.todayCompleted, 2)
        XCTAssertEqual(stats.todayMissed, 1)
        XCTAssertEqual(stats.todayRemaining, 1)
        XCTAssertEqual(stats.todayCompletionRate, 0.5, accuracy: 0.001)
        XCTAssertEqual(stats.todayFocusTime, 5400, accuracy: 0.001)
    }

    @MainActor
    func test_emptyStoreProducesZeroMetrics() {
        let (_, stats, cleanup) = makeFixture()
        defer { cleanup() }

        XCTAssertEqual(stats.todayTotal, 0)
        XCTAssertEqual(stats.todayCompletionRate, 0)
        XCTAssertEqual(stats.todayFocusTime, 0)
        XCTAssertEqual(stats.currentStreak, 0)
        XCTAssertNil(stats.bestHour)
    }

    @MainActor
    func test_streakCountsConsecutiveDaysAndToleratesUnfinishedToday() {
        let (store, stats, cleanup) = makeFixture()
        defer { cleanup() }

        store.applyBatch { blocks in
            blocks.append(contentsOf: [
                block(daysOffset: -1, hour: 9, duration: 1800, status: .completed),
                block(daysOffset: -2, hour: 9, duration: 1800, status: .completed),
                // daysOffset: -3 missing — breaks streak
                block(daysOffset: -4, hour: 9, duration: 1800, status: .completed),
            ])
        }

        XCTAssertEqual(stats.currentStreak, 2)

        store.add(block(daysOffset: 0, hour: 9, duration: 1800, status: .completed))
        XCTAssertEqual(stats.currentStreak, 3)
    }

    @MainActor
    func test_bestHourRequiresAtLeastThreeBlocks() {
        let (store, stats, cleanup) = makeFixture()
        defer { cleanup() }

        store.applyBatch { blocks in
            // Hour 9: 2/2 completed (below threshold of 3)
            blocks.append(block(daysOffset: 0, hour: 9, duration: 1800, status: .completed))
            blocks.append(block(daysOffset: -1, hour: 9, duration: 1800, status: .completed))
            // Hour 14: 3/3 completed (qualifies)
            blocks.append(block(daysOffset: 0, hour: 14, duration: 1800, status: .completed))
            blocks.append(block(daysOffset: -1, hour: 14, duration: 1800, status: .completed))
            blocks.append(block(daysOffset: -2, hour: 14, duration: 1800, status: .completed))
        }

        XCTAssertEqual(stats.bestHour?.hour, 14)
        XCTAssertEqual(stats.bestHour?.rate ?? 0, 1.0, accuracy: 0.001)
    }

    @MainActor
    func test_weekDailyCompletionAndFocusTime() {
        let (store, stats, cleanup) = makeFixture()
        defer { cleanup() }

        store.applyBatch { blocks in
            blocks.append(contentsOf: [
                block(daysOffset: 0, hour: 9, duration: 1800, status: .completed),
                block(daysOffset: -2, hour: 9, duration: 3600, status: .completed),
                block(daysOffset: -10, hour: 9, duration: 7200, status: .completed), // outside 7-day window
            ])
        }

        XCTAssertEqual(stats.weekDailyCompletion.count, 7)
        XCTAssertEqual(stats.weekTotalCompleted, 2)
        XCTAssertEqual(stats.weekTotalFocusTime, 5400, accuracy: 0.001)
        XCTAssertEqual(stats.weeklyTrend.count, 4)
    }
}
