import Foundation

private let timeFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f }()
private let weekdayFmt: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "E"; return f }()
private let dateFmt: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "MM月dd日 EEEE"; return f }()

extension Date {
    var timeString: String { timeFmt.string(from: self) }
    var weekdayLabel: String { weekdayFmt.string(from: self) }
    var chineseDateString: String { dateFmt.string(from: self) }

    /// Returns a relative description like "now", "in 15m", "5m ago"
    var relativeDescription: String {
        let interval = timeIntervalSince(Date())
        let minutes = Int(interval / 60)

        if abs(minutes) < 1 { return "just now" }
        if minutes > 0 { return "in \(minutes)m" }
        return "\(abs(minutes))m ago"
    }

    /// Returns the start of today (midnight) in the current calendar
    static var startOfToday: Date {
        Calendar.current.startOfDay(for: Date())
    }

    /// Returns the end of today (23:59:59)
    static var endOfToday: Date {
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday) else {
            return Date()
        }
        return tomorrow.addingTimeInterval(-1)
    }
}

extension TimeInterval {
    /// Formats a TimeInterval into a compact duration string like "1h 23m" or "45m"
    var compactDuration: String {
        let totalSeconds = Int(self)
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

    /// Formats as countdown timer "23:45" (MM:SS) or "1:23:45" (H:MM:SS)
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
}
