import Foundation
import Combine
import OSLog

private let logger = Logger(subsystem: "com.notchblock.app", category: "PetState")

/// Nine-state FSM that drives the desktop pet's animation state.
///
/// Observes `TimeBlockStore.$blocks` via Combine and applies a priority chain:
/// dragging > failed > succeeded > focusing > sleeping > idleMicro > idle > initial.
///
/// `succeeded`/`failed` states auto-timeout after 60s, then re-evaluate
/// (→ `.idle` if no active block, → `.focusing` if a block is active).
///
/// Drag states (`draggingLeft`/`draggingRight`) are set via `dragStart(direction:)`
/// and cleared via `dragEnd()`. They interrupt every other state.
///
/// When `PetPreferences.isEnabled` is false, the state machine is a no-op.
@MainActor
final class PetStateMachine: ObservableObject {
    @Published var currentState: PetState = .initial

    // MARK: - Dependencies

    private let store: TimeBlockStore
    private let preferences: PetPreferences

    // MARK: - Timer (60s for succeeded/failed)

    private var timeoutTimer: Timer?

    // MARK: - Internal State Tracking

    /// The state to restore after a drag operation ends.
    private var previousState: PetState = .idle

    /// Whether the user has performed the first interaction with the pet.
    private var isFirstInteractionDone = false

    /// Tracks the last-known status of each block ID so we can detect
    /// pending→completed and pending→missed transitions.
    private var previouslyKnownStatuses: [UUID: BlockStatus] = [:]

    // MARK: - Combine

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Drag Direction

    enum DragDirection {
        case left
        case right
    }

    // MARK: - Init

    init(store: TimeBlockStore, preferences: PetPreferences = PetPreferences()) {
        self.store = store
        self.preferences = preferences
        observeStore()
    }

    // MARK: - Public API

    /// Call when the user first interacts with the pet (click, hover, etc.).
    /// Transitions from `.initial` → `.idle`.
    func firstInteraction() {
        guard preferences.isEnabled else { return }
        guard currentState == .initial else { return }
        currentState = .idle
        isFirstInteractionDone = true
        logger.info("First interaction: initial → idle")
    }

    /// Begin a drag operation. Saves the current state for later restoration.
    func dragStart(direction: DragDirection) {
        guard preferences.isEnabled else { return }
        previousState = currentState
        let newState: PetState = direction == .left ? .draggingLeft : .draggingRight
        currentState = newState
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        logger.debug("Drag start: \(self.previousState.label) → \(newState.label)")
    }

    /// End a drag operation. Re-evaluates the state based on current blocks.
    func dragEnd() {
        guard preferences.isEnabled else { return }
        evaluateState(store.blocks)
        logger.debug("Drag end: → \(self.currentState.label)")
    }

    // MARK: - Compute Next State (pure function)

    /// Computes the next state the pet should transition to.
    ///
    /// This is a `static` pure function so it can be tested in isolation.
    /// The instance wraps it with Combine subscriptions and timer management.
    ///
    /// - Parameters:
    ///   - currentState: The pet's current state.
    ///   - blocks: Current time blocks from the store.
    ///   - previouslyKnownStatuses: The last-known status for each block ID.
    ///   - isFirstInteractionDone: Whether the user has performed the first interaction.
    ///   - timeoutElapsed: Whether the 60s succeeded/failed timeout has elapsed.
    /// - Returns: The state the pet should be in.
    static func computeNextState(
        currentState: PetState,
        blocks: [TimeBlock],
        previouslyKnownStatuses: [UUID: BlockStatus],
        isFirstInteractionDone: Bool,
        timeoutElapsed: Bool = false
    ) -> PetState {
        // Drag states are externally managed — no automatic transition out of them
        if currentState == .draggingLeft || currentState == .draggingRight {
            return currentState
        }

        // Succeeded/failed persist for 60s (managed by timer in the instance).
        // Only exit when the timer fires (timeoutElapsed == true).
        if !timeoutElapsed && (currentState == .succeeded || currentState == .failed) {
            return currentState
        }

        // Check for status transitions.
        // Priority-independent scan: failed beats succeeded regardless of array order.
        if blocks.contains(where: { block in
            previouslyKnownStatuses[block.id] == .pending && block.status == .missed
        }) {
            return .failed
        }
        if blocks.contains(where: { block in
            previouslyKnownStatuses[block.id] == .pending && block.status == .completed
        }) {
            return .succeeded
        }

        // Active block → focusing
        if blocks.contains(where: { $0.isActiveNow }) {
            return .focusing
        }

        // Not yet interacted → initial (lowest priority)
        if !isFirstInteractionDone {
            return .initial
        }

        // Default idle
        return .idle
    }

    // MARK: - Private: Store Observation

    private func observeStore() {
        store.$blocks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] blocks in
                self?.evaluateState(blocks)
            }
            .store(in: &cancellables)
    }

    // MARK: - Private: State Evaluation

    private func evaluateState(_ blocks: [TimeBlock]) {
        guard preferences.isEnabled else { return }

        let nextState = Self.computeNextState(
            currentState: currentState,
            blocks: blocks,
            previouslyKnownStatuses: previouslyKnownStatuses,
            isFirstInteractionDone: isFirstInteractionDone
        )

        transition(to: nextState)

        // Update tracking AFTER transition so the same change isn't re-detected
        updateKnownStatuses(from: blocks)
    }

    private func updateKnownStatuses(from blocks: [TimeBlock]) {
        var updated = previouslyKnownStatuses
        for block in blocks {
            updated[block.id] = block.status
        }
        previouslyKnownStatuses = updated
    }

    // MARK: - Private: Transition + Timer

    private func transition(to state: PetState) {
        guard state != currentState else { return }

        timeoutTimer?.invalidate()
        timeoutTimer = nil

        currentState = state
        logger.debug("Transition: → \(state.label)")

        if state == .succeeded || state == .failed {
            startTimeout()
        }
    }

    /// Start a 60-second timer. On expiry, re-evaluate state
    /// with `timeoutElapsed: true` to force exit from succeeded/failed.
    private func startTimeout() {
        timeoutTimer?.invalidate()
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.handleTimeout()
            }
        }
    }

    private func handleTimeout() {
        timeoutTimer = nil
        logger.debug("Timeout elapsed, re-evaluating state")
        let nextState = Self.computeNextState(
            currentState: currentState,
            blocks: store.blocks,
            previouslyKnownStatuses: previouslyKnownStatuses,
            isFirstInteractionDone: isFirstInteractionDone,
            timeoutElapsed: true
        )
        transition(to: nextState)
        updateKnownStatuses(from: store.blocks)
    }
}
