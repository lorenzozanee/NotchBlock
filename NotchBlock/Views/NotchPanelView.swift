import SwiftUI

/// The dropdown panel content shown below the notch (AC 2.2).
///
/// Displays:
/// - Current active task with countdown timer
/// - Next 2 upcoming tasks
/// - Clean, minimal design with frosted glass background
struct NotchPanelView: View {
    @ObservedObject var store: TimeBlockStore
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            if let active = activeBlock {
                activeTaskSection(active)
                Divider().padding(.horizontal, 16)
            }
            upcomingSection
        }
        .padding(.vertical, 12)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 16, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
        .onReceive(timer) { _ in now = Date() }
    }

    // MARK: - Computed

    private var activeBlock: TimeBlock? { store.activeBlock(at: now) }
    private var upcomingBlocks: [TimeBlock] { store.upcomingBlocks(after: now, limit: 2) }

    // MARK: - Active Task

    private func activeTaskSection(_ block: TimeBlock) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(Color.green).frame(width: 8, height: 8)
                Text("当前任务").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                if let remaining = block.remainingTime {
                    Text(remaining.countdownString)
                        .font(.title3.monospacedDigit().weight(.bold))
                        .foregroundStyle(.green)
                        .contentTransition(.numericText())
                }
            }
            Text(block.title).font(.headline).lineLimit(1)
            HStack(spacing: 4) {
                Image(systemName: "clock").font(.caption2)
                Text("\(block.startTime.timeString) — \(block.endTime.timeString)").font(.caption)
            }
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    // MARK: - Upcoming

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("接下来").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                .padding(.horizontal, 16).padding(.top, 8)

            if upcomingBlocks.isEmpty {
                HStack {
                    Image(systemName: "moon.zzz").font(.caption).foregroundStyle(.tertiary)
                    Text("今天没有更多任务了").font(.caption).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            } else {
                ForEach(upcomingBlocks) { block in upcomingRow(block) }
            }
        }
    }

    private func upcomingRow(_ block: TimeBlock) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.orange).frame(width: 3, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(block.title).font(.subheadline).lineLimit(1)
                Text("\(block.startTime.timeString) · \(block.duration.compactDuration)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 4)
    }
}

#if DEBUG
#Preview {
    let store = TimeBlockStore()
    let now = Date()
    let cal = Calendar.current
    let sod = cal.startOfDay(for: now)

    store.blocks = [
        TimeBlock(title: "深度工作", startTime: cal.date(byAdding: .hour, value: 9, to: sod)!, endTime: cal.date(byAdding: .hour, value: 10, to: sod)!, status: .pending),
        TimeBlock(title: "代码审查", startTime: cal.date(byAdding: .hour, value: 10, to: sod)!, endTime: cal.date(byAdding: .hour, value: 11, to: sod)!, status: .pending),
        TimeBlock(title: "午休", startTime: cal.date(byAdding: .hour, value: 12, to: sod)!, endTime: cal.date(byAdding: .hour, value: 13, to: sod)!, status: .pending),
    ]
    return NotchPanelView(store: store).padding(40)
}
#endif
