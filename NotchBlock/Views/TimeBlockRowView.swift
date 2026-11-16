import SwiftUI

struct TimeBlockRowView: View {
    let block: TimeBlock
    let isActive: Bool
    var onToggleComplete: (() -> Void)?
    @State private var isHovering = false

    var body: some View {
        let color = BrandColors.color(for: block, isActive: isActive)

        HStack(spacing: 12) {
            statusIndicator(color: color)

            VStack(alignment: .leading, spacing: 1) {
                Text(block.startTime.timeString)
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(BrandColors.textPrimary)
                Text(block.endTime.timeString)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(BrandColors.textTertiary)
            }
            .frame(width: 42, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(block.title)
                    .font(.subheadline.weight(isActive ? .semibold : .medium))
                    .foregroundStyle(block.status == .completed ? BrandColors.textTertiary : BrandColors.textPrimary)
                    .lineLimit(1)
                    .strikethrough(block.status == .completed)
                if !block.notes.isEmpty {
                    Text(block.notes)
                        .font(.caption)
                        .foregroundStyle(BrandColors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text(block.duration.compactDuration)
                .font(.caption2.monospacedDigit().weight(.medium))
                .foregroundStyle(isActive ? BrandColors.accentText : BrandColors.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(isActive ? BrandColors.accentFill.opacity(0.45) : BrandColors.surfaceSubtle)
                )
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .minimalCard(
            cornerRadius: 10,
            fill: rowFill,
            border: isActive ? BrandColors.accentBorder : BrandColors.hairline
        )
        .opacity(block.status == .completed ? 0.72 : 1.0)
        .onHover { hovering in
            withAnimation(.snappy(duration: 0.14)) {
                isHovering = hovering
            }
        }
        .animation(.easeInOut(duration: 0.2), value: block.status)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }

    @ViewBuilder
    private func statusIndicator(color: Color) -> some View {
        if let onToggleComplete {
            Button(action: onToggleComplete) {
                Image(systemName: block.status.systemImage)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 22, height: 22)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(block.status == .completed ? "恢复进行中" : "标记完成")
        } else {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .frame(width: 22, height: 22)
        }
    }

    private var rowFill: Color {
        if isActive { return BrandColors.accentSoft }
        if isHovering { return BrandColors.surfaceSubtle }
        return BrandColors.surface
    }
}

#if DEBUG
#Preview {
    let now = Date()
    let block = TimeBlock(
        title: "深度工作",
        startTime: now.addingTimeInterval(-1800),
        endTime: now.addingTimeInterval(1800),
        status: .pending,
        notes: "完成核心模块重构"
    )
    VStack(spacing: 8) {
        TimeBlockRowView(block: block, isActive: true)
        TimeBlockRowView(block: block.with(status: .completed), isActive: false)
    }
    .padding()
    .frame(width: 440)
    .background(BrandColors.canvas)
}
#endif
