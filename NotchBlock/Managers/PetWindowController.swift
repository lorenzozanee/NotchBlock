import Cocoa
import SwiftUI
import Combine
import OSLog

private let petLogger = Logger(subsystem: "com.notchblock.app", category: "PetWindow")

/// Manages the desktop pet NSPanel lifecycle, wiring the state machine,
/// animation player, SwiftUI view, and interaction handler together.
///
/// Key responsibilities:
/// - NSPanel creation with correct level/collectionBehavior for always-on-top
/// - Position restore from UserDefaults, fallback to bottom-right
/// - Generation counter for show/hide race prevention
/// - 5-second watchdog timer that recreates the panel if it goes missing
/// - Wiring: StateMachine → AnimationPlayer → PetView → InteractionHandler
@MainActor
final class PetWindowController: ObservableObject {
    private var petPanel: NSPanel?
    private let stateMachine: PetStateMachine
    private let animationPlayer: PetAnimationPlayer
    private var preferences: PetPreferences
    private var interactionHandler: PetInteractionHandler?

    // MARK: - Show/hide race prevention

    private var showGeneration = 0

    // MARK: - Watchdog

    private var watchdogTimer: Timer?
    private var watchdogRecreateCount = 0
    private static let maxWatchdogRecreates = 3
    private static let watchdogInterval: TimeInterval = 5.0

    // MARK: - Panel sizing

    private static let petWidth: CGFloat = 120
    private static let petHeight: CGFloat = 120

    // MARK: - Callbacks

    /// Called when the user clicks the pet — consumer should show the notch panel.
    var onOpenNotchPanel: (() -> Void)?

    /// Called when the user chooses "Hide Pet" from the context menu.
    var onHidePet: (() -> Void)?

    /// Called when the user chooses a different pet from the context menu.
    var onSwitchPet: ((String) -> Void)?

    // MARK: - Combine

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(store: TimeBlockStore,
         stateMachine: PetStateMachine,
         animationPlayer: PetAnimationPlayer,
         preferences: PetPreferences = PetPreferences()) {
        self.stateMachine = stateMachine
        self.animationPlayer = animationPlayer
        self.preferences = preferences

        setupStateObservation()
    }

    deinit {
        watchdogTimer?.invalidate()
    }

    // MARK: - Public API

    /// Show or create the pet window. Safe to call multiple times.
    func show() {
        guard preferences.isEnabled else {
            petLogger.debug("show() ignored — pet disabled")
            return
        }

        showGeneration += 1
        let gen = showGeneration

        if petPanel == nil {
            createPanel()
        }
        guard let panel = petPanel else { return }

        panel.alphaValue = 0
        panel.orderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 1.0
        }

        petLogger.debug("show() — generation \(gen)")
    }

    /// Hide the pet window with a fade animation.
    func hide() {
        let gen = showGeneration
        guard let panel = petPanel else { return }

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, self.showGeneration == gen else { return }
            self.petPanel?.orderOut(nil)
        })
    }

    /// Close and release the panel entirely.
    func close() {
        stopWatchdog()
        hide()
        petPanel?.close()
        petPanel = nil
    }

    /// Start the 5-second watchdog timer.
    func startWatchdog() {
        guard preferences.isEnabled else { return }
        stopWatchdog()
        watchdogTimer = Timer.scheduledTimer(
            withTimeInterval: Self.watchdogInterval,
            repeats: true
        ) { [weak self] _ in
            self?.watchdogCheck()
        }
        if let timer = watchdogTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        petLogger.debug("Watchdog started")
    }

    func stopWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
        watchdogRecreateCount = 0
    }

    /// Reload the pet panel after a preference change (e.g., pet selection, enable toggle).
    func reload() {
        close()
        if preferences.isEnabled {
            show()
            startWatchdog()
        }
    }

    // MARK: - NSPanel Creation

    private func createPanel() {
        let position = resolveInitialPosition()

        let panel = NSPanel(
            contentRect: NSRect(x: position.x, y: position.y,
                                width: Self.petWidth, height: Self.petHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .mainMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = false
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.canHide = false
        panel.animationBehavior = .none

        // Build the SwiftUI content view
        let petView = PetView(
            animationPlayer: animationPlayer,
            stateMachine: stateMachine
        )
        let hostingView = NSHostingView(rootView: petView)
        hostingView.frame = NSRect(x: 0, y: 0, width: Self.petWidth, height: Self.petHeight)
        hostingView.autoresizingMask = [.width, .height]

        // Attach interaction handler (creates its own overlay view with tracking area)
        let handler = PetInteractionHandler()
        handler.attach(to: hostingView, frame: hostingView.bounds, screen: panel.screen)
        interactionHandler = handler

        // Wire interaction callbacks
        handler.onClick = { [weak self] in
            guard let self else { return }
            self.stateMachine.firstInteraction()
            self.onOpenNotchPanel?()
        }
        handler.onDragMoved = { [weak self] position, direction in
            guard let self, let panel = self.petPanel else { return }
            if let dir = direction {
                let dragDir: PetStateMachine.DragDirection = (dir == .draggingLeft) ? .left : .right
                self.stateMachine.dragStart(direction: dragDir)
            }
            panel.setFrameOrigin(position)
        }
        handler.onDragEnded = { [weak self] position in
            guard let self else { return }
            self.stateMachine.dragEnd()
            self.preferences.positionX = position.x
            self.preferences.positionY = position.y
            petLogger.debug("Position saved: (\(position.x), \(position.y))")
        }
        handler.onHidePet = { [weak self] in
            self?.onHidePet?()
        }
        handler.onSwitchPet = { [weak self] petID in
            self?.onSwitchPet?(petID)
        }

        panel.contentView = hostingView
        petPanel = panel
        petLogger.debug("Panel created at (\(position.x), \(position.y))")
    }

    // MARK: - Position Management

    private func resolveInitialPosition() -> CGPoint {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let screenFrame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        return preferences.resolvedPosition(fallbackScreenFrame: screenFrame)
    }

    // MARK: - State Observation

    private func setupStateObservation() {
        stateMachine.$currentState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.handleStateChange(newState)
            }
            .store(in: &cancellables)
    }

    private func handleStateChange(_ state: PetState) {
        guard preferences.isEnabled else { return }

        let petID = preferences.selectedPet
        guard let gifURL = resolveGIFURL(for: state, petID: petID) else {
            petLogger.warning("No GIF found for state \(state.label), pet \(petID)")
            return
        }

        animationPlayer.loadAnimation(from: gifURL)
        petLogger.debug("State → animation: \(state.label) → \(gifURL.lastPathComponent)")
    }

    /// Resolve a PetState + petID to a GIF file URL.
    /// Validates petID against a whitelist to prevent path traversal.
    private func resolveGIFURL(for state: PetState, petID: String) -> URL? {
        // Security: whitelist petID to prevent path traversal (code review + security review finding)
        guard petID.range(of: #"^[a-zA-Z0-9_-]+$"#, options: .regularExpression) != nil else {
            petLogger.error("Invalid petID '\(petID)' — rejected for path safety")
            return nil
        }

        let fileName = "\(state.animationFileName).gif"
        let subpath = "Pets/\(petID)/\(fileName)"

        // Primary: app bundle Resources
        if let bundleURL = Bundle.main.resourceURL?.appendingPathComponent(subpath),
           FileManager.default.fileExists(atPath: bundleURL.path) {
            return bundleURL
        }

        // Fallback: development path next to the built binary
        if let execURL = Bundle.main.executableURL?
            .deletingLastPathComponent()
            .appendingPathComponent(subpath),
           FileManager.default.fileExists(atPath: execURL.path) {
            return execURL
        }

#if DEBUG
        // Development fallback: project root Resources (stripped from release builds)
        let devPath = "/Users/\(NSUserName())/projects/ccprojects/NotchBlock/NotchBlock/Resources/\(subpath)"
        if FileManager.default.fileExists(atPath: devPath) {
            return URL(fileURLWithPath: devPath)
        }
#endif

        return nil
    }

    // MARK: - Watchdog

    private func watchdogCheck() {
        if petPanel != nil {
            watchdogRecreateCount = 0
            return
        }

        guard preferences.isEnabled else {
            watchdogRecreateCount = 0
            return
        }

        watchdogRecreateCount += 1

        if watchdogRecreateCount > Self.maxWatchdogRecreates {
            stopWatchdog()
            petLogger.error("Watchdog: exceeded \(Self.maxWatchdogRecreates) consecutive recreates — stopped")
            return
        }

        petLogger.warning("Watchdog: pet window missing (attempt \(self.watchdogRecreateCount)/\(Self.maxWatchdogRecreates)) — recreating")
        createPanel()
        show()
    }
}
