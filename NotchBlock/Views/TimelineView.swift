import SwiftUI

/// Vertical timeline with column-based overlap layout and adaptive sizing.
/// Blocks that overlap in time are placed side-by-side like Google Calendar.
/// Hour height adapts to available container size via GeometryReader.
struct TimelineView: View {
    let blocks: [TimeBlock]
    let activeBlockID: UUID?
    let onTap: (TimeBlock) -> Void

    private let startHour = 6
    private let endHour = 24
    private let gutterWidth: CGFloat = 44
    private let minHourHeight: CGFloat = 40
    private let maxHourHeight: CGFloat = 80

    private var totalHours: Int { endHour - startHour }

    var body: some View {
        GeometryReader { geo in
            let hh = min(max(geo.size.height / CGFloat(totalHours), minHourHeight), maxHourHeight)
            let th = CGFloat(totalHours) * hh
            ScrollView {
                ZStack(alignment: .topLeading) {
                    timeGutter(hourHeight: hh)
                    blockOverlay(hourHeight: hh, totalHeight: th, availableWidth: geo.size.width)
                }
                .frame(height: max(th, geo.size.height))
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Time Gutter

    private func timeGutter(hourHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(startHour..<endHour, id: \.self) { hour in
                HStack(alignment: .top, spacing: 0) {
                    Text(String(format: "%02d:00", hour))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .frame(width: gutterWidth - 8, alignment: .trailing)
                    Rectangle().fill(.quaternary).frame(height: 0.5)
                }
                .frame(height: hourHeight, alignment: .top)
            }
            HStack(alignment: .top, spacing: 0) {
                Text("24:00").font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
                    .frame(width: gutterWidth - 8, alignment: .trailing)
                Rectangle().fill(.quaternary).frame(height: 0.5)
            }
            .frame(height: 0, alignment: .top)
        }
    }

    // MARK: - Block Overlay

    private func blockOverlay(hourHeight: CGFloat, totalHeight: CGFloat, availableWidth: CGFloat) -> some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startOfRange = calendar.date(byAdding: .hour, value: startHour, to: today)!
        let totalSeconds = CGFloat(totalHours * 3600)
        let contentWidth = availableWidth - gutterWidth
        let laidOut = layoutColumns(blocks: blocks)

        return ZStack(alignment: .topLeading) {
            ForEach(laidOut, id: \.block.id) { item in
                let secs = item.block.startTime.timeIntervalSince(startOfRange)
                let y = CGFloat(secs) / totalSeconds * totalHeight
                let h = max(CGFloat(item.block.duration) / totalSeconds * totalHeight, 24)
                let clampedY = max(0, min(y, totalHeight - h))
                let isActive = item.block.id == activeBlockID
                let colW = contentWidth / CGFloat(item.columnCount)
                let xOff = CGFloat(item.columnIndex) * colW

                timelineBlock(
                    block: item.block, y: clampedY, height: h,
                    xOffset: xOff, width: colW - 4, isActive: isActive
                )
            }
        }
        .padding(.leading, gutterWidth)
        .frame(height: totalHeight)
    }

    // MARK: - Column Layout

    private struct LayoutItem {
        let block: TimeBlock; let columnIndex: Int; let columnCount: Int
    }

    /// Greedy column assignment: each block goes to the first column
    /// where it doesn't overlap any already-placed block.
    private func layoutColumns(blocks: [TimeBlock]) -> [LayoutItem] {
        let sorted = blocks.sorted { $0.startTime < $1.startTime }
        var columns: [[TimeBlock]] = [[]]

        for block in sorted {
            var placed = false
            for colIdx in 0..<columns.count {
                let overlaps = columns[colIdx].contains { $0.overlaps(with: block) }
                if !overlaps { columns[colIdx].append(block); placed = true; break }
            }
            if !placed { columns.append([block]) }
        }

        let totalCols = columns.count
        var result: [LayoutItem] = []
        for (colIdx, colBlocks) in columns.enumerated() {
            for b in colBlocks {
                result.append(LayoutItem(block: b, columnIndex: colIdx, columnCount: totalCols))
            }
        }
        return result.sorted { $0.block.startTime < $1.block.startTime }
    }

    // MARK: - Single Block

    @ViewBuilder
    private func timelineBlock(
        block: TimeBlock, y: CGFloat, height: CGFloat,
        xOffset: CGFloat, width: CGFloat, isActive: Bool
    ) -> some View {
        let color = blockColor(block: block, isActive: isActive)
        VStack(alignment: .leading, spacing: 2) {
            Text(block.startTime.timeString)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(block.title)
                .font(.caption.weight(.medium)).lineLimit(2)
            if height > 30 {
                Text(block.duration.compactDuration)
                    .font(.system(size: 9)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .frame(width: max(width, 0), height: height, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(isActive ? 0.25 : 0.12))
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 3).padding(.leading, -4)
        }
        .offset(x: xOffset, y: y)
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
        TimeBlock(title: "深度工作", startTime: cal.date(byAdding: .hour, value: 9, to: today)!, endTime: cal.date(byAdding: .hour, value: 11, to: today)!, status: .pending),
        TimeBlock(title: "会议", startTime: cal.date(byAdding: .hour, value: 10, to: today)!, endTime: cal.date(byAdding: .hour, value: 11, to: today)!, status: .pending),
        TimeBlock(title: "午休", startTime: cal.date(byAdding: .hour, value: 13, to: today)!, endTime: cal.date(byAdding: .hour, value: 14, to: today)!, status: .pending),
    ]
    TimelineView(blocks: blocks, activeBlockID: blocks[1].id, onTap: { _ in })
}
#endif
