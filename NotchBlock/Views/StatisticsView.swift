import SwiftUI

/// Productivity analytics dashboard showing daily and weekly completion metrics.
struct StatisticsView: View {
    let stats: StatisticsStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: StatsTab = .overview

    private enum StatsTab: String, CaseIterable, Hashable {
        case overview = "今日"
        case heatmap = "热力图"
        case trend = "趋势"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("统计")
                    .font(.headline)
                    .foregroundStyle(BrandColors.textPrimary)
                Spacer()
                MinimalSegmentedControl(
                    options: StatsTab.allCases.map { ($0, $0.rawValue) },
                    selection: $selectedTab
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            MinimalHairline()

            ScrollView {
                VStack(spacing: 20) {
                    switch selectedTab {
                    case .overview:
                        todaySection
                        weekSection
                    case .heatmap:
                        heatmapSection
                    case .trend:
                        trendSection
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)

            MinimalHairline()

            HStack {
                if let best = stats.bestHour, selectedTab == .heatmap {
                    Label("峰值时段 \(String(format: "%02d:00", best.hour)) · \(Int(best.rate * 100))%", systemImage: "sparkles")
                        .font(.caption)
                        .foregroundStyle(BrandColors.accentText)
                }
                Spacer()
                Button("关闭") { dismiss() }
                    .buttonStyle(MinimalSecondaryButtonStyle(horizontalPadding: 14, verticalPadding: 6))
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .frame(width: 460, height: 520)
        .background {
            FrostedGlassBackground(
                material: .hudWindow,
                tint: BrandColors.canvasGlass
            )
            .ignoresSafeArea()
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BrandColors.textSecondary)

            HStack(spacing: 12) {
                statCard(
                    icon: "checkmark.circle",
                    value: "\(stats.todayCompleted)/\(stats.todayTotal)",
                    label: "完成"
                )
                statCard(
                    icon: "clock",
                    value: stats.todayFocusTime.compactDuration,
                    label: "专注"
                )
                statCard(
                    icon: "flame",
                    value: "\(stats.currentStreak) 天",
                    label: "连续"
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("完成率")
                        .font(.caption)
                        .foregroundStyle(BrandColors.textSecondary)
                    Spacer()
                    Text("\(Int(stats.todayCompletionRate * 100))%")
                        .font(.caption.monospacedDigit().weight(.medium))
                        .foregroundStyle(BrandColors.accentText)
                }
                GeometryReader { geo in
                    let clampedRate = min(max(stats.todayCompletionRate, 0), 1)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(BrandColors.surfaceSubtle)
                            .frame(height: 7)
                        Capsule()
                            .fill(BrandColors.accent)
                            .frame(width: geo.size.width * clampedRate, height: 7)
                    }
                }
                .frame(height: 7)
            }
        }
    }

    private var weekSection: some View {
        let daily = stats.weekDailyCompletion
        let maxCount = max(daily.map(\.count).max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: 12) {
            Text("近 7 日")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BrandColors.textSecondary)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(daily) { day in
                    let barHeight = day.count > 0
                        ? max(10, CGFloat(day.count) / CGFloat(maxCount) * 76)
                        : 4
                    VStack(spacing: 4) {
                        Text("\(day.count)")
                            .font(.caption2.monospacedDigit().weight(.medium))
                            .foregroundStyle(day.count > 0 ? BrandColors.textPrimary : BrandColors.textTertiary)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(day.count > 0 ? BrandColors.accent : BrandColors.surfaceSubtle)
                            .frame(height: barHeight)
                        Text(day.label)
                            .font(.system(size: 10))
                            .foregroundStyle(BrandColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 118, alignment: .bottom)
            .padding(14)
            .minimalCard(cornerRadius: 12)

            HStack {
                Text("完成 \(stats.weekTotalCompleted) 项")
                    .font(.caption)
                    .foregroundStyle(BrandColors.textSecondary)
                Spacer()
                Text("专注 \(stats.weekTotalFocusTime.compactDuration)")
                    .font(.caption)
                    .foregroundStyle(BrandColors.accentText)
            }
        }
    }

    // MARK: - Heatmap

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("时段分布")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BrandColors.textSecondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                ForEach(stats.hourlyProductivity) { hourItem in
                    VStack(spacing: 3) {
                        Text(String(format: "%02d", hourItem.hour))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(BrandColors.textTertiary)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(BrandColors.heatmapColor(rate: hourItem.rate, count: hourItem.count))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(BrandColors.hairline.opacity(0.6), lineWidth: 0.5)
                            )
                            .frame(height: 28)
                        Text(hourItem.count > 0 ? "\(Int(hourItem.rate * 100))%" : "·")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(hourItem.count > 0 ? BrandColors.textSecondary : BrandColors.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: - Trend

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("周完成率")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BrandColors.textSecondary)

            VStack(spacing: 10) {
                ForEach(stats.weeklyTrend) { week in
                    HStack(spacing: 10) {
                        Text(week.label)
                            .font(.caption)
                            .foregroundStyle(BrandColors.textSecondary)
                            .frame(width: 46, alignment: .leading)
                        GeometryReader { geo in
                            let clampedRate = min(max(week.rate, 0), 1)
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(BrandColors.surfaceSubtle)
                                    .frame(height: 18)
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(BrandColors.accent.opacity(max(0.35, clampedRate)))
                                    .frame(width: geo.size.width * clampedRate, height: 18)
                            }
                        }
                        .frame(height: 18)
                        Text("\(week.completed)/\(week.total)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(BrandColors.textSecondary)
                            .frame(width: 34, alignment: .trailing)
                        Text("\(Int(week.rate * 100))%")
                            .font(.caption2.monospacedDigit().weight(.medium))
                            .foregroundStyle(BrandColors.accentText)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }
            .padding(14)
            .minimalCard(cornerRadius: 12)

            HStack {
                Text("近 7 日专注 \(stats.weekTotalFocusTime.compactDuration)")
                    .font(.caption)
                    .foregroundStyle(BrandColors.textSecondary)
                Spacer()
            }
        }
    }

    // MARK: - Helpers

    private func statCard(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.title3.weight(.light))
                .foregroundStyle(BrandColors.accentText)
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(BrandColors.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(BrandColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .minimalCard(cornerRadius: 10)
    }
}

#if DEBUG
#Preview {
    StatisticsView(
        stats: StatisticsStore(
            store: TimeBlockStore(userDefaults: UserDefaults(suiteName: "preview.stats") ?? .standard)
        )
    )
}
#endif
