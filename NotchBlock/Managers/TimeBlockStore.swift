import Foundation
import Combine
import OSLog

private let storeLogger = Logger(subsystem: "com.notchblock.app", category: "Store")

/// Persists TimeBlock array to UserDefaults as ISO8601 JSON.
/// Exposes @Published array for SwiftUI reactive binding.
final class TimeBlockStore: ObservableObject {
    @Published var blocks: [TimeBlock] = []
    var onDidChange: (() -> Void)?

    private let storageKey = "com.notchblock.timeblocks"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        load()
    }

    // MARK: - CRUD

    func add(_ block: TimeBlock) {
        var updated = blocks
        updated.append(block)
        blocks = updated
        save()
    }

    func update(_ block: TimeBlock) {
        guard let index = blocks.firstIndex(where: { $0.id == block.id }) else { return }
        var updated = blocks
        updated[index] = block
        blocks = updated
        save()
    }

    func delete(_ block: TimeBlock) {
        blocks = blocks.filter { $0.id != block.id }
        save()
    }

    func delete(at offsets: IndexSet) {
        var updated = blocks
        updated.remove(atOffsets: offsets)
        blocks = updated
        save()
    }

    // MARK: - Queries

    func blocks(for date: Date) -> [TimeBlock] {
        let calendar = Calendar.current
        return blocks.filter { calendar.isDate($0.startTime, inSameDayAs: date) }
    }

    func todayBlocks() -> [TimeBlock] {
        blocks(for: Date())
    }

    func activeBlock(at date: Date = Date()) -> TimeBlock? {
        todayBlocks().first { $0.contains(date) && $0.status == .pending }
    }

    func upcomingBlocks(after date: Date = Date(), limit: Int = 2) -> [TimeBlock] {
        todayBlocks()
            .filter { $0.startTime > date && $0.status == .pending }
            .sorted { $0.startTime < $1.startTime }
            .prefix(limit)
            .map { $0 }
    }

    func pastPendingBlocks() -> [TimeBlock] {
        let now = Date()
        return blocks.filter { $0.endTime < now && $0.status == .pending }
    }

    // MARK: - Validation

    /// Returns conflicting blocks if the proposed block overlaps with existing same-day blocks.
    func conflicts(for block: TimeBlock) -> [TimeBlock] {
        let sameDay = blocks(for: block.startTime)
        return sameDay.filter { existing in
            existing.id != block.id && existing.overlaps(with: block)
        }
    }

    // MARK: - Persistence

    func save() {
        let capped = blocksCappedToWindow(days: 90)
        guard let data = try? encoder.encode(capped) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
        onDidChange?()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? decoder.decode([TimeBlock].self, from: data)
        else {
            blocks = []
            return
        }
        blocks = blocksCappedToWindow(blocks: decoded, days: 90)
    }

    /// Prunes blocks older than `days` to prevent UserDefaults bloat.
    private func blocksCappedToWindow(blocks: [TimeBlock]? = nil, days: Int) -> [TimeBlock] {
        let source = blocks ?? self.blocks
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            return source
        }
        return source.filter { $0.endTime >= cutoff }
    }

    /// Total block count before capping (for statistics reference).
    var totalHistoricalCount: Int { blocks.count }
}
