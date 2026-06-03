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

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func markTriggered(_ block: TimeBlock) {
        triggeredBlockIDs.insert(block.id)
    }

    // MARK: - Internal

    private func checkBlocks() {
        let now = Date()
        let today = store.todayBlocks()

        for block in today {
            guard block.status == .pending else { continue }

            if block.endTime <= now {
                // Avoid re-triggering overlay for already-handled blocks
                if !triggeredBlockIDs.contains(block.id) {
                    triggeredBlockIDs.insert(block.id)
                    DispatchQueue.main.async { [weak self] in
                        self?.onBlockEnded?(block)
                    }
                }
                // AC 6.0: auto-mark as missed even if overlay wasn't shown
                // (e.g. app was closed when block ended). Overlay will update
                // to .completed if user confirms, overriding this.
                autoMarkMissed(block)
            }
        }
    }

    /// Marks a past pending block as .missed (AC 6.0 — runs continuously,
    /// not dependent on main window being open).
    private func autoMarkMissed(_ block: TimeBlock) {
        let updated = TimeBlock(
            id: block.id,
            title: block.title,
            startTime: block.startTime,
            endTime: block.endTime,
            status: .missed
        )
        store.update(updated)
    }
}
