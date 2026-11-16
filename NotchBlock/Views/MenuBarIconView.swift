import SwiftUI

/// Live-updating menu bar status item label driven by BlockScheduler's 1s tick when active.
struct MenuBarIconView: View {
    let store: TimeBlockStore
    let scheduler: BlockScheduler
    let iconStyle: String
    let showTime: Bool

    var body: some View {
        let style = MenuBarIconStyle(rawValue: iconStyle) ?? .timer

        HStack(spacing: 4) {
            Image(systemName: style.systemImage)
            if let activeID = scheduler.activeBlockID,
               let active = store.blocks.first(where: { $0.id == activeID }) {
                if showTime, let remaining = active.remainingTime(at: scheduler.now) {
                    Text(remaining.menuBarRemainingString)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                }
            } else {
                let pendingCount = store.todayBlocks().filter { !$0.isBreak && $0.status == .pending }.count
                if pendingCount > 0 {
                    Text("\(pendingCount)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                }
            }
        }
    }
}
