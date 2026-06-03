import SwiftUI

@main
struct NotchBlockApp: App {
    @StateObject private var store = TimeBlockStore()

    var body: some Scene {
        // Main scheduler window — opened from menu bar
        WindowGroup {
            MainSchedulerView(store: store)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 460, height: 500)

        // Menu bar item — always visible, lightweight
        MenuBarExtra {
            menuBarContent
        } label: {
            menuBarIcon
        }
    }

    // MARK: - Menu Bar Content

    @ViewBuilder
    private var menuBarContent: some View {
        // Quick status overview
        if let active = store.activeBlock() {
            VStack(alignment: .leading, spacing: 4) {
                Text("当前任务").font(.caption).foregroundStyle(.secondary)
                Text(active.title).font(.headline)
                if let remaining = active.remainingTime {
                    Text("剩余 \(remaining.countdownString)")
                        .font(.caption.monospacedDigit())
                }
            }
            .padding(.vertical, 4)
            Divider()
        }

        Button("打开排程面板") {
            openMainWindow()
        }
        .keyboardShortcut("o")

        Divider()

        if let next = store.upcomingBlocks(after: Date(), limit: 1).first {
            Button("下一任务：\(next.title) (\(next.startTime.timeString))") {
                openMainWindow()
            }
            .disabled(true) // display-only
        }

        Divider()

        Button("退出 NotchBlock") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    // MARK: - Menu Bar Icon

    @ViewBuilder
    private var menuBarIcon: some View {
        if let active = store.activeBlock() {
            // Show active indicator with remaining time
            if let remaining = active.remainingTime {
                let minutes = Int(remaining / 60)
                Image(systemName: "timer")
                Text("\(minutes)m")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            } else {
                Image(systemName: "timer")
            }
        } else {
            Image(systemName: "calendar.badge.clock")
        }
    }

    // MARK: - Helpers

    private func openMainWindow() {
        // Activate app and bring scheduler window to front
        NSApp.activate(ignoringOtherApps: true)
        // Find or open the main window
        for window in NSApp.windows where window.title.contains("排程") || window.canBecomeKey {
            window.makeKeyAndOrderFront(nil)
            return
        }
        // If no window found, open a new one via Window menu
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
