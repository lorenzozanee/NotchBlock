import Foundation

/// Computed analytics over TimeBlockStore data. No additional persistence — pure read-only queries.
final class StatisticsStore: ObservableObject {
    private let store: TimeBlockStore
    private let calendar = Calendar.current

    init(store: TimeBlockStore) {
        self.store = store
    }

    // MARK: - Today

    var todayTotal: Int { store.todayBlocks().count }
    var todayCompleted: Int { store.todayBlocks().filter { $0.status == .completed }.count }
    var todayCompletionRate: Double {
        guard todayTotal > 0 else { return 0 }
        return Double(todayCompleted) / Double(todayTotal)
    }
    var todayFocusTime: TimeInterval {
        store.todayBlocks().filter { $0.status == .completed }.map(\.duration).reduce(0, +)
    }
    var todayMissed: Int { store.todayBlocks().filter { $0.status == .missed }.count }
    var todayRemaining: Int { store.todayBlocks().filter { $0.status == .pending }.count }

    // MARK: - This Week

    var weekDailyCompletion: [(label: String, count: Int)] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).map { daysAgo in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return ("?", 0) }
            let completed = store.blocks(for: date).filter { $0.status == .completed }.count
            let label = weekDayLabel(for: date)
            return (label, completed)
        }.reversed()
    }

    var weekTotalCompleted: Int { weekDailyCompletion.map(\.count).reduce(0, +) }
    var weekTotalFocusTime: TimeInterval {
        let today = calendar.startOfDay(for: Date())
        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: today) else { return 0 }
        return store.blocks
            .filter { $0.status == .completed && $0.startTime >= weekStart }
            .map(\.duration).reduce(0, +)
    }

    // MARK: - Streak

    var currentStreak: Int {
        var streak = 0
        let today = calendar.startOfDay(for: Date())
        for daysBack in 0...365 {
            guard let date = calendar.date(byAdding: .day, value: -daysBack, to: today) else { break }
            if store.blocks(for: date).contains(where: { $0.status == .completed }) {
                streak += 1
            } else if daysBack > 0 { break }
        }
        return streak
    }

    // MARK: - Helpers

    private func weekDayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}
