import Foundation

struct TimeBlock: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    var title: String
    var startTime: Date
    var endTime: Date
    var status: BlockStatus
    var notes: String
    var isBreak: Bool

    init(
        id: UUID = UUID(),
        title: String,
        startTime: Date,
        endTime: Date,
        status: BlockStatus = .pending,
        notes: String = "",
        isBreak: Bool = false
    ) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.status = status
        self.notes = notes
        self.isBreak = isBreak
    }

    enum CodingKeys: String, CodingKey {
        case id, title, startTime, endTime, status, notes, isBreak
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        startTime = try c.decode(Date.self, forKey: .startTime)
        endTime = try c.decode(Date.self, forKey: .endTime)
        status = try c.decode(BlockStatus.self, forKey: .status)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        isBreak = try c.decodeIfPresent(Bool.self, forKey: .isBreak) ?? false
    }
}

// MARK: - Factory

extension TimeBlock {
    func with(status: BlockStatus) -> TimeBlock {
        TimeBlock(
            id: id, title: title, startTime: startTime, endTime: endTime,
            status: status, notes: notes, isBreak: isBreak
        )
    }

    func withEndTime(_ newEnd: Date) -> TimeBlock {
        TimeBlock(
            id: id, title: title, startTime: startTime, endTime: newEnd,
            status: status, notes: notes, isBreak: isBreak
        )
    }

    func withStartTime(_ newStart: Date) -> TimeBlock {
        TimeBlock(
            id: id, title: title, startTime: newStart, endTime: endTime,
            status: status, notes: notes, isBreak: isBreak
        )
    }
}

// MARK: - Queries

extension TimeBlock {
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    /// Half-open interval [startTime, endTime) so adjacent blocks don't overlap at boundaries.
    func contains(_ date: Date) -> Bool {
        date >= startTime && date < endTime
    }

    func overlaps(with other: TimeBlock) -> Bool {
        startTime < other.endTime && other.startTime < endTime
    }

    func isActiveNow(at date: Date = Date()) -> Bool {
        contains(date) && status == .pending
    }

    func remainingTime(at date: Date = Date()) -> TimeInterval? {
        guard date < endTime else { return nil }
        return endTime.timeIntervalSince(date)
    }

    func isPast(at date: Date = Date()) -> Bool {
        date >= endTime
    }

    var isActiveNow: Bool { isActiveNow() }
    var remainingTime: TimeInterval? { remainingTime() }
    var isPast: Bool { isPast() }

    var hasValidTimeRange: Bool {
        startTime < endTime
    }
}
