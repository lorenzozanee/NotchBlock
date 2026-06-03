import SwiftUI

struct MainSchedulerView: View {
    @ObservedObject var store: TimeBlockStore
    @State private var showAddSheet = false
    @State private var editingBlock: TimeBlock?
    @State private var activeBlock: TimeBlock?
    @State private var now = Date()

    /// Timer fires every 30s to refresh active-block detection and relative times
    private let tickTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            if todayBlocks.isEmpty {
                emptyState
            } else {
                blockList
            }
            Divider()
            statusBar
        }
        .frame(minWidth: 420, idealWidth: 460, minHeight: 360, idealHeight: 500)
        .sheet(isPresented: $showAddSheet) {
            AddEditBlockView(store: store)
        }
        .sheet(item: $editingBlock) { block in
            AddEditBlockView(store: store, existingBlock: block)
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
            Button {
                showAddSheet = true
            } label: {
                Label("添加任务", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("今天还没有安排任务")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("点击上方「添加任务」开始规划你的时间块")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Button("添加第一个任务") {
                showAddSheet = true
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
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
                .onTapGesture {
                    editingBlock = block
                }
                .contextMenu {
                    statusMenu(for: block)
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            if let active = activeBlock {
                Label("当前：\(active.title)", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let remaining = active.remainingTime {
                    Text("剩余 \(remaining.countdownString)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.green)
                }
            } else {
                Label("暂无进行中的任务", systemImage: "moon.zzz")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
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
        autoMarkMissed()
    }

    /// Marks past pending blocks as missed
    private func autoMarkMissed() {
        for block in store.pastPendingBlocks() {
            let updated = TimeBlock(
                id: block.id,
                title: block.title,
                startTime: block.startTime,
                endTime: block.endTime,
                status: .missed
            )
            store.update(updated)
        }
    }

    private func markCompleted(_ block: TimeBlock) {
        let updated = TimeBlock(
            id: block.id,
            title: block.title,
            startTime: block.startTime,
            endTime: block.endTime,
            status: .completed
        )
        store.update(updated)
    }

    private func markPending(_ block: TimeBlock) {
        let updated = TimeBlock(
            id: block.id,
            title: block.title,
            startTime: block.startTime,
            endTime: block.endTime,
            status: .pending
        )
        store.update(updated)
    }

    // MARK: - Helpers

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM月dd日 EEEE"
        return formatter.string(from: Date())
    }
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
