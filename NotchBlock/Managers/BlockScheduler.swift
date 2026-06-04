import Foundation
import Combine

/// Monitors time blocks and triggers the hard-interrupt overlay when a block's end time arrives.
///
/// Runs a 1-second polling timer. When a .pending block's endTime passes,
/// fires `onBlockEnded` so the app can show the overlay (Phase 3).
final class BlockScheduler: ObservableObject {
    private let store: TimeBlockStore
    private var timer: Timer?
    private var triggeredBlockIDs = Set<UUID>()

    /// Called when a block's end time is reached and the overlay should appear
    var onBlockEnded: ((TimeBlock) -> Void)?

    init(store: TimeBlockStore) {
        self.store = store
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkBlocks()
        }
        checkBlocks() // catch already-expired blocks immediately
    }

    func stop() { timer?.invalidate(); timer = nil }
    deinit { stop() }

    // MARK: - Internal

    private func checkBlocks() {
        let now = Date()
        let today = store.todayBlocks()

        for block in today {
            guard block.status == .pending else { continue }

            if block.endTime <= now {
                if !block.isBreak && !triggeredBlockIDs.contains(block.id) {
                    triggeredBlockIDs.insert(block.id)
                    DispatchQueue.main.async { [weak self] in
                        self?.onBlockEnded?(block)
                    }
                }
                if block.isBreak { completeBreak(block) }
                else { autoMarkMissed(block) }
            }
        }
    }

    private func completeBreak(_ block: TimeBlock) {
        store.update(block.with(status: .completed))
    }

    private func autoMarkMissed(_ block: TimeBlock) { store.update(block.with(status: .missed)) }
}
