import Cocoa
import SwiftUI

/// Standalone onboarding window — NOT a sheet, avoids sheet interaction bugs on macOS.
final class OnboardingWindowController {
    private var panel: NSPanel?

    func show(store: TimeBlockStore) {
        guard panel == nil else { return }

        let contentView = OnboardingView(onComplete: { [weak self] in
            if store.todayBlocks().isEmpty {
                let cal = Calendar.current
                let start = cal.startOfDay(for: Date())
                let blocks: [TimeBlock] = [
                    TimeBlock(title: "晨间规划", startTime: cal.date(byAdding: .hour, value: 9, to: start)!, endTime: cal.date(byAdding: .hour, value: 9, to: start)!.addingTimeInterval(900), status: .completed),
                    TimeBlock(title: "深度工作", startTime: cal.date(byAdding: .hour, value: 10, to: start)!, endTime: cal.date(byAdding: .hour, value: 12, to: start)!, status: .pending),
                    TimeBlock(title: "午休", startTime: cal.date(byAdding: .hour, value: 12, to: start)!, endTime: cal.date(byAdding: .hour, value: 13, to: start)!, status: .pending),
                ]
                for b in blocks { store.add(b) }
            }
            self?.dismiss()
        })

        let hosting = NSHostingView(rootView: contentView)
        hosting.frame = NSRect(x: 0, y: 0, width: 480, height: 460)

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 460),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.title = "欢迎使用 NotchBlock"
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces]
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = hosting
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
}
