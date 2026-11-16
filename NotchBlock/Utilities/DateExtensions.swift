import Foundation

extension Date {
    var timeString: String {
        formatted(
            Date.VerbatimFormatStyle(
                format: "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
                locale: Locale(identifier: "en_US_POSIX"),
                timeZone: .current,
                calendar: .current
            )
        )
    }

    var weekdayLabel: String {
        formatted(Date.FormatStyle().weekday(.abbreviated).locale(Locale(identifier: "zh_CN")))
    }

    var chineseDateString: String {
        formatted(
            Date.FormatStyle()
                .month(.twoDigits)
                .day(.twoDigits)
                .weekday(.wide)
                .locale(Locale(identifier: "zh_CN"))
        )
    }

    var exportFilenameTimestamp: String {
        formatted(
            Date.VerbatimFormatStyle(
                format: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)-\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased))\(minute: .twoDigits)",
                locale: Locale(identifier: "en_US_POSIX"),
                timeZone: .current,
                calendar: .current
            )
        )
    }

    static var startOfToday: Date {
        Calendar.current.startOfDay(for: Date())
    }

    static var endOfToday: Date {
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday) else {
            return Date()
        }
        return tomorrow.addingTimeInterval(-1)
    }
}

extension TimeInterval {
    /// Formats a TimeInterval into a compact duration string like "1h 23m" or "45m".
    var compactDuration: String {
        let totalSeconds = max(0, Int(self))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    /// Formats as countdown timer "23:45" (MM:SS) or "1:23:45" (H:MM:SS).
    var countdownString: String {
        let totalSeconds = max(0, Int(self))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Compact remaining time for the menu bar ("1h 5m", "14m", or "45s").
    var menuBarRemainingString: String {
        let totalSeconds = max(0, Int(ceil(self)))
        if totalSeconds < 60 {
            return "\(totalSeconds)s"
        }
        let totalMinutes = (totalSeconds + 59) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }
}
