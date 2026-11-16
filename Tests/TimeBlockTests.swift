import XCTest
@testable import NotchBlock

final class TimeBlockTests: XCTestCase {
    @MainActor
    private func makeTestStore() -> (store: TimeBlockStore, cleanup: () -> Void) {
        let suiteName = "com.notchblock.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = TimeBlockStore(userDefaults: defaults, storageKey: "test.blocks")
        return (store, { defaults.removePersistentDomain(forName: suiteName) })
    }

    // MARK: - TimeBlock Model

    func test_overlapDetection() {
        let now = Date()
        let a = TimeBlock(title: "A", startTime: now, endTime: now.addingTimeInterval(3600))
        let overlapping = TimeBlock(title: "B", startTime: now.addingTimeInterval(1800), endTime: now.addingTimeInterval(5400))
        let adjacent = TimeBlock(title: "C", startTime: now.addingTimeInterval(3600), endTime: now.addingTimeInterval(7200))

        XCTAssertTrue(a.overlaps(with: overlapping))
        XCTAssertFalse(a.overlaps(with: adjacent))
    }

    func test_containsIsHalfOpen() {
        let start = Date()
        let end = start.addingTimeInterval(1800)
        let block = TimeBlock(title: "Focus", startTime: start, endTime: end)

        XCTAssertTrue(block.contains(start))
        XCTAssertTrue(block.contains(start.addingTimeInterval(900)))
        XCTAssertFalse(block.contains(end))
    }

    func test_validAndInvalidTimeRanges() {
        let now = Date()
        XCTAssertTrue(TimeBlock(title: "Valid", startTime: now, endTime: now.addingTimeInterval(60)).hasValidTimeRange)
        XCTAssertFalse(TimeBlock(title: "Zero", startTime: now, endTime: now).hasValidTimeRange)
        XCTAssertFalse(TimeBlock(title: "Inverted", startTime: now, endTime: now.addingTimeInterval(-60)).hasValidTimeRange)
    }

    func test_codableBackwardCompatibility() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let legacyJSON = """
        [{"id":"A1B2C3D4-E5F6-7890-ABCD-EF1234567890","title":"Task","startTime":"2026-06-04T09:00:00Z","endTime":"2026-06-04T10:00:00Z","status":"pending"}]
        """
        let legacyBlocks = try decoder.decode([TimeBlock].self, from: Data(legacyJSON.utf8))
        XCTAssertEqual(legacyBlocks.count, 1)
        XCTAssertEqual(legacyBlocks[0].notes, "")
        XCTAssertFalse(legacyBlocks[0].isBreak)

        let v3JSON = """
        [{"id":"A1B2C3D4-E5F6-7890-ABCD-EF1234567890","title":"Task","startTime":"2026-06-04T09:00:00Z","endTime":"2026-06-04T10:00:00Z","status":"pending","notes":"focus work"}]
        """
        let v3Blocks = try decoder.decode([TimeBlock].self, from: Data(v3JSON.utf8))
        XCTAssertEqual(v3Blocks[0].notes, "focus work")
        XCTAssertFalse(v3Blocks[0].isBreak)
    }

    func test_withMutationsPreserveFields() {
        let now = Date()
        let original = TimeBlock(title: "A", startTime: now, endTime: now.addingTimeInterval(1800), notes: "important", isBreak: true)
        let updated = original.with(status: .completed)
        XCTAssertEqual(updated.id, original.id)
        XCTAssertEqual(updated.notes, "important")
        XCTAssertTrue(updated.isBreak)
        XCTAssertEqual(updated.status, .completed)
    }

    // MARK: - TimeBlockStore

    @MainActor
    func test_activeBlockPrioritizesUserBlockOverBreak() {
        let (store, cleanup) = makeTestStore()
        defer { cleanup() }

        let now = Date()
        let brk = TimeBlock(title: "休息", startTime: now.addingTimeInterval(-60), endTime: now.addingTimeInterval(240), isBreak: true)
        let work = TimeBlock(title: "深度工作", startTime: now.addingTimeInterval(-30), endTime: now.addingTimeInterval(1800), isBreak: false)
        store.add(brk)
        store.add(work)

        XCTAssertEqual(store.activeBlock(at: now)?.id, work.id)
    }

    @MainActor
    func test_upcomingBlocksUsesProvidedDate() {
        let (store, cleanup) = makeTestStore()
        defer { cleanup() }

        let calendar = Calendar.current
        let futureDay = calendar.date(byAdding: .day, value: 3, to: calendar.startOfDay(for: Date()))!
        let queryTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: futureDay)!
        let pastOnDay = TimeBlock(title: "Past", startTime: queryTime.addingTimeInterval(-3600), endTime: queryTime)
        let next1 = TimeBlock(title: "Next 1", startTime: queryTime.addingTimeInterval(600), endTime: queryTime.addingTimeInterval(2400))
        let next2 = TimeBlock(title: "Next 2", startTime: queryTime.addingTimeInterval(3600), endTime: queryTime.addingTimeInterval(5400))

        store.applyBatch { blocks in
            blocks.append(contentsOf: [pastOnDay, next2, next1])
        }

        let upcoming = store.upcomingBlocks(after: queryTime, limit: 2)
        XCTAssertEqual(upcoming.map(\.title), ["Next 1", "Next 2"])
    }

    @MainActor
    func test_extendBlockCascadeWithoutShiftAll() {
        let (store, cleanup) = makeTestStore()
        defer { cleanup() }

        let cal = Calendar.current
        let base = cal.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        let a = TimeBlock(title: "A", startTime: base, endTime: base.addingTimeInterval(3600))
        let b = TimeBlock(title: "B", startTime: base.addingTimeInterval(3600), endTime: base.addingTimeInterval(5400))
        let c = TimeBlock(title: "C", startTime: base.addingTimeInterval(5400), endTime: base.addingTimeInterval(7200))
        let distant = TimeBlock(title: "D", startTime: base.addingTimeInterval(14400), endTime: base.addingTimeInterval(18000))

        store.applyBatch { $0.append(contentsOf: [a, b, c, distant]) }
        store.extendBlock(id: a.id, by: 300, shiftAllSubsequent: false, now: a.endTime)

        let updatedA = store.blocks.first { $0.id == a.id }!
        let updatedB = store.blocks.first { $0.id == b.id }!
        let updatedC = store.blocks.first { $0.id == c.id }!
        let updatedD = store.blocks.first { $0.id == distant.id }!

        XCTAssertEqual(updatedA.endTime, a.endTime.addingTimeInterval(300))
        XCTAssertEqual(updatedB.startTime, updatedA.endTime)
        XCTAssertEqual(updatedC.startTime, updatedB.endTime)
        XCTAssertEqual(updatedD.startTime, distant.startTime)
    }

    @MainActor
    func test_extendBlockLateInGracePeriodStillLandsInFuture() {
        let (store, cleanup) = makeTestStore()
        defer { cleanup() }

        let base = Date()
        let a = TimeBlock(title: "A", startTime: base.addingTimeInterval(-3600), endTime: base)
        store.add(a)

        let lateNow = base.addingTimeInterval(240)
        store.extendBlock(id: a.id, by: 60, shiftAllSubsequent: false, now: lateNow)

        let updated = store.blocks.first { $0.id == a.id }!
        XCTAssertGreaterThan(updated.endTime, lateNow)
        XCTAssertEqual(updated.endTime.timeIntervalSince(lateNow), 60, accuracy: 0.001)
    }

    // MARK: - BlockScheduler

    @MainActor
    func test_blockSchedulerTriggersOnceAndRearmsAfterExtend() {
        let (store, cleanup) = makeTestStore()
        defer { cleanup() }

        let now = Date()
        let block = TimeBlock(title: "Task", startTime: now.addingTimeInterval(-1800), endTime: now.addingTimeInterval(-10))
        store.add(block)

        let scheduler = BlockScheduler(store: store, staleThreshold: 300)
        var endedIDs: [UUID] = []
        scheduler.onBlockEnded = { endedIDs.append($0.id) }

        scheduler.checkBlocks(now: now)
        scheduler.checkBlocks(now: now.addingTimeInterval(1))
        XCTAssertEqual(endedIDs, [block.id])

        // Extending into the future clears trigger cache and fires again when the new end arrives
        store.update(block.withEndTime(now.addingTimeInterval(120)))
        scheduler.checkBlocks(now: now.addingTimeInterval(2))
        scheduler.checkBlocks(now: now.addingTimeInterval(121))
        XCTAssertEqual(endedIDs, [block.id, block.id])
    }

    @MainActor
    func test_blockSchedulerMarksStaleBlocksMissedAndCompletesBreaks() {
        let (store, cleanup) = makeTestStore()
        defer { cleanup() }

        let now = Date()
        let staleUser = TimeBlock(title: "Stale", startTime: now.addingTimeInterval(-4000), endTime: now.addingTimeInterval(-600))
        let endedBreak = TimeBlock(title: "休息", startTime: now.addingTimeInterval(-400), endTime: now.addingTimeInterval(-10), isBreak: true)
        store.applyBatch { $0.append(contentsOf: [staleUser, endedBreak]) }

        let scheduler = BlockScheduler(store: store, staleThreshold: 300)
        var endedIDs: [UUID] = []
        scheduler.onBlockEnded = { endedIDs.append($0.id) }

        scheduler.checkBlocks(now: now)

        XCTAssertTrue(endedIDs.isEmpty)
        XCTAssertEqual(store.blocks.first { $0.id == staleUser.id }?.status, .missed)
        XCTAssertEqual(store.blocks.first { $0.id == endedBreak.id }?.status, .completed)
    }

    // MARK: - BreakScheduler

    @MainActor
    func test_breakSchedulerCreatesAndPrunesBreaksIdempotently() {
        let (store, cleanup) = makeTestStore()
        defer { cleanup() }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 10, minute: 0))!

        let b1 = TimeBlock(title: "B1", startTime: now.addingTimeInterval(600), endTime: now.addingTimeInterval(2400))
        let b2 = TimeBlock(title: "B2", startTime: now.addingTimeInterval(3000), endTime: now.addingTimeInterval(4800)) // 10m gap
        let b3 = TimeBlock(title: "B3", startTime: now.addingTimeInterval(4920), endTime: now.addingTimeInterval(6720)) // 2m gap (<5m)
        store.applyBatch { $0.append(contentsOf: [b1, b2, b3]) }

        let breakScheduler = BreakScheduler(store: store, calendar: cal)
        breakScheduler.regenerateBreaks(now: now)
        let firstPassBreaks = store.blocks.filter(\.isBreak)
        XCTAssertEqual(firstPassBreaks.count, 1)
        XCTAssertEqual(firstPassBreaks[0].startTime, b1.endTime)
        XCTAssertEqual(firstPassBreaks[0].duration, 300, accuracy: 0.001)

        // Idempotent second run preserves exact same break ID
        breakScheduler.regenerateBreaks(now: now)
        let secondPassBreaks = store.blocks.filter(\.isBreak)
        XCTAssertEqual(secondPassBreaks.map(\.id), firstPassBreaks.map(\.id))

        // Deleting b2 leaves b1 -> b3 (42m gap), so the break after b1 stays with same ID
        store.delete(b2)
        breakScheduler.regenerateBreaks(now: now)
        XCTAssertEqual(store.blocks.filter(\.isBreak).map(\.id), firstPassBreaks.map(\.id))

        // Deleting b3 leaves b1 alone, pruning the orphaned future break
        store.delete(b3)
        breakScheduler.regenerateBreaks(now: now)
        XCTAssertTrue(store.blocks.filter(\.isBreak).isEmpty)
    }

    @MainActor
    func test_breakSchedulerSkipsCrossDayGap() {
        let (store, cleanup) = makeTestStore()
        defer { cleanup() }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 15, minute: 0))!
        let todayLast = TimeBlock(
            title: "Today Last",
            startTime: cal.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 17, minute: 0))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 18, minute: 0))!
        )
        let tomorrowFirst = TimeBlock(
            title: "Tomorrow First",
            startTime: cal.date(from: DateComponents(year: 2026, month: 6, day: 11, hour: 9, minute: 0))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 6, day: 11, hour: 10, minute: 0))!
        )
        store.applyBatch { $0.append(contentsOf: [todayLast, tomorrowFirst]) }

        let breakScheduler = BreakScheduler(store: store, calendar: cal)
        breakScheduler.regenerateBreaks(now: now)
        XCTAssertTrue(store.blocks.filter(\.isBreak).isEmpty)
    }
}
