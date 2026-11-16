import Cocoa
import SwiftUI

/// Manages the main scheduler window (`id = "main"`) without a launch-time flash.
@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let store: TimeBlockStore
    private let scheduler: BlockScheduler
    private let statsStore: StatisticsStore
    private let updateChecker: UpdateChecker

    var onWindowWillShow: (() -> Void)?

    init(
        store: TimeBlockStore,
        scheduler: BlockScheduler,
        statsStore: StatisticsStore,
        updateChecker: UpdateChecker
    ) {
        self.store = store
        self.scheduler = scheduler
        self.statsStore = statsStore
        self.updateChecker = updateChecker
    }

    func show() {
        onWindowWillShow?()

        if window == nil {
            createWindow()
        }
        guard let window else { return }

        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        let hasOtherVisibleWindow = NSApp.windows.contains { other in
            other != window && other.isVisible && other.canBecomeMain
        }
        if !hasOtherVisibleWindow {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func createWindow() {
        let rootView = MainSchedulerView(
            store: store,
            scheduler: scheduler,
            stats: statsStore,
            updateChecker: updateChecker
        )
        let hostingController = NSHostingController(rootView: rootView)

        let window = NSWindow(contentViewController: hostingController)
        window.identifier = NSUserInterfaceItemIdentifier("main")
        window.title = "排程面板"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 460, height: 420)
        window.setContentSize(NSSize(width: 520, height: 560))
        window.setFrameAutosaveName("MainSchedulerWindow")
        window.center()
        window.delegate = self

        self.window = window
    }
}
