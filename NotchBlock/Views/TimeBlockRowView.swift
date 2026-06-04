import SwiftUI

struct TimeBlockRowView: View {
    let block: TimeBlock
    let isActive: Bool
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            statusIndicator
            timeColumn
            Spacer()
            titleColumn
            durationBadge
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(hoverBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: isActive ? .accentColor.opacity(0.15) : .clear, radius: 4, y: 1)
        .onHover { hovering in
            withAnimation(.snappy(duration: 0.15)) { isHovering = hovering }
        }
        .animation(.easeInOut(duration: 0.25), value: block.status)
        .contentTransition(.opacity)
    }

    // MARK: - Subviews

    private var statusIndicator: some View {
        Image(systemName: block.status.systemImage)
            .font(.title3)
            .foregroundStyle(statusColor)
            .frame(width: 24)
    }

    private var timeColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(block.startTime.timeString)
                .font(.subheadline.weight(.medium))
            Text(block.endTime.timeString)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 48, alignment: .leading)
    }

    private var titleColumn: some View {
        Text(block.title)
            .font(.body)
            .lineLimit(1)
            .strikethrough(block.status == .completed)
    }

    private var durationBadge: some View {
        Text(block.duration.compactDuration)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.quaternary, in: Capsule())
    }

    // MARK: - Styling

    private var statusColor: Color {
        switch block.status {
        case .pending:  return isActive ? .green : .orange
        case .completed: return .green
        case .missed:   return .red
        }
    }

    private var hoverBackground: some ShapeStyle {
        if isActive {
            return AnyShapeStyle(Color.accentColor.opacity(0.12))
        }
        if isHovering {
            return AnyShapeStyle(Color.secondary.opacity(0.06))
        }
        return AnyShapeStyle(Color.clear)
    }
}

#if DEBUG
#Preview {
    let now = Date()
    let block = TimeBlock(
        title: "Deep Work Session",
        startTime: now.addingTimeInterval(-1800),
        endTime: now.addingTimeInterval(1800),
        status: .pending
    )
    return VStack {
        TimeBlockRowView(block: block, isActive: true)
        TimeBlockRowView(block: block, isActive: false)
    }
    .padding()
    .frame(width: 400)
}
#endif
