import SwiftUI

/// Productivity analytics dashboard showing daily/weekly completion data.
struct StatisticsView: View {
    @ObservedObject var stats: StatisticsStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("📊 统计").font(.headline)
                Spacer()
                Picker("", selection: $selectedTab) {
                    Text("今日").tag(0); Text("热力图").tag(1); Text("趋势").tag(2)
                }.pickerStyle(.segmented).frame(width: 200)
            }.padding(.horizontal, 20).padding(.vertical, 14)
            Divider()
            ScrollView {
                VStack(spacing: 20) {
                    switch selectedTab {
                    case 0: todaySection; weekSection
                    case 1: heatmapSection
                    case 2: trendSection
                    default: EmptyView()
                    }
                }.padding(20)
            }
            Divider()
            HStack {
                if let best = stats.bestHour, selectedTab == 1 {
                    Label("最佳时段: \(best.hour):00 (\(Int(best.rate * 100))%)", systemImage: "sparkles")
                        .font(.caption).foregroundStyle(.orange)
                }
                Spacer()
                Button("关闭") { dismiss() }
            }.padding(.horizontal, 20).padding(.vertical, 10)
        }
        .frame(width: 460, height: 520)
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日").font(.title3.weight(.semibold))
            HStack(spacing: 16) {
                statCard(icon: "checkmark.circle.fill", color: .green,
                         value: "\(stats.todayCompleted)/\(stats.todayTotal)", label: "完成任务")
                statCard(icon: "clock.fill", color: .blue,
                         value: stats.todayFocusTime.compactDuration, label: "专注时间")
                statCard(icon: "flame.fill", color: .orange,
                         value: "\(stats.currentStreak)天", label: "连续打卡")
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("完成率").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(stats.todayCompletionRate * 100))%")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.15)).frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(completionBarColor)
                            .frame(width: geo.size.width * stats.todayCompletionRate, height: 8)
                    }
                }.frame(height: 8)
            }
        }
    }

    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本周").font(.title3.weight(.semibold))
            HStack(spacing: 4) {
                ForEach(stats.weekDailyCompletion, id: \.label) { day in
                    VStack(spacing: 4) {
                        Text("\(day.count)").font(.caption2.monospacedDigit().weight(.medium))
                            .foregroundStyle(day.count > 0 ? .primary : .tertiary)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(day.count > 0 ? Color.accentColor : Color.secondary.opacity(0.15))
                            .frame(height: max(4, CGFloat(day.count) * 20))
                        Text(day.label).font(.system(size: 10)).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity)
                }
            }.frame(height: 120)
            HStack {
                Label("周完成: \(stats.weekTotalCompleted) 项", systemImage: "checkmark")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Label("周专注: \(stats.weekTotalFocusTime.compactDuration)", systemImage: "timer")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var completionBarColor: Color {
        let rate = stats.todayCompletionRate
        if rate >= 0.8 { return .green }
        if rate >= 0.5 { return .orange }
        return .red
    }

    // MARK: - Heatmap

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("时段完成率").font(.title3.weight(.semibold))
            Text("颜色越深 = 完成率越高").font(.caption).foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6), spacing: 4) {
                ForEach(stats.hourlyProductivity, id: \.hour) { h in
                    VStack(spacing: 2) {
                        Text(String(format: "%02d", h.hour))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(heatmapColor(rate: h.rate, count: h.count))
                            .frame(height: 28)
                        if h.count > 0 {
                            Text("\(Int(h.rate * 100))%")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("·").font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Trend

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("周完成率趋势").font(.title3.weight(.semibold))

            VStack(spacing: 8) {
                ForEach(stats.weeklyTrend, id: \.label) { week in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(week.label).font(.caption).frame(width: 50, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.secondary.opacity(0.1)).frame(height: 20)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(trendColor(rate: week.rate))
                                        .frame(width: geo.size.width * week.rate, height: 20)
                                }
                            }.frame(height: 20)
                            Text("\(week.completed)/\(week.total)")
                                .font(.caption2.monospacedDigit()).frame(width: 30, alignment: .trailing)
                            Text("\(Int(week.rate * 100))%")
                                .font(.caption2.monospacedDigit().weight(.medium)).frame(width: 36, alignment: .trailing)
                        }
                    }
                }
            }

            HStack {
                Label("专注总时长: \(stats.weekTotalFocusTime.compactDuration)", systemImage: "timer")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }.padding(.top, 4)
        }
    }

    // MARK: - Helpers

    private func heatmapColor(rate: Double, count: Int) -> Color {
        if count == 0 { return Color.secondary.opacity(0.05) }
        if rate >= 0.8 { return .green.opacity(0.7) }
        if rate >= 0.5 { return .orange.opacity(0.5) }
        if rate > 0 { return .red.opacity(0.4) }
        return Color.secondary.opacity(0.1)
    }

    private func trendColor(rate: Double) -> Color {
        if rate >= 0.7 { return .green }
        if rate >= 0.4 { return .orange }
        return .red
    }

    private func statCard(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}

#if DEBUG
#Preview { StatisticsView(stats: StatisticsStore(store: TimeBlockStore())) }
#endif
