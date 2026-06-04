import Foundation

/// Auto-generates 5-min break blocks between consecutive user-created time blocks.
final class BreakScheduler {
    private let store: TimeBlockStore
    private let breakDuration: TimeInterval = 300

    init(store: TimeBlockStore) { self.store = store }

    func regenerateBreaks() {
        let all = store.blocks
        let user = all.filter { !$0.isBreak }.sorted { $0.startTime < $1.startTime }

        for b in all where b.isBreak { store.delete(b) }

        for i in 0..<(user.count - 1) {
            let gap = user[i + 1].startTime.timeIntervalSince(user[i].endTime)
            if gap >= breakDuration {
                store.add(TimeBlock(
                    title: "休息", startTime: user[i].endTime,
                    endTime: user[i].endTime.addingTimeInterval(breakDuration),
                    isBreak: true
                ))
            }
        }
    }
}
