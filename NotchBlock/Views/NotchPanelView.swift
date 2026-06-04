import SwiftUI

/// The dropdown panel shown below the notch on hover (V2 redesign).
///
/// Read-only glance surface:
/// - Active task with large countdown + tap to open main window
/// - Upcoming tasks (max 5, scrollable)
/// - Quick-add button (opens main window)
/// - Empty state when no tasks for the day
struct NotchPanelView: View {
    @ObservedObject var store: TimeBlockStore
    @State private var now = Date()

    /// 1-second tick for countdown, runs in .common modes (no freeze during tracking).
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// Called when user taps any task or the "add" button — opens main scheduler.
    var onOpenMainWindow: (() -> Void)?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if let active = activeBlock {
                activeTaskSection(active)
            } else if upcomingBlocks.isEmpty {
                emptyState
            } else if let next = upcomingBlocks.first {
                nextUpSection(next)
            } else {
                emptyState
            }

            if !listBlocks.isEmpty {
                Divider()
                    .padding(.horizontal, 12)
                upcomingSection
            }

            Divider()
                .padding(.horizontal, 12)
            quickAddBar
        }
        .padding(.vertical, 10)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.12), .white.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 40, y: 12)
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .onReceive(tick) { _ in
            now = Date()
        }
    }

    // MARK: - Active Task Section

    private func activeTaskSection(_ block: TimeBlock) -> some View {
        Button {
            onOpenMainWindow?()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    Text("进行中")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let remaining = block.remainingTime {
                        Text(remaining.countdownString)
                            .font(.system(size: 28, weight: .bold).monospacedDigit())
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())
                    }
                }

                Text(block.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("\(block.startTime.timeString) — \(block.endTime.timeString)")
                        .font(.caption)
                }
                .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Next-Up Section (when no active task)

    private func nextUpSection(_ block: TimeBlock) -> some View {
        Button {
            onOpenMainWindow?()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 7, height: 7)
                    Text("即将开始")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(block.startTime.timeString)
                        .font(.title3.monospacedDigit().weight(.medium))
                        .foregroundStyle(.orange)
                }

                Text(block.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                Text("时长 \(block.duration.compactDuration)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Upcoming Section

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("接下来")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    ForEach(listBlocks) { block in
                        upcomingRow(block)
                    }
                }
            }
            .frame(maxHeight: min(CGFloat(listBlocks.count) * 44, 220))
        }
    }

    private func upcomingRow(_ block: TimeBlock) -> some View {
        Button {
            onOpenMainWindow?()
        } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(block.isBreak ? Color.blue.opacity(0.5) : Color.orange.opacity(0.7))
                    .frame(width: 3, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(block.title)
                        .font(.subheadline)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    Text("\(block.startTime.timeString) · \(block.duration.compactDuration)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .opacity(0.6)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(rowHoverColor(block))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .scaleEffect(rowHoverScale(block))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.snappy(duration: 0.15)) { hoveredBlockID = hovering ? block.id : nil }
        }
    }

    @State private var hoveredBlockID: UUID?

    private func rowHoverColor(_ block: TimeBlock) -> Color {
        hoveredBlockID == block.id ? Color.primary.opacity(0.05) : .clear
    }

    private func rowHoverScale(_ block: TimeBlock) -> CGFloat {
        hoveredBlockID == block.id ? 1.02 : 1.0
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("今天暂无安排")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text("菜单栏或排程面板添加任务")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
    }

    // MARK: - Quick Add Bar

    private var quickAddBar: some View {
        Button {
            onOpenMainWindow?()
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(BrandColors.accent)
                Text("添加任务...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Computed

    private var activeBlock: TimeBlock? { store.activeBlock(at: now) }
    private var upcomingBlocks: [TimeBlock] {
        store.upcomingBlocks(after: now, limit: 5)
    }

    /// Upcoming blocks for the list, excluding the first when shown as hero (nextUpSection).
    private var listBlocks: [TimeBlock] {
        if activeBlock == nil, !upcomingBlocks.isEmpty {
            return Array(upcomingBlocks.dropFirst())
        }
        return upcomingBlocks
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Active + Upcoming") {
    let store = TimeBlockStore()
    let now = Date()
    let cal = Calendar.current
    let sod = cal.startOfDay(for: now)

    store.blocks = [
        TimeBlock(title: "深度工作", startTime: cal.date(byAdding: .hour, value: 9, to: sod)!, endTime: cal.date(byAdding: .hour, value: 11, to: sod)!, status: .pending),
        TimeBlock(title: "代码审查", startTime: cal.date(byAdding: .hour, value: 11, to: sod)!, endTime: cal.date(byAdding: .hour, value: 12, to: sod)!, status: .pending),
        TimeBlock(title: "午休", startTime: cal.date(byAdding: .hour, value: 12, to: sod)!, endTime: cal.date(byAdding: .hour, value: 13, to: sod)!, status: .pending, isBreak: true),
    ]
    return NotchPanelView(store: store).padding(40)
}

#Preview("Empty") {
    NotchPanelView(store: TimeBlockStore()).padding(40)
}
#endif
