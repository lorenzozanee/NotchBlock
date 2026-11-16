import Foundation

/// Idempotently reconciles 5-minute break blocks between future consecutive user blocks.
@MainActor
final class BreakScheduler {
    private let store: TimeBlockStore
    private let breakDuration: TimeInterval
    private let calendar: Calendar
    private var isRegenerating = false

    init(store: TimeBlockStore, breakDuration: TimeInterval = 300, calendar: Calendar = .current) {
        self.store = store
        self.breakDuration = breakDuration
        self.calendar = calendar
    }

    func regenerateBreaks(now: Date = Date()) {
        guard !isRegenerating else { return }
        isRegenerating = true
        defer { isRegenerating = false }

        let userBlocks = store.blocks
            .filter { !$0.isBreak }
            .sorted { $0.startTime < $1.startTime }

        // Compute desired future break windows between consecutive same-day pending user blocks.
        var desiredWindows: [(start: Date, end: Date)] = []
        if userBlocks.count >= 2 {
            for index in 0..<(userBlocks.count - 1) {
                let current = userBlocks[index]
                let next = userBlocks[index + 1]
                guard current.status == .pending,
                      next.status == .pending,
                      current.endTime > now,
                      calendar.isDate(current.endTime, inSameDayAs: next.startTime)
                else { continue }

                let gap = next.startTime.timeIntervalSince(current.endTime)
                if gap >= breakDuration {
                    desiredWindows.append((
                        start: current.endTime,
                        end: current.endTime.addingTimeInterval(breakDuration)
                    ))
                }
            }
        }

        store.applyBatch({ blocks in
            let existingBreaks = blocks.filter(\.isBreak)

            // Keep past, completed, missed, or currently active breaks untouched.
            var preservedBreaks = existingBreaks.filter { brk in
                brk.status != .pending || brk.startTime <= now
            }

            let futurePendingBreaks = existingBreaks.filter { brk in
                brk.status == .pending && brk.startTime > now
            }

            for window in desiredWindows {
                if let existing = futurePendingBreaks.first(where: {
                    abs($0.startTime.timeIntervalSince(window.start)) < 1 &&
                    abs($0.endTime.timeIntervalSince(window.end)) < 1
                }) {
                    preservedBreaks.append(existing)
                } else {
                    preservedBreaks.append(TimeBlock(
                        title: "休息",
                        startTime: window.start,
                        endTime: window.end,
                        isBreak: true
                    ))
                }
            }

            let nonBreaks = blocks.filter { !$0.isBreak }
            blocks = nonBreaks + preservedBreaks
        }, notifyChange: false)
    }
}
