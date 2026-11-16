import AppKit
import OSLog
import SwiftUI
import UniformTypeIdentifiers

private let exportLogger = Logger(subsystem: "com.notchblock.app", category: "Export")

/// Menu bar icon presets shared between MenuBarIconView and SettingsView.
enum MenuBarIconStyle: String, CaseIterable, Sendable {
    case timer
    case clock
    case hourglass
    case blocks

    var systemImage: String {
        switch self {
        case .timer:     return "timer"
        case .clock:     return "calendar.badge.clock"
        case .hourglass: return "hourglass"
        case .blocks:    return "square.grid.3x3.fill"
        }
    }

    var label: String {
        switch self {
        case .timer:     return "计时器"
        case .clock:     return "日历时钟"
        case .hourglass: return "沙漏"
        case .blocks:    return "方块"
        }
    }
}

/// Interactive frosted-glass popover displayed from the menu bar item (`.menuBarExtraStyle(.window)`).
struct MenuBarPopoverView: View {
    let store: TimeBlockStore
    let updateChecker: UpdateChecker
    let onOpenMainWindow: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openSettings) private var openSettings
    @State private var quickAddTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MenuBarStatusHeader(store: store)

            QuickAddRow(title: $quickAddTitle, onSubmit: quickAdd)

            MinimalHairline()

            VStack(spacing: 2) {
                PopoverActionRow(title: "打开排程面板", systemImage: "calendar", shortcut: "⌘O") {
                    dismiss()
                    onOpenMainWindow()
                }
                .keyboardShortcut("o", modifiers: .command)

                PopoverActionRow(title: "偏好设置...", systemImage: "gearshape", shortcut: "⌘,") {
                    dismiss()
                    NSApp.setActivationPolicy(.regular)
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut(",", modifiers: .command)

                PopoverActionRow(title: "导出数据...", systemImage: "square.and.arrow.up") {
                    dismiss()
                    exportData()
                }

                PopoverActionRow(
                    title: updateChecker.isInstalling
                        ? "正在安装更新..."
                        : (updateChecker.isDownloading
                            ? "正在下载更新 (\(Int(updateChecker.downloadProgress * 100))%)"
                            : "检查更新..."),
                    systemImage: "arrow.triangle.2.circlepath"
                ) {
                    dismiss()
                    updateChecker.checkForUpdates(showNoUpdateAlert: true)
                }
                .disabled(updateChecker.isChecking || updateChecker.isDownloading || updateChecker.isInstalling)

                MinimalHairline()
                    .padding(.vertical, 4)

                PopoverActionRow(title: "退出 NotchBlock", systemImage: "power", shortcut: "⌘Q", isDestructive: true) {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(12)
        .frame(width: 288)
        .background {
            FrostedGlassBackground(
                material: .popover,
                blendingMode: .behindWindow,
                tint: BrandColors.panelGlass
            )
            .ignoresSafeArea()
        }
        .tint(BrandColors.accentText)
    }

    private func quickAdd() {
        let trimmed = quickAddTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let start = Date()
        let block = TimeBlock(
            title: trimmed,
            startTime: start,
            endTime: start.addingTimeInterval(1800)
        )
        store.add(block)
        quickAddTitle = ""
    }

    private func exportData() {
        let savePanel = NSSavePanel()
        savePanel.title = "导出时间块数据"
        savePanel.nameFieldStringValue = "NotchBlock-备份-\(Date().exportFilenameTimestamp).json"
        savePanel.allowedContentTypes = [.json]

        NSApp.activate(ignoringOtherApps: true)
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            do {
                let data = try encoder.encode(store.blocks)
                try data.write(to: url)
            } catch {
                exportLogger.error("Export failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Subviews

private struct MenuBarStatusHeader: View {
    let store: TimeBlockStore

    var body: some View {
        SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            Group {
                if let active = store.activeBlock(at: now) {
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(BrandColors.accentText)
                                    .frame(width: 6, height: 6)
                                Text("进行中")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(BrandColors.textSecondary)
                            }
                            Text(active.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BrandColors.textPrimary)
                                .lineLimit(1)
                            if let remaining = active.remainingTime(at: now) {
                                Text(remaining.countdownString)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(BrandColors.accentText)
                                    .contentTransition(.numericText())
                            }
                        }
                        Spacer()
                        Button {
                            store.update(active.with(status: .completed))
                        } label: {
                            Label("完成", systemImage: "checkmark")
                                .font(.caption.weight(.medium))
                        }
                        .buttonStyle(MinimalPrimaryButtonStyle(cornerRadius: 7, horizontalPadding: 10, verticalPadding: 5))
                    }
                } else if let next = store.upcomingBlocks(after: now, limit: 1).first {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("下一任务")
                                .font(.caption2)
                                .foregroundStyle(BrandColors.textSecondary)
                            Text(next.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(BrandColors.textPrimary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(next.startTime.timeString)
                            .font(.subheadline.monospacedDigit().weight(.medium))
                            .foregroundStyle(BrandColors.accentText)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "moon.stars")
                            .font(.caption)
                            .foregroundStyle(BrandColors.accentText)
                        Text("今日暂无排程")
                            .font(.subheadline)
                            .foregroundStyle(BrandColors.textSecondary)
                        Spacer()
                    }
                }
            }
            .padding(10)
            .minimalCard(
                cornerRadius: 10,
                fill: store.activeBlock(at: now) != nil ? BrandColors.accentSoft : BrandColors.surface,
                border: store.activeBlock(at: now) != nil ? BrandColors.accentBorder : BrandColors.hairline
            )
        }
    }
}

private struct QuickAddRow: View {
    @Binding var title: String
    let onSubmit: () -> Void

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 6) {
            TextField("快速创建 30 分钟任务...", text: $title)
                .minimalInput(cornerRadius: 8)
                .onSubmit(onSubmit)

            Button(action: onSubmit) {
                Image(systemName: "plus")
                    .font(.caption.weight(.semibold))
                    .frame(width: 28, height: 30)
            }
            .buttonStyle(MinimalPrimaryButtonStyle(cornerRadius: 8, horizontalPadding: 0, verticalPadding: 0))
            .disabled(!canSubmit)
            .help("创建 30 分钟时间块")
        }
    }
}

private struct PopoverActionRow: View {
    let title: String
    let systemImage: String
    var shortcut: String? = nil
    var isDestructive = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.caption)
                    .frame(width: 16)
                    .foregroundStyle(isDestructive ? BrandColors.missed : BrandColors.textSecondary)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(isDestructive ? BrandColors.missed : BrandColors.textPrimary)
                Spacer()
                if let shortcut {
                    Text(shortcut)
                        .font(.caption2.monospaced())
                        .foregroundStyle(BrandColors.textTertiary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovering ? BrandColors.surfaceSubtle : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
