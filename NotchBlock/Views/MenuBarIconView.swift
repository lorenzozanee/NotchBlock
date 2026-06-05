import SwiftUI

/// Live-updating menu bar icon with 1s countdown tick.
/// Reads NotchBlockApp.IconStyle to avoid duplication.
struct MenuBarIconView: View {
    @ObservedObject var store: TimeBlockStore
    let iconStyle: String
    let showTime: Bool
    @State private var now = Date()

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let s = NotchBlockApp.IconStyle(rawValue: iconStyle) ?? .timer
        Group {
            if let active = store.activeBlock(at: now), active.endTime > now {
                if showTime {
                    let remaining = active.endTime.timeIntervalSince(now)
                    Image(systemName: s.systemImage)
                    Text("\(Int(remaining / 60))m")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                } else {
                    Image(systemName: s.systemImage)
                }
            } else {
                let pending = store.todayBlocks().filter { $0.status == .pending }.count
                if pending > 0 {
                    Image(systemName: s.systemImage)
                    Text("\(pending)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: s.systemImage)
                }
            }
        }
        .onReceive(tick) { t in now = t }
    }
}
