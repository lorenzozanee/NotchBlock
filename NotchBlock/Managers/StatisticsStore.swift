import Foundation

/// Computed analytics over TimeBlockStore data. No additional persistence — pure read-only queries.
final class StatisticsStore: ObservableObject {
    private let store: TimeBlockStore
    private let calendar = Calendar.current

    init(store: TimeBlockStore) { self.store = store }

    private var userBlocks: [TimeBlock] { store.blocks.filter { !$0.isBreak } }
    private var todayUserBlocks: [TimeBlock] { store.todayBlocks().filter { !$0.isBreak } }

    var todayTotal: Int { todayUserBlocks.count }
    var todayCompleted: Int { todayUserBlocks.filter { $0.status == .completed }.count }
    var todayCompletionRate: Double {
        guard todayTotal > 0 else { return 0 }
        return Double(todayCompleted) / Double(todayTotal)
    }
    var todayFocusTime: TimeInterval {
        todayUserBlocks.filter { $0.status == .completed }.map(\.duration).reduce(0, +)
    }
    var todayMissed: Int { todayUserBlocks.filter { $0.status == .missed }.count }
    var todayRemaining: Int { todayUserBlocks.filter { $0.status == .pending }.count }

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

    // MARK: - Heatmap

    var hourlyProductivity: [(hour: Int, rate: Double, count: Int)] {
        var hourBuckets: [Int: (completed: Int, total: Int)] = [:]
        for block in userBlocks {
            let hour = Calendar.current.component(.hour, from: block.startTime)
            var b = hourBuckets[hour] ?? (0, 0)
            b.total += 1
            if block.status == .completed { b.completed += 1 }
            hourBuckets[hour] = b
        }
        return (0..<24).map { h in
            let b = hourBuckets[h] ?? (0, 0)
            return (h, b.total > 0 ? Double(b.completed) / Double(b.total) : 0, b.total)
        }
    }

    var bestHour: (hour: Int, rate: Double)? {
        hourlyProductivity.filter { $0.count >= 3 }.max { $0.rate < $1.rate }.map { ($0.hour, $0.rate) }
    }

    // MARK: - Monthly Trend

    var weeklyTrend: [(label: String, rate: Double, completed: Int, total: Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<4).map { w in
            guard let ws = cal.date(byAdding: .weekOfYear, value: -w, to: today),
                  let we = cal.date(byAdding: .day, value: 6, to: ws)
            else { return ("?", 0, 0, 0) }
            let blocks = store.blocks.filter { $0.startTime >= ws && $0.startTime <= we }
            let c = blocks.filter { $0.status == .completed }.count
            let t = blocks.count
            return (ws.weekdayLabel + "周", t > 0 ? Double(c) / Double(t) : 0, c, t)
        }.reversed()
    }

    // MARK: - Helpers

    private func weekDayLabel(for date: Date) -> String { date.weekdayLabel }
}
