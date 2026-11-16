import SwiftUI

struct MainSchedulerView: View {
    let store: TimeBlockStore
    let scheduler: BlockScheduler
    var stats: StatisticsStore?
    var updateChecker: UpdateChecker?

    @State private var showAddSheet = false
    @State private var editingBlock: TimeBlock?
    @State private var showStats = false
    @State private var viewMode: ViewMode = .list
    @State private var showWhatsNew = false
    @State private var whatsNewVersion = ""
    @State private var whatsNewChangelog = ""

    enum ViewMode: String, CaseIterable, Hashable {
        case list = "列表"
        case timeline = "时间轴"
    }

    private var todayBlocks: [TimeBlock] {
        store.todayBlocks()
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            MinimalHairline()

            Group {
                if todayBlocks.isEmpty {
                    emptyState
                } else if viewMode == .timeline {
                    ScheduleTimelineView(
                        blocks: todayBlocks,
                        activeBlockID: scheduler.activeBlockID,
                        onTap: { block in
                            if !block.isBreak {
                                editingBlock = block
                            }
                        }
                    )
                } else {
                    blockList
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !todayBlocks.isEmpty {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(BrandColors.accentOnFill)
                            .frame(width: 42, height: 42)
                            .background {
                                ZStack {
                                    VisualEffectBackdrop(material: .popover, blendingMode: .withinWindow)
                                    BrandColors.accentFill
                                }
                                .clipShape(Circle())
                            }
                            .overlay(Circle().strokeBorder(BrandColors.accentBorder, lineWidth: 1))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("n", modifiers: .command)
                    .shadow(color: .black.opacity(0.22), radius: 12, y: 4)
                    .padding(18)
                    .accessibilityLabel("新建任务")
                    .transition(.scale.combined(with: .opacity))
                }
            }

            MinimalHairline()
            SchedulerStatusBar(store: store, scheduler: scheduler, stats: stats)
        }
        .frame(minWidth: 460, idealWidth: 520, minHeight: 420, idealHeight: 560)
        .background {
            FrostedGlassBackground(
                material: .underWindowBackground,
                tint: BrandColors.canvasGlass
            )
            .ignoresSafeArea()
        }
        .tint(BrandColors.accentText)
        .onAppear {
            if let updateChecker, let changelog = updateChecker.checkWhatsNew() {
                whatsNewVersion = updateChecker.currentVersion
                whatsNewChangelog = changelog
                showWhatsNew = true
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddEditBlockView(store: store)
        }
        .sheet(item: $editingBlock) { block in
            AddEditBlockView(store: store, existingBlock: block)
        }
        .sheet(isPresented: $showStats) {
            if let stats {
                StatisticsView(stats: stats)
            }
        }
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewView(version: whatsNewVersion, changelog: whatsNewChangelog) {
                showWhatsNew = false
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("今日排程")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(BrandColors.textPrimary)
                Text(Date().chineseDateString)
                    .font(.caption)
                    .foregroundStyle(BrandColors.textSecondary)
            }

            Spacer()

            HStack(spacing: 8) {
                MinimalSegmentedControl(
                    options: ViewMode.allCases.map { ($0, $0.rawValue) },
                    selection: $viewMode
                )

                if stats != nil {
                    Button {
                        showStats = true
                    } label: {
                        Label("统计", systemImage: "chart.bar")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(MinimalSecondaryButtonStyle(horizontalPadding: 10, verticalPadding: 6))
                }
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(BrandColors.accentSoft)
                    .frame(width: 56, height: 56)
                Circle()
                    .strokeBorder(BrandColors.accentBorder, lineWidth: 1)
                    .frame(width: 56, height: 56)
                Image(systemName: "calendar")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(BrandColors.accentText)
            }

            Text("暂无排程")
                .font(.headline)
                .foregroundStyle(BrandColors.textPrimary)

            Button {
                showAddSheet = true
            } label: {
                Label("新建任务", systemImage: "plus")
            }
            .buttonStyle(MinimalPrimaryButtonStyle(horizontalPadding: 18, verticalPadding: 8))
            .keyboardShortcut("n", modifiers: .command)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Block List

    private var blockList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(todayBlocks) { block in
                    TimeBlockRowView(
                        block: block,
                        isActive: block.id == scheduler.activeBlockID,
                        onToggleComplete: block.isBreak ? nil : { toggleStatus(for: block) }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !block.isBreak {
                            editingBlock = block
                        }
                    }
                    .contextMenu { statusMenu(for: block) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .padding(.bottom, 56)
        }
        .scrollIndicators(.hidden)
    }

    private func toggleStatus(for block: TimeBlock) {
        let nextStatus: BlockStatus = block.status == .completed ? .pending : .completed
        store.update(block.with(status: nextStatus))
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func statusMenu(for block: TimeBlock) -> some View {
        if !block.isBreak {
            if block.status != .completed {
                Button {
                    store.update(block.with(status: .completed))
                } label: {
                    Label("标记已完成", systemImage: "checkmark.circle")
                }
            }
            if block.status != .missed {
                Button {
                    store.update(block.with(status: .missed))
                } label: {
                    Label("标记未完成", systemImage: "xmark.circle")
                }
            }
            if block.status != .pending && block.endTime > Date() {
                Button {
                    store.update(block.with(status: .pending))
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
    }
}

private struct SchedulerStatusBar: View {
    let store: TimeBlockStore
    let scheduler: BlockScheduler
    let stats: StatisticsStore?

    private var activeBlock: TimeBlock? {
        guard let activeID = scheduler.activeBlockID else { return nil }
        return store.blocks.first { $0.id == activeID }
    }

    var body: some View {
        HStack(spacing: 14) {
            if let active = activeBlock {
                HStack(spacing: 6) {
                    Circle()
                        .fill(BrandColors.accentText)
                        .frame(width: 6, height: 6)
                    Text(active.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(BrandColors.textPrimary)
                        .lineLimit(1)
                    if let remaining = active.remainingTime(at: scheduler.now) {
                        Text(remaining.countdownString)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(BrandColors.accentText)
                            .contentTransition(.numericText())
                    }
                }
            } else {
                Text("空闲")
                    .font(.caption)
                    .foregroundStyle(BrandColors.textTertiary)
            }

            Spacer()

            if let s = stats {
                HStack(spacing: 10) {
                    Text("\(s.todayCompleted)/\(s.todayTotal)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(BrandColors.textSecondary)
                    Text(s.todayFocusTime.compactDuration)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(BrandColors.accentText)
                    if s.currentStreak > 1 {
                        Label("\(s.currentStreak)d", systemImage: "flame")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(BrandColors.textSecondary)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(BrandColors.surface.opacity(0.65))
    }
}

#if DEBUG
#Preview {
    let store = TimeBlockStore(userDefaults: UserDefaults(suiteName: "preview.main") ?? .standard)
    let scheduler = BlockScheduler(store: store)
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: Date())

    store.blocks = [
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
    ]

    return MainSchedulerView(store: store, scheduler: scheduler, stats: StatisticsStore(store: store))
}
#endif
