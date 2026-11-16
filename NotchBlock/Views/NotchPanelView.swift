import SwiftUI

/// The frosted-glass dropdown panel shown below the notch on hover.
struct NotchPanelView: View {
    let store: TimeBlockStore
    var presentation: NotchPanelController.PresentationState = .init(isVisible: true)
    var onOpenMainWindow: (() -> Void)?

    var body: some View {
        SwiftUI.TimelineView(PausablePeriodicSchedule(paused: !presentation.isVisible, interval: 1)) { context in
            let now = context.date
            let activeBlock = store.activeBlock(at: now)
            let upcomingBlocks = store.upcomingBlocks(after: now, limit: 5)
            let listBlocks = (activeBlock == nil && !upcomingBlocks.isEmpty)
                ? Array(upcomingBlocks.dropFirst())
                : upcomingBlocks

            VStack(spacing: 0) {
                if let active = activeBlock {
                    activeTaskSection(active, now: now)
                } else if let next = upcomingBlocks.first {
                    nextUpSection(next)
                } else {
                    emptyState
                }

                if !listBlocks.isEmpty {
                    MinimalHairline()
                        .padding(.horizontal, 14)
                    upcomingSection(listBlocks)
                }

                MinimalHairline()
                    .padding(.horizontal, 14)
                quickAddBar
            }
            .padding(.vertical, 8)
            .frame(width: 320)
            .background {
                FrostedGlassBackground(
                    material: .hudWindow,
                    tint: BrandColors.panelGlass,
                    cornerRadius: 18,
                    showBorder: true
                )
            }
        }
    }

    // MARK: - Sections

    private func activeTaskSection(_ block: TimeBlock, now: Date) -> some View {
        Button {
            onOpenMainWindow?()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Circle()
                        .fill(BrandColors.accentText)
                        .frame(width: 6, height: 6)
                    Text("进行中")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(BrandColors.textSecondary)
                    Spacer()
                    if let remaining = block.remainingTime(at: now) {
                        Text(remaining.countdownString)
                            .font(.system(size: 26, weight: .semibold).monospacedDigit())
                            .foregroundStyle(BrandColors.textPrimary)
                            .contentTransition(.numericText())
                    }
                }

                Text(block.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundStyle(BrandColors.textPrimary)

                Text("\(block.startTime.timeString) — \(block.endTime.timeString)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(BrandColors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func nextUpSection(_ block: TimeBlock) -> some View {
        Button {
            onOpenMainWindow?()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Circle()
                        .fill(BrandColors.accent)
                        .frame(width: 6, height: 6)
                    Text("即将开始")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(BrandColors.textSecondary)
                    Spacer()
                    Text(block.startTime.timeString)
                        .font(.title3.monospacedDigit().weight(.medium))
                        .foregroundStyle(BrandColors.accentText)
                }

                Text(block.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundStyle(BrandColors.textPrimary)

                Text(block.duration.compactDuration)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(BrandColors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.stars")
                .font(.title3)
                .foregroundStyle(BrandColors.accentText)
            Text("今日暂无安排")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(BrandColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 22)
    }

    private var quickAddBar: some View {
        Button {
            onOpenMainWindow?()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandColors.accentText)
                Text("打开排程面板")
                    .font(.subheadline)
                    .foregroundStyle(BrandColors.textSecondary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .foregroundStyle(BrandColors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func upcomingSection(_ listBlocks: [TimeBlock]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("接下来")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BrandColors.textTertiary)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 2)

            ScrollView(.vertical) {
                VStack(spacing: 2) {
                    ForEach(listBlocks) { block in
                        UpcomingRowView(block: block) {
                            onOpenMainWindow?()
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: min(CGFloat(listBlocks.count) * 46, 200))
        }
    }
}

private struct PausablePeriodicSchedule: TimelineSchedule {
    let paused: Bool
    let interval: TimeInterval

    struct Entries: Sequence, IteratorProtocol {
        var nextDate: Date?
        let interval: TimeInterval
        let paused: Bool

        mutating func next() -> Date? {
            guard let current = nextDate else { return nil }
            nextDate = paused ? nil : current.addingTimeInterval(interval)
            return current
        }
    }

    func entries(from startDate: Date, mode: Mode) -> Entries {
        Entries(nextDate: startDate, interval: interval, paused: paused)
    }
}

private struct UpcomingRowView: View {
    let block: TimeBlock
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(block.isBreak ? BrandColors.breakAccent : BrandColors.accent)
                    .frame(width: 3, height: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(block.title)
                        .font(.subheadline)
                        .lineLimit(1)
                        .foregroundStyle(BrandColors.textPrimary)
                    Text("\(block.startTime.timeString) · \(block.duration.compactDuration)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(BrandColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BrandColors.textTertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovering ? BrandColors.surfaceSubtle : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.snappy(duration: 0.14)) {
                isHovering = hovering
            }
        }
    }
}

#if DEBUG
#Preview("Active + Upcoming") {
    let store = TimeBlockStore(userDefaults: UserDefaults(suiteName: "preview.notch") ?? .standard)
    let now = Date()

    store.blocks = [
        TimeBlock(title: "深度工作", startTime: now.addingTimeInterval(-1200), endTime: now.addingTimeInterval(2400), status: .pending),
        TimeBlock(title: "代码审查", startTime: now.addingTimeInterval(2700), endTime: now.addingTimeInterval(6300), status: .pending),
        TimeBlock(title: "休息", startTime: now.addingTimeInterval(2400), endTime: now.addingTimeInterval(2700), status: .pending, isBreak: true),
    ]
    return NotchPanelView(store: store).padding(40)
}

#Preview("Empty") {
    NotchPanelView(store: TimeBlockStore(userDefaults: UserDefaults(suiteName: "preview.notch.empty") ?? .standard)).padding(40)
}
#endif
