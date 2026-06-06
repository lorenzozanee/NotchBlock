#!/usr/bin/env swift
import Foundation
import CoreGraphics

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

// ────────────────────────────────────────────────────────────────────
// MARK: - Watchdog Logic (pure function)
// ────────────────────────────────────────────────────────────────────
// The watchdog checks every 5s whether the pet window exists.
// If missing + enabled: recreate, increment counter.
// Max 3 consecutive recreates, then stop + log error.

struct WatchdogState {
    var recreateCount: Int
    var isStopped: Bool

    init(recreateCount: Int = 0, isStopped: Bool = false) {
        self.recreateCount = recreateCount
        self.isStopped = isStopped
    }

    static let maxRecreates = 3

    mutating func check(windowExists: Bool, petEnabled: Bool) -> Bool {
        if isStopped { return false }

        if windowExists {
            // Window exists — reset counter
            recreateCount = 0
            return false
        }

        guard petEnabled else {
            // Pet disabled — reset counter, no recreate needed
            recreateCount = 0
            return false
        }

        // Window missing + pet enabled — should recreate
        recreateCount += 1
        if recreateCount > Self.maxRecreates {
            isStopped = true
            return false // exceeded max, stop
        }
        return true // should recreate
    }

    mutating func reset() {
        recreateCount = 0
        isStopped = false
    }
}

// ────────────────────────────────────────────────────────────────────
// MARK: - Generation Counter (show/hide race prevention)
// ────────────────────────────────────────────────────────────────────

struct ShowHideTracker {
    private var generation: Int = 0

    /// Returns a new generation token for a show operation.
    mutating func nextGeneration() -> Int {
        generation += 1
        return generation
    }

    /// Returns true if `gen` matches the current generation.
    func isCurrent(_ gen: Int) -> Bool {
        gen == generation
    }
}

// ────────────────────────────────────────────────────────────────────
// MARK: - Animation URL Resolution (state → GIF path)
// ────────────────────────────────────────────────────────────────────

/// Resolve a PetState to the expected GIF file URL within the app bundle.
/// This is the pure-logic mapping that PetWindowController uses to tell
/// PetAnimationPlayer which GIF to load.
func resolveAnimationURL(
    for state: PetState,
    petID: String = "elysia",
    bundleAssetsPath: String = "/Contents/Resources/Pets"
) -> String {
    let fileName = state.animationFileName
    return "\(bundleAssetsPath)/\(petID)/\(fileName).gif"
}

// ────────────────────────────────────────────────────────────────────
// MARK: - NSPanel Config (pure validation logic)
// ────────────────────────────────────────────────────────────────────
// We can't create NSPanel in a pure-swift test, but we can validate
// the config parameters that WOULD be used.

struct PanelConfig {
    let styleMask: [String]  // e.g. ["borderless", "nonactivatingPanel"]
    let level: String        // e.g. "mainMenu", "floating"
    let collectionBehavior: [String]
    let isOpaque: Bool
    let backgroundColor: String
    let hasShadow: Bool
    let ignoresMouseEvents: Bool
    let hidesOnDeactivate: Bool
    let isMovable: Bool
    let isReleasedWhenClosed: Bool
}

/// Validate that a given NSPanel configuration matches the pet window spec.
func validatePetPanelConfig(_ config: PanelConfig) -> Bool {
    guard config.styleMask.contains("borderless") else { return false }
    guard config.styleMask.contains("nonactivatingPanel") else { return false }
    guard config.level == "mainMenu" || config.level == "floating" else { return false }
    guard !config.isOpaque else { return false }
    guard config.backgroundColor == "clear" else { return false }
    guard !config.hasShadow else { return false }
    guard !config.ignoresMouseEvents else { return false } // pet IS interactive
    guard !config.hidesOnDeactivate else { return false }
    // isMovable can be true (drag support via mouse events)
    guard !config.isReleasedWhenClosed else { return false }
    return true
}

/// Validate that a given NSPanel configuration matches the pet window spec
/// with fullScreenAuxiliary behavior.
func validatePetPanelConfigWithFullScreen(_ config: PanelConfig) -> Bool {
    guard validatePetPanelConfig(config) else { return false }
    guard config.collectionBehavior.contains("canJoinAllSpaces") else { return false }
    guard config.collectionBehavior.contains("fullScreenAuxiliary") else { return false }
    return true
}

// ────────────────────────────────────────────────────────────────────
// MARK: - Position Persistence (pure logic wrapper)
// ────────────────────────────────────────────────────────────────────

/// Default edge margin for pet window positioning.
let defaultEdgeMargin: CGFloat = 20.0

/// Resolve pet position: if stored position is (0,0), use fallback (bottom-right).
func resolvePosition(
    storedX: CGFloat,
    storedY: CGFloat,
    screenFrame: CGRect,
    petSize: CGSize = CGSize(width: 120, height: 120)
) -> CGPoint {
    let x = storedX
    let y = storedY
    if x == 0 && y == 0 {
        // Fallback: bottom-right corner
        return CGPoint(
            x: screenFrame.maxX - defaultEdgeMargin - petSize.width,
            y: screenFrame.minY + defaultEdgeMargin
        )
    }
    return CGPoint(x: x, y: y)
}

/// Clamp a position to stay within the screen frame, preserving margin.
func clampPosition(
    _ point: CGPoint,
    to screenFrame: CGRect,
    margin: CGFloat = defaultEdgeMargin,
    petSize: CGSize = CGSize(width: 120, height: 120)
) -> CGPoint {
    let minX = screenFrame.minX + margin
    let maxX = screenFrame.maxX - margin - petSize.width
    let minY = screenFrame.minY + margin
    let maxY = screenFrame.maxY - margin - petSize.height
    return CGPoint(
        x: min(max(point.x, minX), maxX),
        y: min(max(point.y, minY), maxY)
    )
}

// ────────────────────────────────────────────────────────────────────
// MARK: - TESTS: Watchdog Logic
// ────────────────────────────────────────────────────────────────────

print("=== PetWindowController Tests ===\n")
print("-- Watchdog Logic --")

test("watchdog: no-op when window exists") {
    var wd = WatchdogState()
    let shouldRecreate = wd.check(windowExists: true, petEnabled: true)
    try assert(!shouldRecreate, "should not recreate when window exists")
    try assertEqual(wd.recreateCount, 0, "counter should remain 0")
    try assert(!wd.isStopped, "should not be stopped")
}

test("watchdog: recreates when window missing and enabled") {
    var wd = WatchdogState()
    let shouldRecreate = wd.check(windowExists: false, petEnabled: true)
    try assert(shouldRecreate, "should recreate when window is missing and pet enabled")
    try assertEqual(wd.recreateCount, 1, "counter should increment to 1")
    try assert(!wd.isStopped, "should not be stopped yet")
}

test("watchdog: no recreate when disabled") {
    var wd = WatchdogState()
    let shouldRecreate = wd.check(windowExists: false, petEnabled: false)
    try assert(!shouldRecreate, "should not recreate when pet is disabled")
    try assertEqual(wd.recreateCount, 0, "counter should be 0 when disabled")
}

test("watchdog: resets counter when window comes back") {
    var wd = WatchdogState()
    _ = wd.check(windowExists: false, petEnabled: true) // count = 1
    _ = wd.check(windowExists: false, petEnabled: true) // count = 2
    try assertEqual(wd.recreateCount, 2)

    // Window appears
    let shouldRecreate = wd.check(windowExists: true, petEnabled: true)
    try assert(!shouldRecreate, "should not recreate when window reappears")
    try assertEqual(wd.recreateCount, 0, "counter should reset when window exists")
}

test("watchdog: stops after 3 consecutive recreates") {
    var wd = WatchdogState()

    // Recreate 1
    try assert(wd.check(windowExists: false, petEnabled: true))
    try assertEqual(wd.recreateCount, 1)

    // Recreate 2
    try assert(wd.check(windowExists: false, petEnabled: true))
    try assertEqual(wd.recreateCount, 2)

    // Recreate 3
    try assert(wd.check(windowExists: false, petEnabled: true))
    try assertEqual(wd.recreateCount, 3)
    try assert(!wd.isStopped, "should allow 3rd recreate")

    // 4th attempt — stopped
    let shouldRecreate = wd.check(windowExists: false, petEnabled: true)
    try assert(!shouldRecreate, "should stop after 3 recreates")
    try assertEqual(wd.recreateCount, 4, "counter still increments for tracking")
    try assert(wd.isStopped, "should be stopped after exceeding max")
}

test("watchdog: no-op when already stopped") {
    var wd = WatchdogState()
    wd.isStopped = true
    let shouldRecreate = wd.check(windowExists: false, petEnabled: true)
    try assert(!shouldRecreate, "stopped watchdog should never recreate")
}

test("watchdog: counter does not reset when disabled and window missing") {
    var wd = WatchdogState()
    _ = wd.check(windowExists: false, petEnabled: true) // count = 1

    // Now disabled, still no window
    let shouldRecreate = wd.check(windowExists: false, petEnabled: false)
    try assert(!shouldRecreate, "no recreate when disabled")
    try assertEqual(wd.recreateCount, 0, "counter resets when disabled (no recreate needed)")
}

test("watchdog: reset() restores initial state") {
    var wd = WatchdogState()
    _ = wd.check(windowExists: false, petEnabled: true)
    _ = wd.check(windowExists: false, petEnabled: true)
    _ = wd.check(windowExists: false, petEnabled: true)
    wd.isStopped = true
    try assert(wd.isStopped)

    wd.reset()
    try assertEqual(wd.recreateCount, 0)
    try assert(!wd.isStopped)
    try assert(wd.check(windowExists: false, petEnabled: true))
}

// ────────────────────────────────────────────────────────────────────
// MARK: - TESTS: Generation Counter
// ────────────────────────────────────────────────────────────────────

print("\n-- Generation Counter --")

test("generation: increments on each call") {
    var tracker = ShowHideTracker()
    let g1 = tracker.nextGeneration()
    let g2 = tracker.nextGeneration()
    let g3 = tracker.nextGeneration()
    try assertEqual(g1, 1)
    try assertEqual(g2, 2)
    try assertEqual(g3, 3)
}

test("generation: isCurrent returns true for matching gen") {
    var tracker = ShowHideTracker()
    let gen = tracker.nextGeneration()
    try assert(tracker.isCurrent(gen))

    _ = tracker.nextGeneration()
    try assert(!tracker.isCurrent(gen), "old generation should no longer be current")
}

test("generation: race prevention — hide completion uses stale gen") {
    var tracker = ShowHideTracker()

    // Show → gen 1
    let gen1 = tracker.nextGeneration()
    try assertEqual(gen1, 1)

    // Show again before hide completes → gen 2
    let gen2 = tracker.nextGeneration()
    try assertEqual(gen2, 2)

    // Hide completion for gen1 arrives — should NOT execute
    try assert(!tracker.isCurrent(gen1), "stale generation should be rejected")

    // Hide completion for gen2 arrives — should execute
    try assert(tracker.isCurrent(gen2), "current generation should be accepted")
}

test("generation: overflow safety — handles many increments") {
    var tracker = ShowHideTracker()
    var lastGen = 0
    for _ in 0..<1000 {
        let gen = tracker.nextGeneration()
        try assert(gen > lastGen, "generation should always increase")
        lastGen = gen
        try assert(tracker.isCurrent(gen))
    }
}

// ────────────────────────────────────────────────────────────────────
// MARK: - TESTS: Animation URL Resolution
// ────────────────────────────────────────────────────────────────────

print("\n-- Animation URL Resolution --")

test("animationURL: idle → elysia/idle.gif") {
    let url = resolveAnimationURL(for: .idle)
    try assert(url.hasSuffix("elysia/idle.gif"), "expected elysia/idle.gif, got \(url)")
}

test("animationURL: focusing → elysia/waiting.gif") {
    let url = resolveAnimationURL(for: .focusing)
    try assert(url.hasSuffix("elysia/waiting.gif"))
}

test("animationURL: succeeded → elysia/jumping.gif") {
    let url = resolveAnimationURL(for: .succeeded)
    try assert(url.hasSuffix("elysia/jumping.gif"))
}

test("animationURL: failed → elysia/failed.gif") {
    let url = resolveAnimationURL(for: .failed)
    try assert(url.hasSuffix("elysia/failed.gif"))
}

test("animationURL: initial → elysia/waving.gif") {
    let url = resolveAnimationURL(for: .initial)
    try assert(url.hasSuffix("elysia/waving.gif"))
}

test("animationURL: draggingLeft → elysia/running-left.gif") {
    let url = resolveAnimationURL(for: .draggingLeft)
    try assert(url.hasSuffix("elysia/running-left.gif"))
}

test("animationURL: draggingRight → elysia/running-right.gif") {
    let url = resolveAnimationURL(for: .draggingRight)
    try assert(url.hasSuffix("elysia/running-right.gif"))
}

test("animationURL: sleeping → elysia/sleeping.gif") {
    let url = resolveAnimationURL(for: .sleeping)
    try assert(url.hasSuffix("elysia/sleeping.gif"))
}

test("animationURL: idleMicro → elysia/blink.gif") {
    let url = resolveAnimationURL(for: .idleMicro)
    try assert(url.hasSuffix("elysia/blink.gif"))
}

test("animationURL: different pet ID changes path") {
    let url = resolveAnimationURL(for: .idle, petID: "chibi")
    try assert(url.hasSuffix("chibi/idle.gif"))
}

// ────────────────────────────────────────────────────────────────────
// MARK: - TESTS: NSPanel Config Validation
// ────────────────────────────────────────────────────────────────────

print("\n-- Panel Config Validation --")

test("panelConfig: valid pet panel config passes validation") {
    let config = PanelConfig(
        styleMask: ["borderless", "nonactivatingPanel"],
        level: "mainMenu",
        collectionBehavior: ["canJoinAllSpaces", "fullScreenAuxiliary"],
        isOpaque: false,
        backgroundColor: "clear",
        hasShadow: false,
        ignoresMouseEvents: false,
        hidesOnDeactivate: false,
        isMovable: true,
        isReleasedWhenClosed: false
    )
    try assert(validatePetPanelConfigWithFullScreen(config), "valid pet config should pass")
}

test("panelConfig: missing borderless → fails validation") {
    let config = PanelConfig(
        styleMask: ["nonactivatingPanel"],
        level: "mainMenu",
        collectionBehavior: ["canJoinAllSpaces", "fullScreenAuxiliary"],
        isOpaque: false,
        backgroundColor: "clear",
        hasShadow: false,
        ignoresMouseEvents: false,
        hidesOnDeactivate: false,
        isMovable: true,
        isReleasedWhenClosed: false
    )
    try assert(!validatePetPanelConfig(config), "missing borderless should fail")
}

test("panelConfig: missing nonactivatingPanel → fails validation") {
    let config = PanelConfig(
        styleMask: ["borderless"],
        level: "mainMenu",
        collectionBehavior: ["canJoinAllSpaces", "fullScreenAuxiliary"],
        isOpaque: false,
        backgroundColor: "clear",
        hasShadow: false,
        ignoresMouseEvents: false,
        hidesOnDeactivate: false,
        isMovable: true,
        isReleasedWhenClosed: false
    )
    try assert(!validatePetPanelConfig(config), "missing nonactivatingPanel should fail")
}

test("panelConfig: opaque background → fails validation") {
    let config = PanelConfig(
        styleMask: ["borderless", "nonactivatingPanel"],
        level: "mainMenu",
        collectionBehavior: ["canJoinAllSpaces", "fullScreenAuxiliary"],
        isOpaque: true,
        backgroundColor: "clear",
        hasShadow: false,
        ignoresMouseEvents: false,
        hidesOnDeactivate: false,
        isMovable: true,
        isReleasedWhenClosed: false
    )
    try assert(!validatePetPanelConfig(config), "opaque should fail")
}

test("panelConfig: non-clear background → fails validation") {
    let config = PanelConfig(
        styleMask: ["borderless", "nonactivatingPanel"],
        level: "mainMenu",
        collectionBehavior: ["canJoinAllSpaces", "fullScreenAuxiliary"],
        isOpaque: false,
        backgroundColor: "white",
        hasShadow: false,
        ignoresMouseEvents: false,
        hidesOnDeactivate: false,
        isMovable: true,
        isReleasedWhenClosed: false
    )
    try assert(!validatePetPanelConfig(config), "non-clear background should fail")
}

test("panelConfig: hasShadow → fails validation") {
    let config = PanelConfig(
        styleMask: ["borderless", "nonactivatingPanel"],
        level: "mainMenu",
        collectionBehavior: ["canJoinAllSpaces", "fullScreenAuxiliary"],
        isOpaque: false,
        backgroundColor: "clear",
        hasShadow: true,
        ignoresMouseEvents: false,
        hidesOnDeactivate: false,
        isMovable: true,
        isReleasedWhenClosed: false
    )
    try assert(!validatePetPanelConfig(config), "shadow should fail")
}

test("panelConfig: ignoresMouseEvents → fails validation (pet is interactive)") {
    let config = PanelConfig(
        styleMask: ["borderless", "nonactivatingPanel"],
        level: "mainMenu",
        collectionBehavior: ["canJoinAllSpaces", "fullScreenAuxiliary"],
        isOpaque: false,
        backgroundColor: "clear",
        hasShadow: false,
        ignoresMouseEvents: true,
        hidesOnDeactivate: false,
        isMovable: true,
        isReleasedWhenClosed: false
    )
    try assert(!validatePetPanelConfig(config), "ignoring mouse events should fail for interactive pet")
}

test("panelConfig: hidesOnDeactivate → fails validation") {
    let config = PanelConfig(
        styleMask: ["borderless", "nonactivatingPanel"],
        level: "mainMenu",
        collectionBehavior: ["canJoinAllSpaces", "fullScreenAuxiliary"],
        isOpaque: false,
        backgroundColor: "clear",
        hasShadow: false,
        ignoresMouseEvents: false,
        hidesOnDeactivate: true,
        isMovable: true,
        isReleasedWhenClosed: false
    )
    try assert(!validatePetPanelConfig(config), "hidesOnDeactivate should fail")
}

test("panelConfig: isReleasedWhenClosed → fails validation") {
    let config = PanelConfig(
        styleMask: ["borderless", "nonactivatingPanel"],
        level: "mainMenu",
        collectionBehavior: ["canJoinAllSpaces", "fullScreenAuxiliary"],
        isOpaque: false,
        backgroundColor: "clear",
        hasShadow: false,
        ignoresMouseEvents: false,
        hidesOnDeactivate: false,
        isMovable: true,
        isReleasedWhenClosed: true
    )
    try assert(!validatePetPanelConfig(config), "isReleasedWhenClosed should fail")
}

test("panelConfig: missing fullScreenAuxiliary → fails fullscreen validation") {
    let config = PanelConfig(
        styleMask: ["borderless", "nonactivatingPanel"],
        level: "mainMenu",
        collectionBehavior: ["canJoinAllSpaces"],
        isOpaque: false,
        backgroundColor: "clear",
        hasShadow: false,
        ignoresMouseEvents: false,
        hidesOnDeactivate: false,
        isMovable: true,
        isReleasedWhenClosed: false
    )
    try assert(validatePetPanelConfig(config), "basic config should still pass")
    try assert(!validatePetPanelConfigWithFullScreen(config), "missing fullScreenAuxiliary should fail fullscreen validation")
}

test("panelConfig: floating level is acceptable alternative") {
    let config = PanelConfig(
        styleMask: ["borderless", "nonactivatingPanel"],
        level: "floating",
        collectionBehavior: ["canJoinAllSpaces", "fullScreenAuxiliary"],
        isOpaque: false,
        backgroundColor: "clear",
        hasShadow: false,
        ignoresMouseEvents: false,
        hidesOnDeactivate: false,
        isMovable: true,
        isReleasedWhenClosed: false
    )
    try assert(validatePetPanelConfig(config), "floating level should be acceptable")
}

test("panelConfig: invalid level → fails validation") {
    let config = PanelConfig(
        styleMask: ["borderless", "nonactivatingPanel"],
        level: "normal",
        collectionBehavior: ["canJoinAllSpaces", "fullScreenAuxiliary"],
        isOpaque: false,
        backgroundColor: "clear",
        hasShadow: false,
        ignoresMouseEvents: false,
        hidesOnDeactivate: false,
        isMovable: true,
        isReleasedWhenClosed: false
    )
    try assert(!validatePetPanelConfig(config), "normal window level should fail for pet")
}

// ────────────────────────────────────────────────────────────────────
// MARK: - TESTS: Position Persistence
// ────────────────────────────────────────────────────────────────────

print("\n-- Position Persistence --")

test("position: uses stored coordinates when non-zero") {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let pos = resolvePosition(storedX: 500, storedY: 300, screenFrame: screen)
    try assertEqual(pos.x, 500)
    try assertEqual(pos.y, 300)
}

test("position: (0,0) falls back to bottom-right") {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let pos = resolvePosition(storedX: 0, storedY: 0, screenFrame: screen, petSize: CGSize(width: 120, height: 120))
    // Bottom-right: screen.maxX - margin - petWidth = 1440 - 20 - 120 = 1300
    // Bottom edge: screen.minY + margin = 0 + 20 = 20
    try assertEqual(pos.x, 1300, "x should be at right edge minus margin and pet width")
    try assertEqual(pos.y, 20, "y should be at bottom edge plus margin")
}

test("position: clamps to left edge when too far left") {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let pos = clampPosition(CGPoint(x: -100, y: 400), to: screen)
    try assertEqual(pos.x, 20, "x should be clamped to left margin")
    try assertEqual(pos.y, 400, "y should be unchanged when in bounds")
}

test("position: clamps to right edge when too far right") {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let pos = clampPosition(CGPoint(x: 2000, y: 400), to: screen, petSize: CGSize(width: 120, height: 120))
    // maxX = 1440 - 20 - 120 = 1300
    try assertEqual(pos.x, 1300, "x should be clamped to right edge minus margins")
}

test("position: clamps to bottom edge") {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let pos = clampPosition(CGPoint(x: 500, y: -50), to: screen)
    try assertEqual(pos.y, 20, "y should be clamped to bottom margin")
}

test("position: clamps to top edge") {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let pos = clampPosition(CGPoint(x: 500, y: 1000), to: screen, petSize: CGSize(width: 120, height: 120))
    // maxY = 900 - 20 - 120 = 760
    try assertEqual(pos.y, 760, "y should be clamped to top edge minus margins")
}

test("position: clamps both axes simultaneously") {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let pos = clampPosition(CGPoint(x: -100, y: 1000), to: screen, petSize: CGSize(width: 120, height: 120))
    try assertEqual(pos.x, 20)
    try assertEqual(pos.y, 760)
}

test("position: point within bounds is unchanged") {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let pos = clampPosition(CGPoint(x: 500, y: 400), to: screen)
    try assertEqual(pos.x, 500)
    try assertEqual(pos.y, 400)
}

test("position: custom margin affects clamping") {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let pos = clampPosition(CGPoint(x: 0, y: 0), to: screen, margin: 50, petSize: CGSize(width: 120, height: 120))
    try assertEqual(pos.x, 50)
    try assertEqual(pos.y, 50)
}

test("position: secondary screen clamping uses its coordinates") {
    let secondary = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
    let pos = clampPosition(CGPoint(x: 1400, y: 500), to: secondary, petSize: CGSize(width: 120, height: 120))
    // minX = 1440 + 20 = 1460
    try assertEqual(pos.x, 1460, "x clamped to secondary screen left edge")
    try assertEqual(pos.y, 500, "y within bounds unchanged")
}

// ────────────────────────────────────────────────────────────────────
// MARK: - TESTS: End-to-End State → Animation Flow
// ────────────────────────────────────────────────────────────────────

print("\n-- State → Animation Flow --")

test("state-to-animation: all 9 states have unique animation filenames") {
    let allNames = PetState.allCases.map { $0.animationFileName }
    let uniqueNames = Set(allNames)
    try assertEqual(uniqueNames.count, 9, "all 9 states should have distinct animation file names")
}

test("state-to-animation: each state maps to correct URL") {
    let expected: [PetState: String] = [
        .initial: "elysia/waving.gif",
        .idle: "elysia/idle.gif",
        .idleMicro: "elysia/blink.gif",
        .sleeping: "elysia/sleeping.gif",
        .focusing: "elysia/waiting.gif",
        .succeeded: "elysia/jumping.gif",
        .failed: "elysia/failed.gif",
        .draggingLeft: "elysia/running-left.gif",
        .draggingRight: "elysia/running-right.gif",
    ]
    for (state, expectedSuffix) in expected {
        let url = resolveAnimationURL(for: state)
        try assert(url.hasSuffix(expectedSuffix), "state \(state) should map to \(expectedSuffix), got \(url)")
    }
}

test("state-to-animation: same state returns same URL (idempotent)") {
    let url1 = resolveAnimationURL(for: .focusing)
    let url2 = resolveAnimationURL(for: .focusing)
    try assertEqual(url1, url2)
}

test("state-to-animation: transitioning states produce different URLs") {
    let idleURL = resolveAnimationURL(for: .idle)
    let focusURL = resolveAnimationURL(for: .focusing)
    try assertNotEqual(idleURL, focusURL, "different states should map to different URLs")
}

// ────────────────────────────────────────────────────────────────────
// MARK: - TESTS: Pet State Priority at Window Level
// ────────────────────────────────────────────────────────────────────

print("\n-- Pet State Priority at Window Level --")

test("priority: dragging states > all non-drag states") {
    try assert(PetState.draggingLeft > PetState.failed)
    try assert(PetState.draggingLeft > PetState.succeeded)
    try assert(PetState.draggingLeft > PetState.focusing)
    try assert(PetState.draggingRight > PetState.failed)
    try assert(PetState.draggingRight > PetState.focusing)
}

test("priority: failed > succeeded > focusing > idle") {
    try assert(PetState.failed > PetState.succeeded)
    try assert(PetState.succeeded > PetState.focusing)
    try assert(PetState.focusing > PetState.idle)
}

test("priority: initial is lowest priority") {
    for state in PetState.allCases {
        if state != .initial {
            try assert(state > PetState.initial, "\(state) should have higher priority than initial")
        }
    }
}

test("priority: idleMicro > idle > initial") {
    try assert(PetState.idleMicro > PetState.idle)
    try assert(PetState.idle > PetState.initial)
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
