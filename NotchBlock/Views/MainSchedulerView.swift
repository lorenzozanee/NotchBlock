import SwiftUI
import AppKit

struct MainSchedulerView: View {
    @ObservedObject var store: TimeBlockStore
    var stats: StatisticsStore?
    @State private var showAddSheet = false
    @State private var editingBlock: TimeBlock?
    @State private var activeBlock: TimeBlock?
    @State private var now = Date()
    @State private var showStats = false
    @State private var viewMode: ViewMode = .list
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    enum ViewMode: String, CaseIterable {
        case list = "列表"
        case timeline = "时间轴"
    }

    /// Timer fires every 30s to refresh active-block detection and relative times
    private let tickTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            if todayBlocks.isEmpty {
                emptyState
            } else if viewMode == .timeline {
                TimelineView(
                    blocks: todayBlocks,
                    activeBlockID: activeBlock?.id,
                    onTap: { editingBlock = $0 }
                )
            } else {
                blockList
            }
            Divider()
            statusBar
        }
        .frame(minWidth: 440, idealWidth: 480, minHeight: 380, idealHeight: 520)
        .tint(BrandColors.accent)
        .background(.windowBackground)
        .overlay(alignment: .bottomTrailing) {
            if !todayBlocks.isEmpty {
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                .padding(20)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear { setupKeyboardShortcuts() }
        .onDisappear { removeKeyboardShortcuts() }
        .sheet(isPresented: $showAddSheet) {
            AddEditBlockView(store: store)
        }
        .sheet(item: $editingBlock) { block in
            AddEditBlockView(store: store, existingBlock: block)
        }
        .sheet(isPresented: $showStats) {
            if let stats { StatisticsView(stats: stats) }
        }
        .onAppear(perform: refreshActiveBlock)
        .onReceive(tickTimer) { _ in
            now = Date()
            refreshActiveBlock()
        }
    }

    // MARK: - Computed

    private var todayBlocks: [TimeBlock] {
        store.todayBlocks().sorted { $0.startTime < $1.startTime }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("今日排程")
                    .font(.title2.weight(.semibold))
                Text(todayDateString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("视图", selection: $viewMode) {
                ForEach(ViewMode.allCases, id: \.rawValue) { mode in
                    Label(mode.rawValue, systemImage: mode == .list ? "list.bullet" : "rectangle.split.1x2")
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
            if stats != nil {
                Button { showStats = true } label: {
                    Label("统计", systemImage: "chart.bar.fill")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(BrandColors.accent)
                .symbolEffect(.bounce.up, options: .repeating)

            VStack(spacing: 6) {
                Text("今天还没有安排任务")
                    .font(.title3.weight(.medium))
                Text("点击下方 + 按钮或按 ⌘N 添加第一个任务")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                Label("菜单栏输入任务名，快速创建 30 分钟时间块", systemImage: "text.cursor")
                Label("鼠标悬停 Mac 刘海，快速预览今日排程", systemImage: "rectangle.and.hand.point.up.left")
                Label("任务结束时全屏遮罩强提醒，帮你保持专注", systemImage: "bell.badge")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.vertical, 8)

            Button { showAddSheet = true } label: {
                Label("添加第一个任务", systemImage: "plus")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(BrandColors.accent)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Block List

    private var blockList: some View {
        List {
            ForEach(todayBlocks) { block in
                TimeBlockRowView(
                    block: block,
                    isActive: block.id == activeBlock?.id
                )
                .contentShape(Rectangle())
                .onTapGesture { editingBlock = block }
                .contextMenu { statusMenu(for: block) }
            }
            .animation(.smooth(duration: 0.3), value: todayBlocks.map(\.id))
        }
        .listStyle(.plain)
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 16) {
            if let active = activeBlock {
                Label("当前：\(active.title)", systemImage: "clock")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let remaining = active.remainingTime {
                    Text("剩余 \(remaining.countdownString)")
                        .font(.caption.monospacedDigit()).foregroundStyle(.green)
                }
            } else {
                Label("暂无进行中的任务", systemImage: "moon.zzz")
                    .font(.caption).foregroundStyle(.tertiary)
                Spacer()
            }

            if let s = stats {
                HStack(spacing: 8) {
                    Label("\(s.todayCompleted)/\(s.todayTotal)", systemImage: "checkmark")
                        .font(.caption).foregroundStyle(.green)
                    Label(s.todayFocusTime.compactDuration, systemImage: "timer")
                        .font(.caption).foregroundStyle(.blue)
                    if s.currentStreak > 1 {
                        Label("\(s.currentStreak)天", systemImage: "flame.fill")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func statusMenu(for block: TimeBlock) -> some View {
        if block.status == .pending {
            Button {
                markCompleted(block)
            } label: {
                Label("标记已完成", systemImage: "checkmark.circle")
            }
            .sensoryFeedback(.success, trigger: block.status)
        }
        if block.status == .missed || block.status == .completed {
            Button {
                markPending(block)
            } label: {
                Label("恢复为进行中", systemImage: "arrow.uturn.backward")
            }
        }
        Divider()
        Button {
            editingBlock = block
        } label: {
            Label("编辑", systemImage: "pencil")
        }
        Divider()
        Button(role: .destructive) {
            store.delete(block)
        } label: {
            Label("删除", systemImage: "trash")
        }
    }

    // MARK: - Actions

    private func refreshActiveBlock() {
        activeBlock = store.activeBlock(at: now)
    }

    private func markCompleted(_ block: TimeBlock) { store.update(block.with(status: .completed)) }

    @State private var keyMonitor: Any?

    private func setupKeyboardShortcuts() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers == "n" {
                DispatchQueue.main.async { self.showAddSheet = true }
                return nil
            }
            return event
        }
    }

    private func removeKeyboardShortcuts() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func markPending(_ block: TimeBlock) { store.update(block.with(status: .pending)) }
    }

    // MARK: - Helpers

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM月dd日 EEEE"
        return formatter.string(from: Date())
    }

#if DEBUG
#Preview {
    let store = TimeBlockStore()
    let now = Date()
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: now)

    let blocks: [TimeBlock] = [
        TimeBlock(
            title: "晨间阅读",
            startTime: calendar.date(byAdding: .hour, value: 8, to: startOfDay)!,
            endTime: calendar.date(byAdding: .hour, value: 9, to: startOfDay)!,
            status: .completed
        ),
        TimeBlock(
            title: "深度工作",
            startTime: calendar.date(byAdding: .hour, value: 9, to: startOfDay)!,
            endTime: calendar.date(byAdding: .hour, value: 11, to: startOfDay)!,
            status: .pending
        ),
        TimeBlock(
            title: "代码审查",
            startTime: calendar.date(byAdding: .hour, value: 11, to: startOfDay)!,
            endTime: calendar.date(byAdding: .hour, value: 12, to: startOfDay)!,
            status: .pending
        ),
        TimeBlock(
            title: "午休",
            startTime: calendar.date(byAdding: .hour, value: 12, to: startOfDay)!,
            endTime: calendar.date(byAdding: .hour, value: 13, to: startOfDay)!,
            status: .pending
        ),
    ]
    store.blocks = blocks

    return MainSchedulerView(store: store)
}
#endif
