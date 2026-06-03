import SwiftUI

/// Productivity analytics dashboard showing daily/weekly completion data.
struct StatisticsView: View {
    @ObservedObject var stats: StatisticsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("📊 统计").font(.headline)
                Spacer()
            }.padding(.horizontal, 20).padding(.vertical, 14)
            Divider()
            ScrollView {
                VStack(spacing: 20) {
                    todaySection
                    Divider().padding(.horizontal, 20)
                    weekSection
                }.padding(20)
            }
            Divider()
            HStack {
                Spacer()
                Button("关闭") { dismiss() }
            }.padding(.horizontal, 20).padding(.vertical, 10)
        }
        .frame(width: 420, height: 480)
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
