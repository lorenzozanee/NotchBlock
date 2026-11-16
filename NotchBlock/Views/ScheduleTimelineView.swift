import SwiftUI

/// Vertical day timeline with clustered overlap columns and configurable focus hours.
struct ScheduleTimelineView: View {
    let blocks: [TimeBlock]
    let activeBlockID: UUID?
    let onTap: (TimeBlock) -> Void

    @AppStorage("focusStartHour") private var focusStartHour = 9
    @AppStorage("focusEndHour") private var focusEndHour = 18

    private let gutterWidth: CGFloat = 46
    private let minHourHeight: CGFloat = 44
    private let maxHourHeight: CGFloat = 80

    private var hourRange: ClosedRange<Int> {
        let cal = Calendar.current
        var minHour = max(0, min(focusStartHour, 22))
        var maxHour = max(minHour + 1, min(focusEndHour, 24))

        for block in blocks {
            let startH = cal.component(.hour, from: block.startTime)
            let endComp = cal.dateComponents([.hour, .minute], from: block.endTime)
            let endH = (endComp.hour ?? 0) + ((endComp.minute ?? 0) > 0 ? 1 : 0)
            minHour = min(minHour, startH)
            if cal.isDate(block.endTime, inSameDayAs: block.startTime) {
                maxHour = max(maxHour, min(24, endH))
            } else {
                maxHour = 24
            }
        }
        return minHour...maxHour
    }

    private var startHour: Int { hourRange.lowerBound }
    private var endHour: Int { hourRange.upperBound }
    private var totalHours: Int { max(1, endHour - startHour) }

    var body: some View {
        GeometryReader { geo in
            let hourHeight = min(max(geo.size.height / CGFloat(totalHours), minHourHeight), maxHourHeight)
            let totalHeight = CGFloat(totalHours) * hourHeight

            ScrollView {
                ZStack(alignment: .topLeading) {
                    TimelineGutter(startHour: startHour, endHour: endHour, gutterWidth: gutterWidth, hourHeight: hourHeight)
                    TimelineBlocksLayer(
                        blocks: blocks,
                        activeBlockID: activeBlockID,
                        startHour: startHour,
                        totalHours: totalHours,
                        totalHeight: totalHeight,
                        gutterWidth: gutterWidth,
                        availableWidth: geo.size.width,
                        onTap: onTap
                    )
                    CurrentTimeLine(
                        startHour: startHour,
                        totalHours: totalHours,
                        totalHeight: totalHeight,
                        gutterWidth: gutterWidth
                    )
                }
                .padding(.top, 8)
                .frame(minHeight: max(totalHeight + 24, geo.size.height), alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
        }
    }
}

// MARK: - Subviews

private struct TimelineGutter: View {
    let startHour: Int
    let endHour: Int
    let gutterWidth: CGFloat
    let hourHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ForEach(startHour..<endHour, id: \.self) { hour in
                HStack(alignment: .top, spacing: 6) {
                    Text(String(format: "%02d:00", hour))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(BrandColors.textTertiary)
                        .frame(width: gutterWidth - 6, alignment: .trailing)
                    Rectangle()
                        .fill(BrandColors.hairline)
                        .frame(height: 0.5)
                        .padding(.top, 5)
                }
                .frame(height: hourHeight, alignment: .top)
            }
            HStack(alignment: .top, spacing: 6) {
                Text(String(format: "%02d:00", endHour))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(BrandColors.textTertiary)
                    .frame(width: gutterWidth - 6, alignment: .trailing)
                Rectangle()
                    .fill(BrandColors.hairline)
                    .frame(height: 0.5)
                    .padding(.top, 5)
            }
            .frame(height: 0, alignment: .top)
        }
    }
}

private struct TimelineBlocksLayer: View {
    let blocks: [TimeBlock]
    let activeBlockID: UUID?
    let startHour: Int
    let totalHours: Int
    let totalHeight: CGFloat
    let gutterWidth: CGFloat
    let availableWidth: CGFloat
    let onTap: (TimeBlock) -> Void

    private struct LayoutItem: Identifiable {
        var id: UUID { block.id }
        let block: TimeBlock
        let columnIndex: Int
        let columnCount: Int
    }

    var body: some View {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let rangeStart = cal.date(byAdding: .hour, value: startHour, to: todayStart) ?? todayStart
        let totalSeconds = TimeInterval(totalHours * 3600)
        let contentLeft = gutterWidth + 8
        let contentWidth = max(120, availableWidth - contentLeft - 14)

        ForEach(layoutItems) { item in
            let startOffset = max(0, item.block.startTime.timeIntervalSince(rangeStart))
            let rawEndOffset = item.block.endTime.timeIntervalSince(rangeStart)
            let clampedEnd = min(totalSeconds, max(startOffset + 300, rawEndOffset))

            let topY = CGFloat(startOffset / totalSeconds) * totalHeight + 5
            let rawHeight = CGFloat((clampedEnd - startOffset) / totalSeconds) * totalHeight
            let height = max(24, rawHeight - 2)

            let columnGap: CGFloat = 4
            let colWidth = (contentWidth - CGFloat(item.columnCount - 1) * columnGap) / CGFloat(item.columnCount)
            let leftX = contentLeft + CGFloat(item.columnIndex) * (colWidth + columnGap)

            TimelineBlockCard(
                block: item.block,
                isActive: item.block.id == activeBlockID,
                height: height,
                width: max(40, colWidth),
                onTap: { onTap(item.block) }
            )
            .offset(x: leftX, y: topY)
        }
    }

    private var layoutItems: [LayoutItem] {
        let sorted = blocks.sorted {
            if $0.startTime != $1.startTime { return $0.startTime < $1.startTime }
            return $0.endTime < $1.endTime
        }

        var clusters: [[TimeBlock]] = []
        var currentCluster: [TimeBlock] = []
        var clusterEnd = Date.distantPast

        for block in sorted {
            if currentCluster.isEmpty || block.startTime < clusterEnd {
                currentCluster.append(block)
                clusterEnd = max(clusterEnd, block.endTime)
            } else {
                clusters.append(currentCluster)
                currentCluster = [block]
                clusterEnd = block.endTime
            }
        }
        if !currentCluster.isEmpty { clusters.append(currentCluster) }

        var items: [LayoutItem] = []
        for cluster in clusters {
            var columns: [[TimeBlock]] = []
            for block in cluster {
                if let colIndex = columns.firstIndex(where: { ($0.last?.endTime ?? .distantPast) <= block.startTime }) {
                    columns[colIndex].append(block)
                } else {
                    columns.append([block])
                }
            }
            let count = max(1, columns.count)
            for (colIndex, colBlocks) in columns.enumerated() {
                for block in colBlocks {
                    items.append(LayoutItem(block: block, columnIndex: colIndex, columnCount: count))
                }
            }
        }
        return items
    }
}

private struct TimelineBlockCard: View {
    let block: TimeBlock
    let isActive: Bool
    let height: CGFloat
    let width: CGFloat
    let onTap: () -> Void

    var body: some View {
        let accentColor = BrandColors.color(for: block, isActive: isActive)
        let cardFill = isActive ? BrandColors.accentSoft : BrandColors.surface
        let borderColor = isActive ? BrandColors.accentBorder : BrandColors.hairline

        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(block.startTime.timeString)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(BrandColors.textSecondary)
                Text(block.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(block.status == .completed ? BrandColors.textTertiary : BrandColors.textPrimary)
                    .lineLimit(height > 44 ? 2 : 1)
                if height > 44 {
                    Text(block.duration.compactDuration)
                        .font(.system(size: 9))
                        .foregroundStyle(BrandColors.textTertiary)
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 6)
            .padding(.vertical, 4)
            .frame(width: width, height: height, alignment: .topLeading)
            .minimalCard(cornerRadius: 8, fill: cardFill, border: borderColor)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: 3)
                    .padding(.vertical, 4)
                    .padding(.leading, 1)
            }
        }
        .buttonStyle(.plain)
        .animation(.smooth(duration: 0.2), value: block.status)
    }
}

private struct CurrentTimeLine: View {
    let startHour: Int
    let totalHours: Int
    let totalHeight: CGFloat
    let gutterWidth: CGFloat

    var body: some View {
        SwiftUI.TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = context.date
            let cal = Calendar.current
            let startOfDay = cal.startOfDay(for: now)
            let rangeStart = cal.date(byAdding: .hour, value: startHour, to: startOfDay) ?? startOfDay
            let elapsed = now.timeIntervalSince(rangeStart)
            let totalSeconds = TimeInterval(totalHours * 3600)

            if elapsed >= 0 && elapsed <= totalSeconds {
                let yOffset = CGFloat(elapsed / totalSeconds) * totalHeight + 5
                HStack(spacing: 0) {
                    Circle()
                        .fill(BrandColors.accentText)
                        .frame(width: 6, height: 6)
                    Rectangle()
                        .fill(BrandColors.accentText.opacity(0.65))
                        .frame(height: 1)
                }
                .padding(.leading, gutterWidth - 3)
                .offset(y: yOffset - 3)
                .allowsHitTesting(false)
            }
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
        TimeBlock(title: "同步会议", startTime: cal.date(byAdding: .hour, value: 10, to: today)!, endTime: cal.date(byAdding: .hour, value: 11, to: today)!, status: .pending),
        TimeBlock(title: "下午专注", startTime: cal.date(byAdding: .hour, value: 14, to: today)!, endTime: cal.date(byAdding: .hour, value: 16, to: today)!, status: .pending),
    ]
    ScheduleTimelineView(blocks: blocks, activeBlockID: blocks[1].id, onTap: { _ in })
        .frame(width: 460, height: 500)
}
#endif
