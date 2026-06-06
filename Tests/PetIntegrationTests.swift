#!/usr/bin/env swift
import Foundation

// ── Mirrored types for test isolation ──

enum PetState: Int, Comparable, CaseIterable {
    case initial = 0, idle = 1, idleMicro = 2, sleeping = 3, focusing = 4
    case succeeded = 5, failed = 6, draggingLeft = 7, draggingRight = 8
    static func < (lhs: PetState, rhs: PetState) -> Bool { lhs.rawValue < rhs.rawValue }
    var animationFileName: String {
        switch self {
        case .initial: return "waving"
        case .idle: return "idle"
        case .idleMicro: return "blink"
        case .sleeping: return "sleeping"
        case .focusing: return "waiting"
        case .succeeded: return "jumping"
        case .failed: return "failed"
        case .draggingLeft: return "running-left"
        case .draggingRight: return "running-right"
        }
    }
}

enum BlockStatus: String, Codable, CaseIterable {
    case pending, completed, missed
}

struct TimeBlock {
    let id: UUID
    var title: String
    var startTime: Date
    var endTime: Date
    var status: BlockStatus
    var notes: String
    var isBreak: Bool

    init(id: UUID = UUID(), title: String = "", startTime: Date, endTime: Date,
         status: BlockStatus = .pending, notes: String = "", isBreak: Bool = false) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.status = status
        self.notes = notes
        self.isBreak = isBreak
    }

    var isActiveNow: Bool {
        let now = Date()
        return now >= startTime && now <= endTime && status == .pending
    }
}

// ── Test infrastructure ──

var passed = 0, failed = 0
func test(_ name: String, _ block: () throws -> Void) {
    do { try block(); passed += 1; print("  ✅ \(name)") }
    catch { failed += 1; print("  ❌ \(name): \(error)") }
}

func assert(_ condition: Bool, _ msg: String = "") throws {
    guard condition else { throw TestError.assertionFailed(msg) }
}

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String = "") throws {
    guard a == b else { throw TestError.assertionFailed("expected \(b), got \(a)\(msg.isEmpty ? "" : " — \(msg)")") }
}

func assertNotEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String = "") throws {
    guard a != b else { throw TestError.assertionFailed("expected not \(b), got \(a)\(msg.isEmpty ? "" : " — \(msg)")") }
}

enum TestError: Error, CustomStringConvertible {
    case assertionFailed(String)
    var description: String {
        switch self {
        case .assertionFailed(let msg): return msg.isEmpty ? "assertion failed" : msg
        }
    }
}

let now = Date()

func makeBlock(
    id: UUID = UUID(),
    startOffset: TimeInterval = -600,
    endOffset: TimeInterval = 600,
    status: BlockStatus = .pending
) -> TimeBlock {
    TimeBlock(
        id: id,
        title: "Test",
        startTime: now.addingTimeInterval(startOffset),
        endTime: now.addingTimeInterval(endOffset),
        status: status
    )
}

// ────────────────────────────────────────────────────────────────────
// MARK: - Pure Logic: computeNextState (mirrored from PetStateMachine)
// ────────────────────────────────────────────────────────────────────

func computeNextState(
    currentState: PetState,
    blocks: [TimeBlock],
    previouslyKnownStatuses: [UUID: BlockStatus],
    isFirstInteractionDone: Bool,
    timeoutElapsed: Bool = false
) -> PetState {
    if currentState == .draggingLeft || currentState == .draggingRight {
        return currentState
    }
    if !timeoutElapsed && (currentState == .succeeded || currentState == .failed) {
        return currentState
    }
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
    if blocks.contains(where: { $0.isActiveNow }) {
        return .focusing
    }
    if !isFirstInteractionDone {
        return .initial
    }
    return .idle
}

// ────────────────────────────────────────────────────────────────────
// MARK: - Animation File Resolution
// ────────────────────────────────────────────────────────────────────

func resolveAnimationURL(for state: PetState, petID: String = "elysia") -> String {
    let fileName = state.animationFileName
    return "Pets/\(petID)/\(fileName).gif"
}

// ────────────────────────────────────────────────────────────────────
// MARK: - Simulated Integration: Store Change → State → Animation
// ────────────────────────────────────────────────────────────────────
// This simulates the full chain without AppKit dependencies.
// TimeBlockStore publishes block changes → PetStateMachine computes new state
// → PetWindowController resolves animation URL → PetAnimationPlayer loads GIF.

struct IntegrationSimulator {
    private var blocks: [TimeBlock] = []
    private var knownStatuses: [UUID: BlockStatus] = [:]
    private var currentState: PetState = .initial
    private var isFirstInteractionDone: Bool = false
    private var timeoutElapsed: Bool = false
    private var timerActive: Bool = false
    private var petID: String = "elysia"

    // MARK: - Store simulation

    mutating func addBlock(_ block: TimeBlock) {
        blocks.append(block)
        knownStatuses[block.id] = block.status
        evaluate()
    }

    mutating func updateBlockStatus(_ id: UUID, to status: BlockStatus) {
        updateBlockStatusWithoutEvaluate(id, to: status)
        evaluate()
    }

    /// Update block status without triggering state evaluation (useful for batching).
    private mutating func updateBlockStatusWithoutEvaluate(_ id: UUID, to status: BlockStatus) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        var updated = blocks
        updated[index].status = status
        blocks = updated
    }

    /// Update multiple block statuses and evaluate once (avoids race where
    /// an intermediate evaluation sees only the first change).
    mutating func updateBlockStatuses(_ changes: [(UUID, BlockStatus)]) {
        for (id, status) in changes {
            updateBlockStatusWithoutEvaluate(id, to: status)
        }
        evaluate()
    }

    mutating func setBlocks(_ newBlocks: [TimeBlock]) {
        blocks = newBlocks
        for b in newBlocks {
            if knownStatuses[b.id] == nil {
                knownStatuses[b.id] = b.status
            }
        }
        evaluate()
    }

    // MARK: - Interaction simulation

    mutating func performFirstInteraction() {
        guard currentState == .initial else { return }
        currentState = .idle
        isFirstInteractionDone = true
    }

    mutating func startDrag(direction: PetState) {
        guard direction == .draggingLeft || direction == .draggingRight else { return }
        currentState = direction
    }

    mutating func endDrag() {
        // Drag states are trapped by computeNextState — temporarily clear
        // to a neutral state so evaluate() can compute the correct next state.
        if currentState == .draggingLeft || currentState == .draggingRight {
            currentState = .idle
        }
        evaluate()
    }

    mutating func triggerTimeout() {
        timeoutElapsed = true
        evaluate()
        timeoutElapsed = false
    }

    // MARK: - Internal evaluation

    private mutating func evaluate() {
        let nextState = computeNextState(
            currentState: currentState,
            blocks: blocks,
            previouslyKnownStatuses: knownStatuses,
            isFirstInteractionDone: isFirstInteractionDone,
            timeoutElapsed: timeoutElapsed
        )

        if nextState != currentState {
            currentState = nextState
            // Timer for succeeded/failed
            timerActive = (nextState == .succeeded || nextState == .failed)
        }

        // Update tracking
        for b in blocks {
            knownStatuses[b.id] = b.status
        }
    }

    // MARK: - Query

    var state: PetState { currentState }
    var animationURL: String { resolveAnimationURL(for: currentState, petID: petID) }
    var hasActiveTimer: Bool { timerActive }
    var interactionDone: Bool { isFirstInteractionDone }
}

// ────────────────────────────────────────────────────────────────────
// MARK: - TESTS: End-to-End Integration Flow
// ────────────────────────────────────────────────────────────────────

print("=== PetIntegrationTests ===\n")

print("-- Flow: Initial → First Interaction → Idle --")

test("integration: initial state maps to waving.gif") {
    var sim = IntegrationSimulator()
    try assertEqual(sim.state, .initial)
    try assert(sim.animationURL.hasSuffix("waving.gif"), "initial should map to waving.gif")
}

test("integration: first interaction transitions initial → idle") {
    var sim = IntegrationSimulator()
    sim.performFirstInteraction()
    try assertEqual(sim.state, .idle)
    try assert(sim.animationURL.hasSuffix("idle.gif"))
}

test("integration: first interaction marks interactionDone") {
    var sim = IntegrationSimulator()
    try assert(!sim.interactionDone)
    sim.performFirstInteraction()
    try assert(sim.interactionDone)
}

test("integration: first interaction is no-op when not in initial state") {
    var sim = IntegrationSimulator()
    // Start with an active block → focusing
    let block = makeBlock()
    sim.setBlocks([block])
    try assertEqual(sim.state, .focusing)

    // firstInteraction should be no-op (not in initial)
    sim.performFirstInteraction()
    try assertEqual(sim.state, .focusing, "should stay in focusing")
    try assert(!sim.interactionDone)
}

print("\n-- Flow: Active Block → Focusing Animation --")

test("integration: active block triggers focusing + waiting.gif") {
    var sim = IntegrationSimulator()
    sim.performFirstInteraction() // idle state
    let block = makeBlock()
    sim.setBlocks([block])
    try assertEqual(sim.state, .focusing)
    try assert(sim.animationURL.hasSuffix("waiting.gif"))
}

test("integration: no active blocks → idle + idle.gif") {
    var sim = IntegrationSimulator()
    sim.performFirstInteraction()
    sim.setBlocks([])
    try assertEqual(sim.state, .idle)
    try assert(sim.animationURL.hasSuffix("idle.gif"))
}

print("\n-- Flow: Block Completion → Succeeded Animation --")

test("integration: block completes → succeeded + jumping.gif") {
    var sim = IntegrationSimulator()
    sim.performFirstInteraction()

    let block = makeBlock()
    sim.setBlocks([block])
    try assertEqual(sim.state, .focusing)

    // User completes the block
    sim.updateBlockStatus(block.id, to: .completed)
    try assertEqual(sim.state, .succeeded)
    try assert(sim.animationURL.hasSuffix("jumping.gif"))
    try assert(sim.hasActiveTimer, "60s timer should be active for succeeded")
}

print("\n-- Flow: Block Miss → Failed Animation --")

test("integration: block missed → failed + failed.gif") {
    var sim = IntegrationSimulator()
    sim.performFirstInteraction()

    let block = makeBlock()
    sim.setBlocks([block])
    try assertEqual(sim.state, .focusing)

    sim.updateBlockStatus(block.id, to: .missed)
    try assertEqual(sim.state, .failed)
    try assert(sim.animationURL.hasSuffix("failed.gif"))
    try assert(sim.hasActiveTimer, "60s timer should be active for failed")
}

print("\n-- Flow: Succeeded/Failed Timeout Recovery --")

test("integration: succeeded + timeout → idle (no active blocks)") {
    var sim = IntegrationSimulator()
    sim.performFirstInteraction()

    let block = makeBlock()
    sim.setBlocks([block])
    sim.updateBlockStatus(block.id, to: .completed)
    try assertEqual(sim.state, .succeeded)

    // 60s passes → timeout
    sim.triggerTimeout()
    try assertEqual(sim.state, .idle)
    try assert(sim.animationURL.hasSuffix("idle.gif"))
}

test("integration: succeeded + timeout → focusing (active block exists)") {
    var sim = IntegrationSimulator()
    sim.performFirstInteraction()

    let completedBlock = makeBlock()
    let activeBlock = makeBlock()
    sim.setBlocks([completedBlock, activeBlock])
    sim.updateBlockStatus(completedBlock.id, to: .completed)
    try assertEqual(sim.state, .succeeded) // because completed was just detected

    sim.triggerTimeout()
    try assertEqual(sim.state, .focusing)
    try assert(sim.animationURL.hasSuffix("waiting.gif"))
}

test("integration: failed + timeout → idle (no active blocks)") {
    var sim = IntegrationSimulator()
    sim.performFirstInteraction()

    let block = makeBlock()
    sim.setBlocks([block])
    sim.updateBlockStatus(block.id, to: .missed)
    try assertEqual(sim.state, .failed)

    sim.triggerTimeout()
    try assertEqual(sim.state, .idle)
}

print("\n-- Flow: Drag Interrupts Any State --")

test("integration: drag overrides focusing") {
    var sim = IntegrationSimulator()
    sim.performFirstInteraction()

    let block = makeBlock()
    sim.setBlocks([block])
    try assertEqual(sim.state, .focusing)

    sim.startDrag(direction: .draggingLeft)
    try assertEqual(sim.state, .draggingLeft)
    try assert(sim.animationURL.hasSuffix("running-left.gif"))
}

test("integration: drag overrides succeeded") {
    var sim = IntegrationSimulator()
    sim.performFirstInteraction()

    let block = makeBlock()
    sim.setBlocks([block])
    sim.updateBlockStatus(block.id, to: .completed)
    try assertEqual(sim.state, .succeeded)

    sim.startDrag(direction: .draggingRight)
    try assertEqual(sim.state, .draggingRight)
    try assert(sim.animationURL.hasSuffix("running-right.gif"))
}

test("integration: drag overrides failed") {
    var sim = IntegrationSimulator()
    sim.performFirstInteraction()

    let block = makeBlock()
    sim.setBlocks([block])
    sim.updateBlockStatus(block.id, to: .missed)
    try assertEqual(sim.state, .failed)

    sim.startDrag(direction: .draggingLeft)
    try assertEqual(sim.state, .draggingLeft)
}

test("integration: drag end re-evaluates state") {
    var sim = IntegrationSimulator()
    sim.performFirstInteraction()

    let block = makeBlock()
    sim.setBlocks([block])
    try assertEqual(sim.state, .focusing)

    sim.startDrag(direction: .draggingRight)
    try assertEqual(sim.state, .draggingRight)

    sim.endDrag()
    try assertEqual(sim.state, .focusing, "after drag, should return to focusing since block is active")
}

test("integration: drag end returns to idle when nothing active") {
    var sim = IntegrationSimulator()
    sim.performFirstInteraction()
    try assertEqual(sim.state, .idle)

    sim.startDrag(direction: .draggingLeft)
    try assertEqual(sim.state, .draggingLeft)

    sim.endDrag()
    try assertEqual(sim.state, .idle)
}

print("\n-- Flow: Multiple Block Transitions --")

test("integration: two blocks, one completes, one still active → focusing after timeout") {
    var sim = IntegrationSimulator()
    sim.performFirstInteraction()

    let block1 = makeBlock()
    let block2 = makeBlock()
    sim.setBlocks([block1, block2])
    try assertEqual(sim.state, .focusing)

    // Block1 completes
    sim.updateBlockStatus(block1.id, to: .completed)
    try assertEqual(sim.state, .succeeded)

    // Timeout → re-evaluate; block2 is still active
    sim.triggerTimeout()
    try assertEqual(sim.state, .focusing, "should go back to focusing because block2 is active")
}

test("integration: failed takes priority over succeeded when both detected") {
    var sim = IntegrationSimulator()
    sim.performFirstInteraction()

    let block1 = makeBlock()
    let block2 = makeBlock()
    sim.setBlocks([block1, block2])
    try assertEqual(sim.state, .focusing)

    // Batch: both change at once within the same evaluation tick
    sim.updateBlockStatuses([(block1.id, .completed), (block2.id, .missed)])
    try assertEqual(sim.state, .failed, "failed should win over succeeded")
}

test("integration: only completed block with pending still active → focusing") {
    var sim = IntegrationSimulator()
    sim.performFirstInteraction()

    let completedBlock = makeBlock(startOffset: -3600, endOffset: -60, status: .completed)
    let activeBlock = makeBlock()
    // Note: completedBlock status is already .completed, not a transition
    sim.setBlocks([completedBlock, activeBlock])
    // Since completedBlock was never seen as pending, no transition to succeeded
    // But activeBlock IS active → focusing
    try assertEqual(sim.state, .focusing)
}

print("\n-- Flow: Animation URL Transitions --")

test("integration: animation URL changes when state changes") {
    var sim = IntegrationSimulator()
    let initialURL = sim.animationURL
    try assert(initialURL.hasSuffix("waving.gif"))

    sim.performFirstInteraction()
    let idleURL = sim.animationURL
    try assertNotEqual(initialURL, idleURL, "URL should change after state transition")
    try assert(idleURL.hasSuffix("idle.gif"))
}

test("integration: all state transitions produce valid animation URLs") {
    let validStates: Set<String> = [
        "waving.gif", "idle.gif", "blink.gif", "sleeping.gif",
        "waiting.gif", "jumping.gif", "failed.gif",
        "running-left.gif", "running-right.gif"
    ]
    for state in PetState.allCases {
        let url = resolveAnimationURL(for: state)
        let fileName = url.components(separatedBy: "/").last ?? ""
        try assert(validStates.contains(fileName), "unexpected animation file: \(fileName)")
    }
}

print("\n-- Flow: Full Lifecycle Simulation --")

test("integration: full lifecycle — initial → idle → focusing → succeeded → idle") {
    var sim = IntegrationSimulator()

    // 1. App starts, no blocks, no interaction
    try assertEqual(sim.state, .initial)

    // 2. User hovers/clicks pet
    sim.performFirstInteraction()
    try assertEqual(sim.state, .idle)

    // 3. User starts a focus block
    let block = makeBlock()
    sim.setBlocks([block])
    try assertEqual(sim.state, .focusing)
    try assert(sim.animationURL.hasSuffix("waiting.gif"))

    // 4. Block completes
    sim.updateBlockStatus(block.id, to: .completed)
    try assertEqual(sim.state, .succeeded)
    try assert(sim.animationURL.hasSuffix("jumping.gif"))

    // 5. 60s passes
    sim.triggerTimeout()
    try assertEqual(sim.state, .idle)
    try assert(sim.animationURL.hasSuffix("idle.gif"))
}

test("integration: full lifecycle with failure path") {
    var sim = IntegrationSimulator()

    sim.performFirstInteraction()
    try assertEqual(sim.state, .idle)

    let block = makeBlock()
    sim.setBlocks([block])
    try assertEqual(sim.state, .focusing)

    sim.updateBlockStatus(block.id, to: .missed)
    try assertEqual(sim.state, .failed)
    try assert(sim.animationURL.hasSuffix("failed.gif"))

    sim.triggerTimeout()
    try assertEqual(sim.state, .idle)
}

print("\n-- Edge Cases --")

test("integration: rapid block add/remove doesn't crash") {
    var sim = IntegrationSimulator()
    sim.performFirstInteraction()

    for i in 0..<50 {
        let block = makeBlock(startOffset: Double(i * 100), endOffset: Double(i * 100 + 600))
        sim.setBlocks([block])
    }
    // Should not crash
    try assert(sim.state == .focusing || sim.state == .idle)
}

test("integration: empty blocks with no interaction stays initial") {
    var sim = IntegrationSimulator()
    sim.setBlocks([])
    try assertEqual(sim.state, .initial)
    try assert(sim.animationURL.hasSuffix("waving.gif"))
}

test("integration: future pending blocks don't trigger focusing") {
    var sim = IntegrationSimulator()
    sim.performFirstInteraction()
    try assertEqual(sim.state, .idle)

    let futureBlock = makeBlock(startOffset: 3600, endOffset: 7200, status: .pending)
    sim.setBlocks([futureBlock])
    try assertEqual(sim.state, .idle, "future block should not trigger focusing")
}

test("integration: past pending blocks (not yet marked missed) stay idle") {
    var sim = IntegrationSimulator()
    sim.performFirstInteraction()
    try assertEqual(sim.state, .idle)

    let pastBlock = makeBlock(startOffset: -7200, endOffset: -3600, status: .pending)
    sim.setBlocks([pastBlock])
    try assertEqual(sim.state, .idle, "past pending block not active and not transitioned → idle")
}

// ── Summary ───────────────────────────────────────────────────────

print("\n\(passed)/\(passed + failed) tests passed")
if failed > 0 {
    print("❌ \(failed) test(s) FAILED")
    exit(1)
} else {
    print("✅ All tests passed!")
    exit(0)
}
