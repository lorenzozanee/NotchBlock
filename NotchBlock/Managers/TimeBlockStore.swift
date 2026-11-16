import Foundation
import Observation
import OSLog

private let storeLogger = Logger(subsystem: "com.notchblock.app", category: "Store")

/// Persists TimeBlock array to UserDefaults as ISO8601 JSON.
@Observable
@MainActor
final class TimeBlockStore {
    var blocks: [TimeBlock] = []
    @ObservationIgnored var onDidChange: (() -> Void)?

    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private let storageKey: String
    @ObservationIgnored private let encoder: JSONEncoder
    @ObservationIgnored private let decoder: JSONDecoder

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "com.notchblock.timeblocks"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec

        load()
    }

    // MARK: - CRUD

    func add(_ block: TimeBlock) {
        applyBatch { $0.append(block) }
    }

    func update(_ block: TimeBlock) {
        applyBatch { blocks in
            guard let index = blocks.firstIndex(where: { $0.id == block.id }) else { return }
            blocks[index] = block
        }
    }

    func delete(_ block: TimeBlock) {
        applyBatch { blocks in
            blocks.removeAll { $0.id == block.id }
        }
    }

    /// Extends a block's end time from `max(endTime, now)` so late extensions always land in the future,
    /// shifting either all subsequent pending user blocks or cascading overlapping ones.
    func extendBlock(id: UUID, by seconds: TimeInterval, shiftAllSubsequent: Bool, now: Date = Date()) {
        guard seconds > 0, let target = blocks.first(where: { $0.id == id }) else { return }

        let originalEnd = target.endTime
        let extendedEnd = max(originalEnd, now).addingTimeInterval(seconds)
        let delta = extendedEnd.timeIntervalSince(originalEnd)
        let calendar = Calendar.current

        applyBatch { blocks in
            if let index = blocks.firstIndex(where: { $0.id == id }) {
                blocks[index] = blocks[index].withEndTime(extendedEnd).with(status: .pending)
            }

            let subsequentIDs = blocks
                .filter {
                    !$0.isBreak &&
                    $0.status == .pending &&
                    $0.id != id &&
                    calendar.isDate($0.startTime, inSameDayAs: originalEnd) &&
                    $0.startTime >= originalEnd
                }
                .sorted { $0.startTime < $1.startTime }
                .map(\.id)

            if shiftAllSubsequent {
                let shiftSet = Set(subsequentIDs)
                for index in blocks.indices where shiftSet.contains(blocks[index].id) {
                    blocks[index] = blocks[index]
                        .withStartTime(blocks[index].startTime.addingTimeInterval(delta))
                        .withEndTime(blocks[index].endTime.addingTimeInterval(delta))
                }
            } else {
                var minimumStart = extendedEnd
                for nextID in subsequentIDs {
                    guard let nextIndex = blocks.firstIndex(where: { $0.id == nextID }) else { continue }
                    let currentStart = blocks[nextIndex].startTime
                    guard currentStart < minimumStart else { break }
                    let shift = minimumStart.timeIntervalSince(currentStart)
                    let newEnd = blocks[nextIndex].endTime.addingTimeInterval(shift)
                    blocks[nextIndex] = blocks[nextIndex]
                        .withStartTime(minimumStart)
                        .withEndTime(newEnd)
                    minimumStart = newEnd
                }
            }
        }
    }

    /// Applies multiple mutations and persists once, optionally firing `onDidChange`.
    func applyBatch(_ transform: (inout [TimeBlock]) -> Void, notifyChange: Bool = true) {
        var updated = blocks
        transform(&updated)
        guard updated != blocks else { return }
        blocks = updated
        save(notifyChange: notifyChange)
    }

    // MARK: - Queries

    func blocks(for date: Date) -> [TimeBlock] {
        let calendar = Calendar.current
        return blocks
            .filter { calendar.isDate($0.startTime, inSameDayAs: date) }
            .sorted { $0.startTime < $1.startTime }
    }

    func todayBlocks() -> [TimeBlock] {
        blocks(for: Date())
    }

    func activeBlock(at date: Date = Date()) -> TimeBlock? {
        blocks
            .filter { $0.contains(date) && $0.status == .pending }
            .sorted {
                if $0.isBreak != $1.isBreak { return !$0.isBreak }
                return $0.startTime < $1.startTime
            }
            .first
    }

    func upcomingBlocks(after date: Date = Date(), limit: Int = 2) -> [TimeBlock] {
        blocks(for: date)
            .filter { $0.startTime > date && $0.status == .pending }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Validation

    /// Returns conflicting user blocks (auto-generated breaks do not block scheduling).
    func conflicts(for block: TimeBlock) -> [TimeBlock] {
        blocks
            .filter { existing in
                !existing.isBreak && existing.id != block.id && existing.overlaps(with: block)
            }
            .sorted { $0.startTime < $1.startTime }
    }

    // MARK: - Persistence

    func save(notifyChange: Bool = true) {
        let capped = blocksCappedToWindow(days: 90)
        do {
            let data = try encoder.encode(capped)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            storeLogger.error("Failed to encode time blocks: \(error.localizedDescription)")
        }
        if notifyChange {
            onDidChange?()
        }
    }

    private func load() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            blocks = []
            return
        }
        do {
            let decoded = try decoder.decode([TimeBlock].self, from: data)
            blocks = blocksCappedToWindow(blocks: decoded, days: 90)
        } catch {
            storeLogger.error("Failed to decode time blocks: \(error.localizedDescription)")
            blocks = []
        }
    }

    /// Prunes blocks older than `days` to prevent UserDefaults bloat.
    private func blocksCappedToWindow(blocks: [TimeBlock]? = nil, days: Int) -> [TimeBlock] {
        let source = blocks ?? self.blocks
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            return source
        }
        return source.filter { $0.endTime >= cutoff }
    }

    var totalHistoricalCount: Int { blocks.count }
}
