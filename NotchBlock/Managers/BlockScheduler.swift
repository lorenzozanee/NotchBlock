import Foundation
import Observation

/// Monitors pending time blocks on a 1-second structured task and triggers
/// the fullscreen overlay when a block's end time arrives.
@Observable
@MainActor
final class BlockScheduler {
    private(set) var now = Date()
    private(set) var activeBlockID: UUID?

    @ObservationIgnored private let store: TimeBlockStore
    @ObservationIgnored private let staleThreshold: TimeInterval
    @ObservationIgnored private var triggeredBlockIDs = Set<UUID>()
    @ObservationIgnored nonisolated(unsafe) private var pollingTask: Task<Void, Never>?

    @ObservationIgnored var onBlockEnded: ((TimeBlock) -> Void)?

    init(store: TimeBlockStore, staleThreshold: TimeInterval = 300) {
        self.store = store
        self.staleThreshold = staleThreshold
    }

    deinit {
        pollingTask?.cancel()
    }

    func start() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.checkBlocks()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Block Evaluation

    func checkBlocks(now: Date = Date()) {
        self.now = now
        var breakIDsToComplete = Set<UUID>()
        var staleIDsToMiss = Set<UUID>()
        var newlyEndedBlocks: [TimeBlock] = []

        for block in store.blocks where block.status == .pending {
            if block.endTime > now {
                // Clear trigger cache if the block was extended or rescheduled into the future.
                triggeredBlockIDs.remove(block.id)
                continue
            }

            if block.isBreak {
                breakIDsToComplete.insert(block.id)
            } else if now.timeIntervalSince(block.endTime) > staleThreshold {
                staleIDsToMiss.insert(block.id)
            } else if !triggeredBlockIDs.contains(block.id) {
                triggeredBlockIDs.insert(block.id)
                newlyEndedBlocks.append(block)
            }
        }

        if !breakIDsToComplete.isEmpty || !staleIDsToMiss.isEmpty {
            store.applyBatch { blocks in
                for idx in blocks.indices {
                    if breakIDsToComplete.contains(blocks[idx].id) {
                        blocks[idx] = blocks[idx].with(status: .completed)
                    } else if staleIDsToMiss.contains(blocks[idx].id) {
                        blocks[idx] = blocks[idx].with(status: .missed)
                    }
                }
            }
        }

        for block in newlyEndedBlocks {
            onBlockEnded?(block)
        }

        let currentActiveID = store.activeBlock(at: now)?.id
        if activeBlockID != currentActiveID {
            activeBlockID = currentActiveID
        }
    }
}
