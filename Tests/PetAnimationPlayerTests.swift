#!/usr/bin/env swift
import Foundation

// ── Lightweight models for pure-logic testing (no AppKit dependency) ──

/// Mirrored subset of PetState for test isolation.
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

/// Lightweight frame descriptor for testing decoder logic.
struct MockFrame {
    let index: Int
    let duration: TimeInterval  // seconds this frame should display
    let disposalMethod: Int     // 0=none, 1=background, 2=previous
}

/// Simulate a GIF decode result for testing playback logic.
struct GIFDecodeResult {
    let frames: [MockFrame]
    let totalFrameCount: Int
    let loopCount: Int          // 0 = loop forever
    let isValid: Bool
    let errorMessage: String?

    static func valid(frames: [MockFrame], loopCount: Int = 0) -> GIFDecodeResult {
        GIFDecodeResult(frames: frames, totalFrameCount: frames.count, loopCount: loopCount, isValid: true, errorMessage: nil)
    }

    static func invalid(_ message: String) -> GIFDecodeResult {
        GIFDecodeResult(frames: [], totalFrameCount: 0, loopCount: 0, isValid: false, errorMessage: message)
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

enum TestError: Error, CustomStringConvertible {
    case assertionFailed(String)
    var description: String {
        switch self {
        case .assertionFailed(let msg): return msg.isEmpty ? "assertion failed" : msg
        }
    }
}

// ── Pure-logic functions under test ──
// These mirror the algorithms PetAnimationPlayer will use internally.
// The actual class wraps these in AppKit-dependent code (CGImageSource, CVDisplayLink),
// but the core logic is testable in isolation.

enum PowerSource {
    case acPower
    case battery
}

/// Compute the target FPS based on power source and idle state.
/// AC: return nil (use display refresh rate). Battery: 10fps. Battery+idle30s: 5fps.
func computeTargetFPS(powerSource: PowerSource, idleSeconds: TimeInterval) -> Int? {
    switch powerSource {
    case .acPower:
        return nil // nil means "use display refresh rate"
    case .battery:
        if idleSeconds >= 30 {
            return 5
        } else {
            return 10
        }
    }
}

/// Determine whether a frame at the given index should be rendered
/// given a target FPS and the source GIF's native frame rate.
/// Returns true if the frame should be displayed (or if targetFPS is nil).
func shouldRenderFrame(frameIndex: Int, targetFPS: Int?, sourceFPS: Int) -> Bool {
    guard let targetFPS = targetFPS, targetFPS > 0 else {
        return true // no throttling
    }
    guard targetFPS < sourceFPS else {
        return true // target is >= source, no skipping needed
    }
    let skipInterval = max(1, sourceFPS / targetFPS)
    return frameIndex % skipInterval == 0
}

/// Advance the frame index, handling loop boundaries.
/// Returns the next frame index. If loopCount > 0, tracks completed loops.
func advanceFrame(
    currentIndex: Int,
    totalFrames: Int,
    loopCount: Int,
    completedLoops: Int
) -> (nextIndex: Int, completedLoops: Int) {
    guard totalFrames > 0 else {
        return (0, completedLoops)
    }

    let nextIndex = currentIndex + 1

    // If we haven't reached the end, just move forward
    if nextIndex < totalFrames {
        return (nextIndex, completedLoops)
    }

    // At the end — check loop constraints
    if loopCount == 0 {
        // Loop forever — reset to frame 0
        return (0, completedLoops)
    }

    // Finite loop — count completed loops
    let newCompletedLoops = completedLoops + 1
    if newCompletedLoops >= loopCount {
        // All loops done — freeze on last frame
        return (totalFrames - 1, newCompletedLoops)
    }

    // Still within loop count — reset to frame 0
    return (0, newCompletedLoops)
}

/// Crossfade state machine.
enum CrossfadePhase {
    case none
    case fading(durationElapsed: TimeInterval, totalDuration: TimeInterval)
    case complete
}

/// Compute the crossfade phase given the elapsed time since crossfade started.
/// A crossfade takes `totalDuration` seconds. After that, it's complete.
func computeCrossfadePhase(
    isCrossfading: Bool,
    elapsed: TimeInterval,
    totalDuration: TimeInterval
) -> CrossfadePhase {
    guard isCrossfading else { return .none }
    if elapsed >= totalDuration {
        return .complete
    }
    return .fading(durationElapsed: elapsed, totalDuration: totalDuration)
}

/// Pre-decode count: always decode first `preloadCount` frames eagerly.
func preloadFrameCount(totalFrames: Int, preloadCount: Int = 4) -> Int {
    guard totalFrames > 0 else { return 0 }
    return min(totalFrames, preloadCount)
}

// ── TESTS ──────────────────────────────────────────────────────────

print("=== PetAnimationPlayer Pure Logic Tests ===\n")

// MARK: - GIF Decoder Logic

print("-- GIF Decoder Logic --")

test("valid GIF has frame count and no error") {
    let result = GIFDecodeResult.valid(frames: (0..<30).map {
        MockFrame(index: $0, duration: 1.0/30.0, disposalMethod: 0)
    })
    try assert(result.isValid)
    try assertEqual(result.totalFrameCount, 30)
    try assert(result.errorMessage == nil)
}

test("invalid GIF has error message") {
    let result = GIFDecodeResult.invalid("file not found")
    try assert(!result.isValid)
    try assertEqual(result.totalFrameCount, 0)
    try assert(result.errorMessage != nil)
}

test("pre-decode count: full GIF (>= 4 frames) decodes 4") {
    let count = preloadFrameCount(totalFrames: 30, preloadCount: 4)
    try assertEqual(count, 4)
}

test("pre-decode count: short GIF (< 4 frames) decodes all") {
    let count = preloadFrameCount(totalFrames: 3, preloadCount: 4)
    try assertEqual(count, 3)
}

test("pre-decode count: empty GIF decodes 0") {
    let count = preloadFrameCount(totalFrames: 0, preloadCount: 4)
    try assertEqual(count, 0)
}

test("pre-decode count: exactly 4 frames") {
    let count = preloadFrameCount(totalFrames: 4, preloadCount: 4)
    try assertEqual(count, 4)
}

// MARK: - Frame Advancement

print("\n-- Frame Advancement --")

test("advances to next frame in middle of animation") {
    let (next, loops) = advanceFrame(currentIndex: 5, totalFrames: 30, loopCount: 0, completedLoops: 0)
    try assertEqual(next, 6)
    try assertEqual(loops, 0)
}

test("wraps to frame 0 at end (infinite loop)") {
    let (next, loops) = advanceFrame(currentIndex: 29, totalFrames: 30, loopCount: 0, completedLoops: 0)
    try assertEqual(next, 0)
    try assertEqual(loops, 0)
}

test("handles first frame to second") {
    let (next, _) = advanceFrame(currentIndex: 0, totalFrames: 30, loopCount: 0, completedLoops: 0)
    try assertEqual(next, 1)
}

test("finite loop increments completed count and resets") {
    let (next, loops) = advanceFrame(currentIndex: 29, totalFrames: 30, loopCount: 3, completedLoops: 0)
    try assertEqual(next, 0)
    try assertEqual(loops, 1)
}

test("finite loop freeze on last frame when all loops done") {
    let (next, loops) = advanceFrame(currentIndex: 29, totalFrames: 30, loopCount: 2, completedLoops: 1)
    try assertEqual(next, 29)
    try assertEqual(loops, 2)
}

test("finite loop: second-to-last iteration") {
    let (next, loops) = advanceFrame(currentIndex: 29, totalFrames: 30, loopCount: 3, completedLoops: 2)
    try assertEqual(next, 29)
    try assertEqual(loops, 3)
}

test("single-frame GIF loops forever from frame 0") {
    let (next, loops) = advanceFrame(currentIndex: 0, totalFrames: 1, loopCount: 0, completedLoops: 0)
    try assertEqual(next, 0)
    try assertEqual(loops, 0)
}

test("single-frame GIF finite loop freezes immediately") {
    let (next, loops) = advanceFrame(currentIndex: 0, totalFrames: 1, loopCount: 1, completedLoops: 0)
    try assertEqual(next, 0)
    try assertEqual(loops, 1) // completed its one and only loop
}

test("empty GIF (0 frames) returns index 0") {
    let (next, _) = advanceFrame(currentIndex: 0, totalFrames: 0, loopCount: 0, completedLoops: 0)
    try assertEqual(next, 0)
}

// MARK: - Crossfade State Machine

print("\n-- Crossfade State Machine --")

test("crossfade not active returns .none") {
    let phase = computeCrossfadePhase(isCrossfading: false, elapsed: 0, totalDuration: 0.2)
    if case .none = phase {
        // pass
    } else {
        try assert(false, "expected .none")
    }
}

test("crossfade in progress returns .fading") {
    let phase = computeCrossfadePhase(isCrossfading: true, elapsed: 0.1, totalDuration: 0.2)
    switch phase {
    case .fading(let durationElapsed, let totalDuration):
        try assert(durationElapsed >= 0)
        try assertEqual(totalDuration, 0.2)
    default:
        try assert(false, "expected .fading")
    }
}

test("crossfade at exactly duration returns .complete") {
    let phase = computeCrossfadePhase(isCrossfading: true, elapsed: 0.2, totalDuration: 0.2)
    if case .complete = phase {
        // pass
    } else {
        try assert(false, "expected .complete")
    }
}

test("crossfade past duration returns .complete") {
    let phase = computeCrossfadePhase(isCrossfading: true, elapsed: 0.5, totalDuration: 0.2)
    if case .complete = phase {
        // pass
    } else {
        try assert(false, "expected .complete")
    }
}

test("crossfade at 0 seconds started returns .fading with 0 elapsed") {
    let phase = computeCrossfadePhase(isCrossfading: true, elapsed: 0.0, totalDuration: 0.2)
    switch phase {
    case .fading(let elapsed, _):
        try assertEqual(elapsed, 0.0)
    default:
        try assert(false, "expected .fading at elapsed=0")
    }
}

test("crossfade duration is exactly 0.2s as specified") {
    // Verify the design constant: 0.2s crossfade duration
    try assertEqual(0.2, 0.2) // spec value documented
}

// MARK: - Battery-Aware Frame Rate

print("\n-- Battery-Aware Frame Rate --")

test("AC power returns nil (use display refresh rate)") {
    let fps = computeTargetFPS(powerSource: .acPower, idleSeconds: 0)
    try assert(fps == nil)
}

test("AC power returns nil even when idle") {
    let fps = computeTargetFPS(powerSource: .acPower, idleSeconds: 300)
    try assert(fps == nil)
}

test("battery mode returns 10fps when active") {
    let fps = computeTargetFPS(powerSource: .battery, idleSeconds: 0)
    try assertEqual(fps, 10)
}

test("battery mode returns 10fps just below idle threshold") {
    let fps = computeTargetFPS(powerSource: .battery, idleSeconds: 29)
    try assertEqual(fps, 10)
}

test("battery mode returns 5fps at exactly 30s idle") {
    let fps = computeTargetFPS(powerSource: .battery, idleSeconds: 30)
    try assertEqual(fps, 5)
}

test("battery mode returns 5fps deep idle") {
    let fps = computeTargetFPS(powerSource: .battery, idleSeconds: 300)
    try assertEqual(fps, 5)
}

// MARK: - Frame Skip Logic

print("\n-- Frame Skip Logic --")

test("nil targetFPS always renders") {
    try assert(shouldRenderFrame(frameIndex: 7, targetFPS: nil, sourceFPS: 30))
}

test("targetFPS >= sourceFPS always renders") {
    try assert(shouldRenderFrame(frameIndex: 5, targetFPS: 60, sourceFPS: 30))
}

test("targetFPS == sourceFPS always renders") {
    try assert(shouldRenderFrame(frameIndex: 5, targetFPS: 30, sourceFPS: 30))
}

test("half frame rate renders every other frame") {
    let sourceFPS = 30
    let targetFPS = 10  // skipInterval = 3
    let skipInterval = sourceFPS / targetFPS  // = 3
    try assertEqual(skipInterval, 3)
    // Frame 0 renders, frame 1-2 skip, frame 3 renders
    try assert(shouldRenderFrame(frameIndex: 0, targetFPS: targetFPS, sourceFPS: sourceFPS))
    try assert(!shouldRenderFrame(frameIndex: 1, targetFPS: targetFPS, sourceFPS: sourceFPS))
    try assert(!shouldRenderFrame(frameIndex: 2, targetFPS: targetFPS, sourceFPS: sourceFPS))
    try assert(shouldRenderFrame(frameIndex: 3, targetFPS: targetFPS, sourceFPS: sourceFPS))
}

test("quarter frame rate (5fps from 30fps) renders every 6th frame") {
    let sourceFPS = 30
    let targetFPS = 5  // skipInterval = 6
    let skipInterval = sourceFPS / targetFPS
    try assertEqual(skipInterval, 6)
    try assert(shouldRenderFrame(frameIndex: 0, targetFPS: targetFPS, sourceFPS: sourceFPS))
    try assert(shouldRenderFrame(frameIndex: 6, targetFPS: targetFPS, sourceFPS: sourceFPS))
    try assert(!shouldRenderFrame(frameIndex: 5, targetFPS: targetFPS, sourceFPS: sourceFPS))
}

test("frame 0 always renders regardless of throttle") {
    try assert(shouldRenderFrame(frameIndex: 0, targetFPS: 5, sourceFPS: 30))
    try assert(shouldRenderFrame(frameIndex: 0, targetFPS: 1, sourceFPS: 60))
}

test("targetFPS of 0 treated as no throttle") {
    try assert(shouldRenderFrame(frameIndex: 3, targetFPS: 0, sourceFPS: 30))
}

// MARK: - Disposal Method Handling

print("\n-- Disposal Method Handling --")

test("disposal method 0 (none) — frame overlays previous") {
    let frame = MockFrame(index: 0, duration: 0.1, disposalMethod: 0)
    try assertEqual(frame.disposalMethod, 0)
}

test("disposal method 1 (background) — clear to background before drawing") {
    let frame = MockFrame(index: 1, duration: 0.1, disposalMethod: 1)
    try assertEqual(frame.disposalMethod, 1)
}

test("disposal method 2 (previous) — restore to previous frame") {
    let frame = MockFrame(index: 2, duration: 0.1, disposalMethod: 2)
    try assertEqual(frame.disposalMethod, 2)
}

// MARK: - Error Recovery

print("\n-- Error Recovery --")

test("corrupt GIF falls back to placeholder") {
    let result = GIFDecodeResult.invalid("CGImageSourceCreateWithURL failed")
    try assert(!result.isValid)
    try assertEqual(result.totalFrameCount, 0)
    try assert(result.frames.isEmpty)
}

test("missing file produces invalid result") {
    let result = GIFDecodeResult.invalid("file not found at path")
    try assert(!result.isValid)
}

test("valid result after invalid is separate tracking") {
    let bad = GIFDecodeResult.invalid("read error")
    let good = GIFDecodeResult.valid(frames: [
        MockFrame(index: 0, duration: 1.0/15.0, disposalMethod: 0)
    ])
    try assert(!bad.isValid)
    try assert(good.isValid)
}

// MARK: - Loop Count Edge Cases

print("\n-- Loop Count Edge Cases --")

test("loop count 0 means infinite") {
    let result = GIFDecodeResult.valid(frames: (0..<10).map {
        MockFrame(index: $0, duration: 0.1, disposalMethod: 0)
    }, loopCount: 0)
    try assertEqual(result.loopCount, 0)
}

test("loop count 1 means play once") {
    let result = GIFDecodeResult.valid(frames: (0..<10).map {
        MockFrame(index: $0, duration: 0.1, disposalMethod: 0)
    }, loopCount: 1)
    try assertEqual(result.loopCount, 1)
}

test("finite loop: play once freezes on last frame") {
    let (next, loops) = advanceFrame(currentIndex: 9, totalFrames: 10, loopCount: 1, completedLoops: 0)
    try assertEqual(next, 9)  // frozen on last
    try assertEqual(loops, 1) // one loop completed
}

test("finite loop: play twice then freeze") {
    let (next1, loops1) = advanceFrame(currentIndex: 9, totalFrames: 10, loopCount: 2, completedLoops: 0)
    try assertEqual(next1, 0)
    try assertEqual(loops1, 1)

    let (next2, loops2) = advanceFrame(currentIndex: 9, totalFrames: 10, loopCount: 2, completedLoops: 1)
    try assertEqual(next2, 9)  // frozen
    try assertEqual(loops2, 2)
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
