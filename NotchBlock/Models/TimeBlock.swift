import Foundation

struct TimeBlock: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var startTime: Date
    var endTime: Date
    var status: BlockStatus

    init(
        id: UUID = UUID(),
        title: String,
        startTime: Date,
        endTime: Date,
        status: BlockStatus = .pending
    ) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.status = status
    }
}

// MARK: - Factory

extension TimeBlock {
    func with(status: BlockStatus) -> TimeBlock {
        TimeBlock(id: id, title: title, startTime: startTime, endTime: endTime, status: status)
    }
}

// MARK: - Computed Properties

extension TimeBlock {
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    func contains(_ date: Date) -> Bool {
        date >= startTime && date <= endTime
    }

    func overlaps(with other: TimeBlock) -> Bool {
        startTime < other.endTime && other.startTime < endTime
    }

    var isActiveNow: Bool {
        let now = Date()
        return now >= startTime && now <= endTime && status == .pending
    }

    var remainingTime: TimeInterval? {
        let now = Date()
        guard now < endTime else { return nil }
        return endTime.timeIntervalSince(now)
    }

    var isPast: Bool {
        Date() > endTime
    }

    var hasValidTimeRange: Bool {
        startTime < endTime
    }
}
