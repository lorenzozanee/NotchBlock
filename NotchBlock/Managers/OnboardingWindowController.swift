import Cocoa
import SwiftUI

/// Standalone onboarding window — avoids SwiftUI sheet interaction bugs on macOS.
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?

    func show(store: TimeBlockStore) {
        guard panel == nil else {
            panel?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = OnboardingView { [weak self, weak store] in
            if let store, store.todayBlocks().isEmpty {
                Self.seedStarterBlocks(into: store)
            }
            self?.dismiss()
        }

        let hosting = NSHostingView(rootView: contentView)
        hosting.frame = NSRect(x: 0, y: 0, width: 460, height: 440)

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 440),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "欢迎使用 NotchBlock"
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces]
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = hosting
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel = window
    }

    func dismiss() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        panel?.close()
        panel = nil
    }

    func windowWillClose(_ notification: Notification) {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        panel = nil
    }

    /// Creates starter blocks that never immediately trigger overdue overlays when onboarding finishes late in the day.
    private static func seedStarterBlocks(into store: TimeBlockStore, now: Date = Date()) {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: now)

        func todayAt(hour: Int, minute: Int = 0) -> Date {
            cal.date(bySettingHour: hour, minute: minute, second: 0, of: startOfDay) ?? now
        }

        let morningStart = todayAt(hour: 9)
        let morningEnd = morningStart.addingTimeInterval(900)
        let deepStart = todayAt(hour: 10)
        let deepEnd = todayAt(hour: 12)

        var starters: [TimeBlock] = [
            TimeBlock(
                title: "晨间规划",
                startTime: morningStart,
                endTime: morningEnd,
                status: .completed
            ),
            TimeBlock(
                title: "深度工作",
                startTime: deepStart,
                endTime: deepEnd,
                status: deepEnd <= now ? .completed : .pending
            ),
        ]

        if let nextSlot = cal.date(byAdding: .minute, value: 15, to: now),
           cal.isDate(nextSlot, inSameDayAs: now),
           cal.isDate(nextSlot.addingTimeInterval(1800), inSameDayAs: now),
           deepEnd <= now {
            starters.append(TimeBlock(
                title: "体验专注时间块",
                startTime: nextSlot,
                endTime: nextSlot.addingTimeInterval(1800),
                status: .pending
            ))
        }

        store.applyBatch { blocks in
            blocks.append(contentsOf: starters)
        }
    }
}
