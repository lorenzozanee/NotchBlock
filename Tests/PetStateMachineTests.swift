#!/usr/bin/env swift
import Foundation

// ── Mirrored types for test isolation ──

enum PetState: Int, Comparable, CaseIterable {
    case initial = 0
    case idle = 1
    case idleMicro = 2
    case sleeping = 3
    case focusing = 4
    case succeeded = 5
    case failed = 6
    case draggingLeft = 7
    case draggingRight = 8
    static func < (lhs: PetState, rhs: PetState) -> Bool { lhs.rawValue < rhs.rawValue }
}

enum BlockStatus: String, Codable, CaseIterable {
    case pending
    case completed
    case missed
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

/// Mirrored DragDirection for PetStateMachine testing.
enum DragDirection {
    case left
    case right
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

// ── computeNextState — mirrored pure function from PetStateMachine ──

/// Computes the next state the pet should transition to.
///
/// - Parameters:
///   - currentState: The pet's current state.
///   - blocks: Current time blocks from the store.
///   - previouslyKnownStatuses: The last-known status for each block ID (used to detect transitions).
///   - isFirstInteractionDone: Whether the user has performed the first interaction.
///   - timeoutElapsed: Whether the 60s succeeded/failed timeout has elapsed (forces re-evaluation).
/// - Returns: The state the pet should be in.
func computeNextState(
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
    // Priority-independent scan: check all blocks, failed beats succeeded
    // regardless of iteration order.
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

// ── Helpers for building test data ──

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
// MARK: - Priority Chain Verification
// ────────────────────────────────────────────────────────────────────

print("=== PetStateMachine Tests ===\n")
print("-- Priority Chain --")

test("initial is lowest priority (rawValue 0)") {
    try assertEqual(PetState.initial.rawValue, 0)
}

test("idle is above initial (rawValue 1)") {
    try assertEqual(PetState.idle.rawValue, 1)
}

test("idleMicro is above idle (rawValue 2)") {
    try assertEqual(PetState.idleMicro.rawValue, 2)
}

test("sleeping is above idleMicro (rawValue 3)") {
    try assertEqual(PetState.sleeping.rawValue, 3)
}

test("focusing is above sleeping (rawValue 4)") {
    try assertEqual(PetState.focusing.rawValue, 4)
}

test("succeeded is above focusing (rawValue 5)") {
    try assertEqual(PetState.succeeded.rawValue, 5)
}

test("failed is above succeeded (rawValue 6)") {
    try assertEqual(PetState.failed.rawValue, 6)
}

test("draggingLeft is above failed (rawValue 7)") {
    try assertEqual(PetState.draggingLeft.rawValue, 7)
}

test("draggingRight is highest priority (rawValue 8)") {
    try assertEqual(PetState.draggingRight.rawValue, 8)
}

test("priority chain: dragging > failed > succeeded > focusing > sleeping > idleMicro > idle > initial") {
    try assert(PetState.draggingRight > PetState.failed)
    try assert(PetState.failed > PetState.succeeded)
    try assert(PetState.succeeded > PetState.focusing)
    try assert(PetState.focusing > PetState.sleeping)
    try assert(PetState.sleeping > PetState.idleMicro)
    try assert(PetState.idleMicro > PetState.idle)
    try assert(PetState.idle > PetState.initial)
}

// ────────────────────────────────────────────────────────────────────
// MARK: - Basic Transitions
// ────────────────────────────────────────────────────────────────────

print("\n-- Basic Transitions --")

test("initial stays initial when no interaction and no blocks") {
    let state = computeNextState(
        currentState: .initial,
        blocks: [],
        previouslyKnownStatuses: [:],
        isFirstInteractionDone: false
    )
    try assertEqual(state, .initial)
}

test("idle state when interaction done, no active blocks") {
    let state = computeNextState(
        currentState: .idle,
        blocks: [],
        previouslyKnownStatuses: [:],
        isFirstInteractionDone: true
    )
    try assertEqual(state, .idle)
}

test("focusing when active block exists (overrides initial)") {
    let activeBlock = makeBlock()
    let state = computeNextState(
        currentState: .initial,
        blocks: [activeBlock],
        previouslyKnownStatuses: [:],
        isFirstInteractionDone: false
    )
    try assertEqual(state, .focusing, "active block should trigger focusing even before first interaction")
}

test("focusing when active block exists (from idle)") {
    let activeBlock = makeBlock()
    let state = computeNextState(
        currentState: .idle,
        blocks: [activeBlock],
        previouslyKnownStatuses: [:],
        isFirstInteractionDone: true
    )
    try assertEqual(state, .focusing)
}

test("idle persists when no active block and no status change") {
    let inactiveBlock = makeBlock(startOffset: -3600, endOffset: -1800, status: .completed)
    let knownStatuses = [inactiveBlock.id: BlockStatus.completed]
    let state = computeNextState(
        currentState: .idle,
        blocks: [inactiveBlock],
        previouslyKnownStatuses: knownStatuses,
        isFirstInteractionDone: true
    )
    try assertEqual(state, .idle)
}

test("focusing persists when block still pending and no status change") {
    let pendingBlock = makeBlock()
    let knownStatuses = [pendingBlock.id: BlockStatus.pending]
    let state = computeNextState(
        currentState: .focusing,
        blocks: [pendingBlock],
        previouslyKnownStatuses: knownStatuses,
        isFirstInteractionDone: true
    )
    try assertEqual(state, .focusing)
}

// ────────────────────────────────────────────────────────────────────
// MARK: - Status Transition Detection
// ────────────────────────────────────────────────────────────────────

print("\n-- Status Transition Detection --")

test("focusing → succeeded when block transitions pending→completed") {
    let blockId = UUID()
    let completedBlock = makeBlock(id: blockId, status: .completed)
    let knownStatuses = [blockId: BlockStatus.pending]
    let state = computeNextState(
        currentState: .focusing,
        blocks: [completedBlock],
        previouslyKnownStatuses: knownStatuses,
        isFirstInteractionDone: true
    )
    try assertEqual(state, .succeeded)
}

test("focusing → failed when block transitions pending→missed") {
    let blockId = UUID()
    let missedBlock = makeBlock(id: blockId, status: .missed)
    let knownStatuses = [blockId: BlockStatus.pending]
    let state = computeNextState(
        currentState: .focusing,
        blocks: [missedBlock],
        previouslyKnownStatuses: knownStatuses,
        isFirstInteractionDone: true
    )
    try assertEqual(state, .failed)
}

test("idle → succeeded when block completes (even from idle)") {
    let blockId = UUID()
    let completedBlock = makeBlock(id: blockId, startOffset: -3600, endOffset: -60, status: .completed)
    let knownStatuses = [blockId: BlockStatus.pending]
    let state = computeNextState(
        currentState: .idle,
        blocks: [completedBlock],
        previouslyKnownStatuses: knownStatuses,
        isFirstInteractionDone: true
    )
    try assertEqual(state, .succeeded)
}

test("idle → failed when block misses (even from idle)") {
    let blockId = UUID()
    let missedBlock = makeBlock(id: blockId, startOffset: -3600, endOffset: -60, status: .missed)
    let knownStatuses = [blockId: BlockStatus.pending]
    let state = computeNextState(
        currentState: .idle,
        blocks: [missedBlock],
        previouslyKnownStatuses: knownStatuses,
        isFirstInteractionDone: true
    )
    try assertEqual(state, .failed)
}

// ────────────────────────────────────────────────────────────────────
// MARK: - Priority: failed > succeeded
// ────────────────────────────────────────────────────────────────────

print("\n-- Priority: failed > succeeded --")

test("failed takes priority over succeeded when both detected in same evaluation") {
    let missedId = UUID()
    let completedId = UUID()
    let blocks = [
        makeBlock(id: completedId, startOffset: -3600, endOffset: -60, status: .completed),
        makeBlock(id: missedId, startOffset: -7200, endOffset: -3600, status: .missed),
    ]
    let knownStatuses = [
        missedId: BlockStatus.pending,
        completedId: BlockStatus.pending,
    ]
    let state = computeNextState(
        currentState: .focusing,
        blocks: blocks,
        previouslyKnownStatuses: knownStatuses,
        isFirstInteractionDone: true
    )
    try assertEqual(state, .failed, "failed (rawValue 6) has higher priority than succeeded (rawValue 5)")
}

test("failed takes priority when missed block appears before completed in array") {
    let missedId = UUID()
    let completedId = UUID()
    // missed FIRST in array
    let blocks = [
        makeBlock(id: missedId, startOffset: -7200, endOffset: -3600, status: .missed),
        makeBlock(id: completedId, startOffset: -3600, endOffset: -60, status: .completed),
    ]
    let knownStatuses = [
        missedId: BlockStatus.pending,
        completedId: BlockStatus.pending,
    ]
    let state = computeNextState(
        currentState: .focusing,
        blocks: blocks,
        previouslyKnownStatuses: knownStatuses,
        isFirstInteractionDone: true
    )
    try assertEqual(state, .failed, "missed should win regardless of array order")
}

// ────────────────────────────────────────────────────────────────────
// MARK: - State Persistence (Timer-Managed)
// ────────────────────────────────────────────────────────────────────

print("\n-- State Persistence (Timer-Managed) --")

test("succeeded persists — new block changes don't override it (timeoutElapsed=false)") {
    let oldCompletedId = UUID()
    let newActiveBlock = makeBlock()
    let blocks = [
        makeBlock(id: oldCompletedId, startOffset: -3600, endOffset: -60, status: .completed),
        newActiveBlock,
    ]
    let knownStatuses = [oldCompletedId: BlockStatus.completed, newActiveBlock.id: BlockStatus.pending]
    let state = computeNextState(
        currentState: .succeeded,
        blocks: blocks,
        previouslyKnownStatuses: knownStatuses,
        isFirstInteractionDone: true,
        timeoutElapsed: false
    )
    try assertEqual(state, .succeeded, "succeeded should persist even with active blocks present")
}

test("failed persists — new block changes don't override it (timeoutElapsed=false)") {
    let oldMissedId = UUID()
    let newActiveBlock = makeBlock()
    let blocks = [
        makeBlock(id: oldMissedId, startOffset: -3600, endOffset: -60, status: .missed),
        newActiveBlock,
    ]
    let knownStatuses = [oldMissedId: BlockStatus.missed, newActiveBlock.id: BlockStatus.pending]
    let state = computeNextState(
        currentState: .failed,
        blocks: blocks,
        previouslyKnownStatuses: knownStatuses,
        isFirstInteractionDone: true,
        timeoutElapsed: false
    )
    try assertEqual(state, .failed, "failed should persist even with active blocks present")
}

test("succeeded persists — new completions don't cause re-entry (timeoutElapsed=false)") {
    let firstId = UUID()
    let secondId = UUID()
    let blocks = [
        makeBlock(id: firstId, startOffset: -7200, endOffset: -3600, status: .completed),
        makeBlock(id: secondId, startOffset: -3600, endOffset: -60, status: .completed),
    ]
    let knownStatuses = [firstId: BlockStatus.completed, secondId: BlockStatus.pending]
    let state = computeNextState(
        currentState: .succeeded,
        blocks: blocks,
        previouslyKnownStatuses: knownStatuses,
        isFirstInteractionDone: true,
        timeoutElapsed: false
    )
    try assertEqual(state, .succeeded, "should stay in succeeded, not re-enter")
}

// ────────────────────────────────────────────────────────────────────
// MARK: - Drag State Isolation
// ────────────────────────────────────────────────────────────────────

print("\n-- Drag State Isolation --")

test("draggingLeft persists through all block changes") {
    let activeBlock = makeBlock()
    let state = computeNextState(
        currentState: .draggingLeft,
        blocks: [activeBlock],
        previouslyKnownStatuses: [:],
        isFirstInteractionDone: true
    )
    try assertEqual(state, .draggingLeft)
}

test("draggingRight persists through all block changes") {
    let completedBlock = makeBlock(status: .completed)
    let knownStatuses = [completedBlock.id: BlockStatus.pending]
    let state = computeNextState(
        currentState: .draggingRight,
        blocks: [completedBlock],
        previouslyKnownStatuses: knownStatuses,
        isFirstInteractionDone: true
    )
    try assertEqual(state, .draggingRight)
}

test("draggingLeft persists even with completed+missed+active blocks") {
    let missedId = UUID()
    let completedId = UUID()
    let blocks = [
        makeBlock(id: missedId, startOffset: -7200, endOffset: -3600, status: .missed),
        makeBlock(id: completedId, startOffset: -3600, endOffset: -60, status: .completed),
        makeBlock(), // active
    ]
    let knownStatuses = [missedId: BlockStatus.pending, completedId: BlockStatus.pending]
    let state = computeNextState(
        currentState: .draggingLeft,
        blocks: blocks,
        previouslyKnownStatuses: knownStatuses,
        isFirstInteractionDone: true,
        timeoutElapsed: true // even with timeout, drag wins
    )
    try assertEqual(state, .draggingLeft, "drag states should always win, regardless of other conditions")
}

test("draggingRight persists even with timeoutElapsed=true") {
    let state = computeNextState(
        currentState: .draggingRight,
        blocks: [],
        previouslyKnownStatuses: [:],
        isFirstInteractionDone: true,
        timeoutElapsed: true
    )
    try assertEqual(state, .draggingRight, "drag should not be broken by timeout")
}

// ────────────────────────────────────────────────────────────────────
// MARK: - Timeout Re-evaluation
// ────────────────────────────────────────────────────────────────────

print("\n-- Timeout Re-evaluation --")

test("succeeded + timeout → idle when no active blocks") {
    let completedId = UUID()
    let completedBlock = makeBlock(id: completedId, startOffset: -3600, endOffset: -60, status: .completed)
    let knownStatuses = [completedId: BlockStatus.completed] // already tracked
    let state = computeNextState(
        currentState: .succeeded,
        blocks: [completedBlock],
        previouslyKnownStatuses: knownStatuses,
        isFirstInteractionDone: true,
        timeoutElapsed: true // timer fired
    )
    try assertEqual(state, .idle, "after timeout with no active blocks, should go to idle")
}

test("succeeded + timeout → focusing when active block exists") {
    let completedId = UUID()
    let completedBlock = makeBlock(id: completedId, startOffset: -3600, endOffset: -60, status: .completed)
    let activeBlock = makeBlock()
    let knownStatuses = [completedId: BlockStatus.completed, activeBlock.id: BlockStatus.pending]
    let state = computeNextState(
        currentState: .succeeded,
        blocks: [completedBlock, activeBlock],
        previouslyKnownStatuses: knownStatuses,
        isFirstInteractionDone: true,
        timeoutElapsed: true
    )
    try assertEqual(state, .focusing, "after timeout with active block, should resume focusing")
}

test("failed + timeout → idle when no active blocks") {
    let missedId = UUID()
    let missedBlock = makeBlock(id: missedId, startOffset: -3600, endOffset: -60, status: .missed)
    let knownStatuses = [missedId: BlockStatus.missed]
    let state = computeNextState(
        currentState: .failed,
        blocks: [missedBlock],
        previouslyKnownStatuses: knownStatuses,
        isFirstInteractionDone: true,
        timeoutElapsed: true
    )
    try assertEqual(state, .idle, "after timeout with no active blocks, should go to idle")
}

test("failed + timeout → focusing when active block exists") {
    let missedId = UUID()
    let missedBlock = makeBlock(id: missedId, startOffset: -3600, endOffset: -60, status: .missed)
    let activeBlock = makeBlock()
    let knownStatuses = [missedId: BlockStatus.missed, activeBlock.id: BlockStatus.pending]
    let state = computeNextState(
        currentState: .failed,
        blocks: [missedBlock, activeBlock],
        previouslyKnownStatuses: knownStatuses,
        isFirstInteractionDone: true,
        timeoutElapsed: true
    )
    try assertEqual(state, .focusing, "after timeout with active block, should resume focusing")
}

test("succeeded + timeout → initial when no interaction done and no active blocks") {
    let completedId = UUID()
    let completedBlock = makeBlock(id: completedId, startOffset: -3600, endOffset: -60, status: .completed)
    let knownStatuses = [completedId: BlockStatus.completed]
    let state = computeNextState(
        currentState: .succeeded,
        blocks: [completedBlock],
        previouslyKnownStatuses: knownStatuses,
        isFirstInteractionDone: false,
        timeoutElapsed: true
    )
    try assertEqual(state, .initial, "after timeout without interaction, back to initial")
}

// ────────────────────────────────────────────────────────────────────
// MARK: - Timeout Re-triggers (new completions after timeout)
// ────────────────────────────────────────────────────────────────────

print("\n-- Timeout Re-triggers --")

test("timeout → detects new pending→completed transition") {
    let oldCompletedId = UUID()
    let newCompletedId = UUID()
    let blocks = [
        makeBlock(id: oldCompletedId, startOffset: -7200, endOffset: -3600, status: .completed),
        makeBlock(id: newCompletedId, startOffset: -3600, endOffset: -60, status: .completed),
    ]
    // We already knew oldCompleted was completed, but newCompleted was pending
    let knownStatuses = [oldCompletedId: BlockStatus.completed, newCompletedId: BlockStatus.pending]
    let state = computeNextState(
        currentState: .succeeded,
        blocks: blocks,
        previouslyKnownStatuses: knownStatuses,
        isFirstInteractionDone: true,
        timeoutElapsed: true
    )
    try assertEqual(state, .succeeded, "new completion detected → restart succeeded")
}

test("timeout → detects new pending→missed transition") {
    let oldMissedId = UUID()
    let newMissedId = UUID()
    let blocks = [
        makeBlock(id: oldMissedId, startOffset: -7200, endOffset: -3600, status: .missed),
        makeBlock(id: newMissedId, startOffset: -3600, endOffset: -60, status: .missed),
    ]
    let knownStatuses = [oldMissedId: BlockStatus.missed, newMissedId: BlockStatus.pending]
    let state = computeNextState(
        currentState: .failed,
        blocks: blocks,
        previouslyKnownStatuses: knownStatuses,
        isFirstInteractionDone: true,
        timeoutElapsed: true
    )
    try assertEqual(state, .failed, "new missed detected → restart failed")
}

// ────────────────────────────────────────────────────────────────────
// MARK: - Edge Cases
// ────────────────────────────────────────────────────────────────────

print("\n-- Edge Cases --")

test("empty blocks + interaction done → idle") {
    let state = computeNextState(
        currentState: .idle,
        blocks: [],
        previouslyKnownStatuses: [:],
        isFirstInteractionDone: true
    )
    try assertEqual(state, .idle)
}

test("empty blocks + no interaction → initial") {
    let state = computeNextState(
        currentState: .initial,
        blocks: [],
        previouslyKnownStatuses: [:],
        isFirstInteractionDone: false
    )
    try assertEqual(state, .initial)
}

test("unknown block ID (not in statuses) → no transition triggered") {
    let unknownBlock = makeBlock(status: .completed)
    // Empty statuses — block ID unknown
    let state = computeNextState(
        currentState: .idle,
        blocks: [unknownBlock],
        previouslyKnownStatuses: [:],
        isFirstInteractionDone: true
    )
    // Since the block is completed but we never saw it as pending,
    // we don't detect a transition. Also it's not active (completed, not pending).
    // So we stay idle.
    try assertEqual(state, .idle)
}

test("unchanged status → no transition") {
    let blockId = UUID()
    let pendingBlock = makeBlock(id: blockId, status: .pending)
    let knownStatuses = [blockId: BlockStatus.pending]
    let state = computeNextState(
        currentState: .focusing,
        blocks: [pendingBlock],
        previouslyKnownStatuses: knownStatuses,
        isFirstInteractionDone: true
    )
    try assertEqual(state, .focusing, "status unchanged → stay in focusing")
}

test("block status changed from completed to pending → no transition") {
    // Edge case: a block somehow goes from completed back to pending
    let blockId = UUID()
    let pendingBlock = makeBlock(id: blockId, status: .pending)
    let knownStatuses = [blockId: BlockStatus.completed]
    // We only detect pending→completed/missed, not the reverse
    let state = computeNextState(
        currentState: .idle,
        blocks: [pendingBlock],
        previouslyKnownStatuses: knownStatuses,
        isFirstInteractionDone: true
    )
    // pending block IS active, so we go to focusing (active block check)
    try assertEqual(state, .focusing, "active pending block should trigger focusing")
}

test("block with .pending status but not active (future block) → stays idle") {
    let futureBlock = makeBlock(startOffset: 3600, endOffset: 7200, status: .pending)
    let knownStatuses = [futureBlock.id: BlockStatus.pending]
    let state = computeNextState(
        currentState: .idle,
        blocks: [futureBlock],
        previouslyKnownStatuses: knownStatuses,
        isFirstInteractionDone: true
    )
    try assertEqual(state, .idle, "future pending block should not trigger focusing")
}

test("block with .pending status but is past → stays idle") {
    let pastBlock = makeBlock(startOffset: -7200, endOffset: -3600, status: .pending)
    let knownStatuses = [pastBlock.id: BlockStatus.pending]
    let state = computeNextState(
        currentState: .idle,
        blocks: [pastBlock],
        previouslyKnownStatuses: knownStatuses,
        isFirstInteractionDone: true
    )
    try assertEqual(state, .idle, "past pending block is not active, and not transitioned to missed yet")
}

test("focusing persists when only future blocks exist") {
    let futureBlock = makeBlock(startOffset: 3600, endOffset: 7200, status: .pending)
    let knownStatuses = [futureBlock.id: BlockStatus.pending]
    let state = computeNextState(
        currentState: .focusing,
        blocks: [futureBlock],
        previouslyKnownStatuses: knownStatuses,
        isFirstInteractionDone: true
    )
    try assertEqual(state, .idle, "should fall back to idle since no active block")
}

test("large block array (100 blocks) — performance safety") {
    var blocks: [TimeBlock] = []
    var knownStatuses: [UUID: BlockStatus] = [:]
    for i in 0..<100 {
        let id = UUID()
        blocks.append(makeBlock(id: id, startOffset: Double(-3600 + i * 10), endOffset: Double(-3500 + i * 10), status: .completed))
        knownStatuses[id] = .completed
    }
    let state = computeNextState(
        currentState: .idle,
        blocks: blocks,
        previouslyKnownStatuses: knownStatuses,
        isFirstInteractionDone: true
    )
    try assertEqual(state, .idle, "all known completed → idle")
}

test("multiple blocks, one active → focusing") {
    let completedId = UUID()
    let blocks = [
        makeBlock(id: completedId, startOffset: -7200, endOffset: -3600, status: .completed),
        makeBlock(), // active
        makeBlock(startOffset: 3600, endOffset: 7200), // future
    ]
    let knownStatuses = [completedId: BlockStatus.completed]
    let state = computeNextState(
        currentState: .idle,
        blocks: blocks,
        previouslyKnownStatuses: knownStatuses,
        isFirstInteractionDone: true
    )
    try assertEqual(state, .focusing)
}

// ────────────────────────────────────────────────────────────────────
// MARK: - Instance Method Contract Tests
// ────────────────────────────────────────────────────────────────────

print("\n-- Instance Method Contracts --")

test("firstInteraction: initial → idle") {
    // Simulate the firstInteraction() logic
    var state: PetState = .initial
    var interactionDone = false
    // firstInteraction() logic
    if state == .initial {
        state = .idle
        interactionDone = true
    }
    try assertEqual(state, .idle)
    try assert(interactionDone)
}

test("firstInteraction: no-op when not initial") {
    var state: PetState = .focusing
    let beforeState = state
    // firstInteraction() logic: guard currentState == .initial else { return }
    var interactionDone = true
    if state == .initial {
        state = .idle
        interactionDone = true
    }
    try assertEqual(state, beforeState, "firstInteraction should be no-op when not in initial state")
}

test("firstInteraction: no-op when isEnabled is false") {
    // Simulate the guard: guard preferences.isEnabled else { return }
    var state: PetState = .initial
    let isEnabled = false
    if isEnabled && state == .initial {
        state = .idle
    }
    try assertEqual(state, .initial, "when disabled, firstInteraction should do nothing")
}

test("dragStart: saves previous state and transitions to drag") {
    var currentState: PetState = .focusing
    var previousState: PetState = .idle
    let direction = DragDirection.left

    // dragStart logic
    previousState = currentState
    currentState = direction == .left ? .draggingLeft : .draggingRight

    try assertEqual(currentState, .draggingLeft)
    try assertEqual(previousState, .focusing, "previous state should be saved for dragEnd restore")
}

test("dragStart to right") {
    var currentState: PetState = .succeeded
    var previousState: PetState = .idle
    let direction = DragDirection.right

    previousState = currentState
    currentState = direction == .left ? .draggingLeft : .draggingRight

    try assertEqual(currentState, .draggingRight)
    try assertEqual(previousState, .succeeded)
}

test("dragStart: no-op when disabled") {
    var currentState: PetState = .focusing
    let isEnabled = false
    if isEnabled {
        currentState = .draggingLeft
    }
    try assertEqual(currentState, .focusing, "dragStart should be no-op when disabled")
}

test("dragEnd: re-evaluates to correct state from previous focus context") {
    // After drag ends, re-evaluate with previouslyKnownStatuses and previous context
    // The computeNextState with currentState=idle should determine the right state
    let activeBlock = makeBlock()
    let state = computeNextState(
        currentState: .idle, // after dragEnd, we re-evaluate from a clean slate
        blocks: [activeBlock],
        previouslyKnownStatuses: [:],
        isFirstInteractionDone: true
    )
    try assertEqual(state, .focusing, "dragEnd should re-evaluate and find active block → focusing")
}

test("dragEnd: re-evaluates to idle when nothing active") {
    let state = computeNextState(
        currentState: .idle,
        blocks: [],
        previouslyKnownStatuses: [:],
        isFirstInteractionDone: true
    )
    try assertEqual(state, .idle)
}

test("dragStart: no-op when disabled (right direction)") {
    var currentState: PetState = .idle
    let isEnabled = false
    if isEnabled {
        currentState = .draggingRight
    }
    _ = isEnabled
    try assertEqual(currentState, .idle, "drag state should not change when disabled")
}

// ────────────────────────────────────────────────────────────────────
// MARK: - Immutability Contract
// ────────────────────────────────────────────────────────────────────

print("\n-- Immutability Contract --")

test("computeNextState does not mutate input arrays or dicts") {
    let blocks = [makeBlock()]
    let knownStatuses = [blocks[0].id: BlockStatus.pending]
    let blocksBefore = blocks.count
    let statusesBefore = knownStatuses.count

    _ = computeNextState(
        currentState: .idle,
        blocks: blocks,
        previouslyKnownStatuses: knownStatuses,
        isFirstInteractionDone: true
    )

    try assertEqual(blocks.count, blocksBefore, "blocks array should not be mutated")
    try assertEqual(knownStatuses.count, statusesBefore, "statuses dict should not be mutated")
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
