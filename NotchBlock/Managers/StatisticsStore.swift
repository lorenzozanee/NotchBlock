import Foundation
import Observation

/// Computed analytics over TimeBlockStore data (excludes auto-generated breaks).
@Observable
@MainActor
final class StatisticsStore {
    struct DailyCompletion: Identifiable, Equatable {
        let id: Date
        let label: String
        let count: Int
    }

    struct HourlyProductivity: Identifiable, Equatable {
        var id: Int { hour }
        let hour: Int
        let rate: Double
        let count: Int
    }

    struct WeeklyTrendPoint: Identifiable, Equatable {
        let id: Int
        let label: String
        let rate: Double
        let completed: Int
        let total: Int
    }

    @ObservationIgnored private let store: TimeBlockStore
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let nowProvider: @Sendable () -> Date

    init(
        store: TimeBlockStore,
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.calendar = calendar
        self.nowProvider = now
    }

    private var userBlocks: [TimeBlock] { store.blocks.filter { !$0.isBreak } }

    private var todayUserBlocks: [TimeBlock] {
        let now = nowProvider()
        return userBlocks.filter { calendar.isDate($0.startTime, inSameDayAs: now) }
    }

    // MARK: - Today

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

    var weekDailyCompletion: [DailyCompletion] {
        let today = calendar.startOfDay(for: nowProvider())
        let completedByDay = completedCountsByDay()
        return (0..<7).reversed().compactMap { daysAgo in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return nil }
            let completed = completedByDay[date] ?? 0
            return DailyCompletion(id: date, label: date.weekdayLabel, count: completed)
        }
    }

    var weekTotalCompleted: Int {
        weekDailyCompletion.map(\.count).reduce(0, +)
    }

    var weekTotalFocusTime: TimeInterval {
        let today = calendar.startOfDay(for: nowProvider())
        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: today),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)
        else { return 0 }

        return userBlocks
            .filter { $0.status == .completed && $0.startTime >= weekStart && $0.startTime < tomorrow }
            .map(\.duration)
            .reduce(0, +)
    }

    // MARK: - Streak

    var currentStreak: Int {
        var streak = 0
        let today = calendar.startOfDay(for: nowProvider())
        let completedDays = Set(
            userBlocks
                .filter { $0.status == .completed }
                .map { calendar.startOfDay(for: $0.startTime) }
        )

        for daysBack in 0...365 {
            guard let date = calendar.date(byAdding: .day, value: -daysBack, to: today) else { break }
            if completedDays.contains(date) {
                streak += 1
            } else if daysBack > 0 {
                break
            }
        }
        return streak
    }

    // MARK: - Heatmap

    var hourlyProductivity: [HourlyProductivity] {
        var hourBuckets: [Int: (completed: Int, total: Int)] = [:]
        for block in userBlocks {
            let hour = calendar.component(.hour, from: block.startTime)
            var b = hourBuckets[hour] ?? (0, 0)
            b.total += 1
            if block.status == .completed { b.completed += 1 }
            hourBuckets[hour] = b
        }
        return (0..<24).map { h in
            let b = hourBuckets[h] ?? (0, 0)
            let rate = b.total > 0 ? Double(b.completed) / Double(b.total) : 0
            return HourlyProductivity(hour: h, rate: rate, count: b.total)
        }
    }

    var bestHour: (hour: Int, rate: Double)? {
        hourlyProductivity
            .filter { $0.count >= 3 }
            .max { $0.rate < $1.rate }
            .map { ($0.hour, $0.rate) }
    }

    // MARK: - Monthly Trend

    var weeklyTrend: [WeeklyTrendPoint] {
        let today = nowProvider()
        guard let currentWeek = calendar.dateInterval(of: .weekOfYear, for: today) else { return [] }
        let labels = ["本周", "上周", "2周前", "3周前"]

        return (0..<4).reversed().compactMap { weeksAgo in
            guard let start = calendar.date(byAdding: .day, value: -7 * weeksAgo, to: currentWeek.start),
                  let end = calendar.date(byAdding: .day, value: 7, to: start)
            else { return nil }

            let blocks = userBlocks.filter {
                $0.startTime >= start && $0.startTime < end
            }
            let completed = blocks.filter { $0.status == .completed }.count
            let total = blocks.count
            let rate = total > 0 ? Double(completed) / Double(total) : 0
            return WeeklyTrendPoint(
                id: weeksAgo,
                label: labels[weeksAgo],
                rate: rate,
                completed: completed,
                total: total
            )
        }
    }

    private func completedCountsByDay() -> [Date: Int] {
        var counts: [Date: Int] = [:]
        for block in userBlocks where block.status == .completed {
            let day = calendar.startOfDay(for: block.startTime)
            counts[day, default: 0] += 1
        }
        return counts
    }
}
