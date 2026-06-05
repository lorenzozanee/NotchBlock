import Foundation

struct TimeBlock: Identifiable, Codable, Equatable {
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

    // Custom Decodable for backward compat: old data lacks notes/isBreak fields
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        startTime = try c.decode(Date.self, forKey: .startTime)
        endTime = try c.decode(Date.self, forKey: .endTime)
        status = try c.decode(BlockStatus.self, forKey: .status)
        notes = (try? c.decode(String.self, forKey: .notes)) ?? ""
        isBreak = (try? c.decode(Bool.self, forKey: .isBreak)) ?? false
    }
}

// MARK: - Factory

extension TimeBlock {
    func with(status: BlockStatus) -> TimeBlock {
        TimeBlock(id: id, title: title, startTime: startTime, endTime: endTime, status: status, notes: notes, isBreak: isBreak)
    }

    func withEndTime(_ newEnd: Date) -> TimeBlock {
        TimeBlock(id: id, title: title, startTime: startTime, endTime: newEnd, status: status, notes: notes, isBreak: isBreak)
    }

    func withStartTime(_ newStart: Date) -> TimeBlock {
        TimeBlock(id: id, title: title, startTime: newStart, endTime: endTime, status: status, notes: notes, isBreak: isBreak)
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
