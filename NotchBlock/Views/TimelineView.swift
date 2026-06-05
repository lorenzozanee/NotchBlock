import SwiftUI

/// Vertical timeline showing blocks positioned proportionally by their start/end times.
/// Time range: 06:00–24:00 (18 hours). Left gutter shows hour labels.
struct TimelineView: View {
    let blocks: [TimeBlock]
    let activeBlockID: UUID?
    let onTap: (TimeBlock) -> Void

    private let startHour = 6
    private let endHour = 24
    private let hourHeight: CGFloat = 52
    private let gutterWidth: CGFloat = 44

    private var totalHours: Int { endHour - startHour }
    private var totalHeight: CGFloat { CGFloat(totalHours) * hourHeight }

    var body: some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                timeGutter
                blockOverlay
            }
            .frame(height: totalHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollIndicators(.hidden)
    }

    // MARK: - Time Gutter

    private var timeGutter: some View {
        VStack(spacing: 0) {
            ForEach(startHour..<endHour, id: \.self) { hour in
                hourRow(String(format: "%02d:00", hour))
            }
            hourRow("24:00").frame(height: 0, alignment: .top)
        }
    }

    private func hourRow(_ label: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(label)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: gutterWidth - 8, alignment: .trailing)
            Rectangle().fill(.quaternary).frame(height: 0.5)
        }
        .frame(height: hourHeight, alignment: .top)
    }

    // MARK: - Blocks

    private var blockOverlay: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startOfRange = calendar.date(byAdding: .hour, value: startHour, to: today)!
        let totalSeconds = CGFloat(totalHours * 3600)

        return ZStack(alignment: .topLeading) {
            ForEach(blocks) { block in
                let secs = block.startTime.timeIntervalSince(startOfRange)
                let y = CGFloat(secs) / totalSeconds * totalHeight
                let h = max(CGFloat(block.duration) / totalSeconds * totalHeight, 28)
                let isActive = block.id == activeBlockID
                timelineBlock(block: block, y: y, height: h, isActive: isActive)
            }
        }
        .padding(.leading, gutterWidth)
    }

    @ViewBuilder
    private func timelineBlock(block: TimeBlock, y: CGFloat, height: CGFloat, isActive: Bool) -> some View {
        let color = blockColor(block: block, isActive: isActive)
        let clampedY = max(0, min(y, totalHeight - height))
        VStack(alignment: .leading, spacing: 2) {
            Text(block.startTime.timeString)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(block.title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
            Text(block.duration.compactDuration)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .frame(maxWidth: .infinity, minHeight: height, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(isActive ? 0.25 : 0.12))
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 3).padding(.leading, -7)
        }
        .offset(y: clampedY)
        .onTapGesture { onTap(block) }
        .animation(.smooth(duration: 0.3), value: block.status)
    }

    private func blockColor(block: TimeBlock, isActive: Bool) -> Color {
        if block.isBreak { return .purple }
        switch block.status {
        case .pending:  return isActive ? BrandColors.active : BrandColors.pending
        case .completed: return BrandColors.completed
        case .missed:   return BrandColors.missed
        }
    }
}

#if DEBUG
#Preview {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let blocks: [TimeBlock] = [
        TimeBlock(title: "晨间阅读", startTime: cal.date(byAdding: .hour, value: 7, to: today)!, endTime: cal.date(byAdding: .hour, value: 8, to: today)!, status: .completed),
        TimeBlock(title: "深度工作", startTime: cal.date(byAdding: .hour, value: 10, to: today)!, endTime: cal.date(byAdding: .hour, value: 12, to: today)!, status: .pending),
        TimeBlock(title: "午休", startTime: cal.date(byAdding: .hour, value: 13, to: today)!, endTime: cal.date(byAdding: .hour, value: 14, to: today)!, status: .pending),
    ]
    TimelineView(blocks: blocks, activeBlockID: blocks[1].id, onTap: { _ in })
}
#endif
