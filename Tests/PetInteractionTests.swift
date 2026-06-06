#!/usr/bin/env swift
import Foundation
import CoreGraphics

// ── Mirrored PetState for isolated testing ────────────────────────────

enum PetState: Int, Comparable, CaseIterable {
    case initial = 0, idle = 1, idleMicro = 2, sleeping = 3, focusing = 4
    case succeeded = 5, failed = 6, draggingLeft = 7, draggingRight = 8
    static func < (lhs: PetState, rhs: PetState) -> Bool { lhs.rawValue < rhs.rawValue }
}

// ── Interaction logic under test ──────────────────────────────────────

struct InteractionLogic {
    /// 3pt Euclidean distance threshold to differentiate click vs drag.
    static let dragThreshold: CGFloat = 3.0

    /// Minimum time between successive clicks that both register.
    static let clickDebounce: TimeInterval = 0.3

    /// Margin preserved from every screen edge during drag clamping.
    static let edgeMargin: CGFloat = 20.0

    // ── Drag Detection ─────────────────────────────────────────────

    /// Returns true when the squared Euclidean distance >= threshold squared.
    static func isDrag(from start: CGPoint, to current: CGPoint) -> Bool {
        let dx = current.x - start.x
        let dy = current.y - start.y
        return (dx * dx + dy * dy) >= (dragThreshold * dragThreshold)
    }

    /// Returns the horizontal drag direction, or nil when vertical-dominant or no movement.
    static func dragDirection(from start: CGPoint, to current: CGPoint) -> PetState? {
        let dx = current.x - start.x
        let dy = current.y - start.y
        guard abs(dx) > abs(dy) else { return nil }
        return dx < 0 ? .draggingLeft : .draggingRight
    }

    // ── Clamping ───────────────────────────────────────────────────

    /// Clamp a point within the given screen frame, preserving `margin` from every edge.
    static func clampToScreen(_ point: CGPoint, screenFrame: CGRect, margin: CGFloat = edgeMargin) -> CGPoint {
        let minX = screenFrame.minX + margin
        let maxX = screenFrame.maxX - margin
        let minY = screenFrame.minY + margin
        let maxY = screenFrame.maxY - margin
        return CGPoint(
            x: min(max(point.x, minX), maxX),
            y: min(max(point.y, minY), maxY)
        )
    }

    // ── Debounce ───────────────────────────────────────────────────

    /// Returns true if enough time has elapsed since `lastClickTime` to allow a new click.
    static func shouldAllowClick(lastClickTime: Date?, now: Date = Date()) -> Bool {
        guard let last = lastClickTime else { return true }
        return now.timeIntervalSince(last) >= clickDebounce
    }
}

// ── Test harness ──────────────────────────────────────────────────────

var passed = 0, failed = 0
func test(_ name: String, _ block: () throws -> Void) {
    do { try block(); passed += 1; print("  ✅ \(name)") }
    catch { failed += 1; print("  ❌ \(name): \(error)") }
}

// Helper: approximate floating-point equality
func approx(_ a: CGFloat, _ b: CGFloat, tolerance: CGFloat = 0.001) -> Bool {
    abs(a - b) < tolerance
}

// Helper: assert with message
func assertTrue(_ condition: Bool, _ message: String = "", file: StaticString = #file, line: UInt = #line) throws {
    guard condition else {
        throw NSError(domain: "test", code: 1,
            userInfo: [NSLocalizedDescriptionKey: message.isEmpty ? "expected true" : message])
    }
}

print("=== PetInteraction Tests ===\n")

// ══════════════════════════════════════════════════════════════════════
// MARK: - Drag Threshold (isDrag)
// ══════════════════════════════════════════════════════════════════════

print("--- Drag Threshold ---")

test("zero movement is not a drag") {
    try assertTrue(!InteractionLogic.isDrag(from: CGPoint(x: 100, y: 200), to: CGPoint(x: 100, y: 200)))
}

test("movement exactly at 3pt threshold IS a drag") {
    // 3pt exactly on x-axis
    try assertTrue(InteractionLogic.isDrag(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 3, y: 0)))
}

test("movement exactly at 3pt threshold on y-axis IS a drag") {
    try assertTrue(InteractionLogic.isDrag(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: 3)))
}

test("movement at 2.99pt is NOT a drag (below threshold)") {
    try assertTrue(!InteractionLogic.isDrag(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 2.99, y: 0)))
}

test("diagonal movement exceeding threshold IS a drag") {
    // dx=3, dy=4 → distance=5 > 3
    try assertTrue(InteractionLogic.isDrag(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 3, y: 4)))
}

test("diagonal movement below threshold is NOT a drag") {
    // dx=1, dy=1 → distance=1.414 < 3
    try assertTrue(!InteractionLogic.isDrag(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 1, y: 1)))
}

test("large movement is a drag") {
    try assertTrue(InteractionLogic.isDrag(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 500, y: 300)))
}

test("negative direction movement exceeding threshold IS a drag") {
    try assertTrue(InteractionLogic.isDrag(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 90, y: 90)))
}

test("isDrag handles non-origin start coordinates") {
    try assertTrue(InteractionLogic.isDrag(from: CGPoint(x: 500, y: 300), to: CGPoint(x: 510, y: 300)))
}

// ══════════════════════════════════════════════════════════════════════
// MARK: - Direction Detection (dragDirection)
// ══════════════════════════════════════════════════════════════════════

print("\n--- Direction Detection ---")

test("moving left returns draggingLeft") {
    let dir = InteractionLogic.dragDirection(from: CGPoint(x: 100, y: 0), to: CGPoint(x: 80, y: 0))
    try assertTrue(dir == .draggingLeft, "expected draggingLeft, got \(String(describing: dir))")
}

test("moving right returns draggingRight") {
    let dir = InteractionLogic.dragDirection(from: CGPoint(x: 100, y: 0), to: CGPoint(x: 120, y: 0))
    try assertTrue(dir == .draggingRight, "expected draggingRight, got \(String(describing: dir))")
}

test("moving vertically returns nil (no direction)") {
    let dir = InteractionLogic.dragDirection(from: CGPoint(x: 0, y: 100), to: CGPoint(x: 0, y: 200))
    try assertTrue(dir == nil, "expected nil for vertical drag")
}

test("diagonal mostly-horizontal right returns draggingRight") {
    // dx=20, dy=1 → horizontal dominant
    let dir = InteractionLogic.dragDirection(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 20, y: 1))
    try assertTrue(dir == .draggingRight, "expected draggingRight for dx>dy")
}

test("diagonal mostly-horizontal left returns draggingLeft") {
    let dir = InteractionLogic.dragDirection(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 30, y: 55))
    try assertTrue(dir == .draggingLeft, "expected draggingLeft for dx<0 with |dx|>|dy|")
}

test("diagonal mostly-vertical returns nil") {
    // dx=1, dy=20 → vertical dominant
    let dir = InteractionLogic.dragDirection(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 1, y: 20))
    try assertTrue(dir == nil, "expected nil for vertical-dominant drag")
}

test("equal absolute dx and dy returns nil (tie → not horizontal)") {
    let dir = InteractionLogic.dragDirection(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 10, y: 10))
    try assertTrue(dir == nil, "expected nil when |dx| == |dy|")
}

test("equal absolute negative dx and positive dy returns nil") {
    let dir = InteractionLogic.dragDirection(from: CGPoint(x: 0, y: 0), to: CGPoint(x: -10, y: 10))
    try assertTrue(dir == nil, "expected nil when |dx| == |dy|")
}

test("zero movement returns nil") {
    let dir = InteractionLogic.dragDirection(from: CGPoint(x: 10, y: 20), to: CGPoint(x: 10, y: 20))
    try assertTrue(dir == nil, "expected nil for zero movement")
}

// ══════════════════════════════════════════════════════════════════════
// MARK: - Edge Clamping (clampToScreen)
// ══════════════════════════════════════════════════════════════════════

print("\n--- Edge Clamping ---")

let standardScreen = CGRect(x: 0, y: 0, width: 1440, height: 900)

test("point well within bounds is unchanged") {
    let result = InteractionLogic.clampToScreen(CGPoint(x: 500, y: 400), screenFrame: standardScreen)
    try assertTrue(result.x == 500, "x unchanged, got \(result.x)")
    try assertTrue(result.y == 400, "y unchanged, got \(result.y)")
}

test("clamps x at left edge (below margin)") {
    let result = InteractionLogic.clampToScreen(CGPoint(x: 5, y: 400), screenFrame: standardScreen, margin: 20)
    try assertTrue(result.x == 20, "x clamped to 20, got \(result.x)")
    try assertTrue(result.y == 400, "y unchanged")
}

test("clamps x at right edge (above max)") {
    let result = InteractionLogic.clampToScreen(CGPoint(x: 2000, y: 400), screenFrame: standardScreen, margin: 20)
    try assertTrue(result.x == 1420, "x clamped to 1420, got \(result.x)")
}

test("clamps y at bottom edge (below margin)") {
    let result = InteractionLogic.clampToScreen(CGPoint(x: 500, y: 5), screenFrame: standardScreen, margin: 20)
    try assertTrue(result.y == 20, "y clamped to 20, got \(result.y)")
}

test("clamps y at top edge (above max)") {
    let result = InteractionLogic.clampToScreen(CGPoint(x: 500, y: 950), screenFrame: standardScreen, margin: 20)
    try assertTrue(result.y == 880, "y clamped to 880, got \(result.y)")
}

test("clamps both x and y when out of bounds") {
    let result = InteractionLogic.clampToScreen(CGPoint(x: -100, y: -50), screenFrame: standardScreen, margin: 20)
    try assertTrue(result.x == 20, "x clamped")
    try assertTrue(result.y == 20, "y clamped")
}

test("clamps both x and y when exceeding both maxes") {
    let result = InteractionLogic.clampToScreen(CGPoint(x: 3000, y: 2000), screenFrame: standardScreen, margin: 20)
    try assertTrue(result.x == 1420, "x clamped")
    try assertTrue(result.y == 880, "y clamped")
}

test("clamping with custom margin of 0 allows edge positions") {
    let result = InteractionLogic.clampToScreen(CGPoint(x: 0, y: 0), screenFrame: standardScreen, margin: 0)
    try assertTrue(result.x == 0)
    try assertTrue(result.y == 0)
}

test("clamping with custom margin of 50") {
    let result = InteractionLogic.clampToScreen(CGPoint(x: 10, y: 10), screenFrame: standardScreen, margin: 50)
    try assertTrue(result.x == 50)
    try assertTrue(result.y == 50)
}

test("clamping on secondary screen uses its frame correctly") {
    let secondary = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
    let result = InteractionLogic.clampToScreen(CGPoint(x: 1400, y: 500), screenFrame: secondary, margin: 20)
    try assertTrue(result.x == 1460, "clamped to secondary minX + 20 = 1440+20=1460, got \(result.x)")
    try assertTrue(result.y == 500, "y within bounds unchanged")
}

test("clamping on secondary screen at max edges") {
    let secondary = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
    let result = InteractionLogic.clampToScreen(CGPoint(x: 5000, y: 2000), screenFrame: secondary, margin: 20)
    try assertTrue(result.x == 3340, "clamped to secondary maxX - 20 = 1440+1920-20=3340, got \(result.x)")
    try assertTrue(result.y == 1060, "clamped to secondary maxY - 20 = 1080-20=1060, got \(result.y)")
}

// ══════════════════════════════════════════════════════════════════════
// MARK: - Click Debounce (shouldAllowClick)
// ══════════════════════════════════════════════════════════════════════

print("\n--- Click Debounce ---")

test("first click is always allowed (nil lastClickTime)") {
    try assertTrue(InteractionLogic.shouldAllowClick(lastClickTime: nil))
}

test("click allowed after exactly 0.3s debounce period") {
    // Use -0.301 to avoid floating-point rounding at the equality boundary
    let last = Date().addingTimeInterval(-0.301)
    try assertTrue(InteractionLogic.shouldAllowClick(lastClickTime: last, now: Date()))
}

test("click allowed after more than 0.3s") {
    let last = Date().addingTimeInterval(-0.5)
    try assertTrue(InteractionLogic.shouldAllowClick(lastClickTime: last, now: Date()))
}

test("click suppressed within 0.3s debounce period") {
    let now = Date()
    let last = now.addingTimeInterval(-0.1)
    try assertTrue(!InteractionLogic.shouldAllowClick(lastClickTime: last, now: now))
}

test("click suppressed at 0.29s") {
    let now = Date()
    let last = now.addingTimeInterval(-0.29)
    try assertTrue(!InteractionLogic.shouldAllowClick(lastClickTime: last, now: now))
}

test("click allowed after long delay") {
    let last = Date().addingTimeInterval(-10.0)
    try assertTrue(InteractionLogic.shouldAllowClick(lastClickTime: last, now: Date()))
}

test("click timestamp in the future suppresses click (clock-skew defense)") {
    // If lastClickTime is ahead of now (clock was set back), debounce should
    // conservatively suppress the click rather than allow a burst.
    let now = Date()
    let futureLast = now.addingTimeInterval(1.0)
    try assertTrue(!InteractionLogic.shouldAllowClick(lastClickTime: futureLast, now: now))
}

// ══════════════════════════════════════════════════════════════════════
// MARK: - Combined scenario tests
// ══════════════════════════════════════════════════════════════════════

print("\n--- Combined Scenarios ---")

test("slow mouse movement below threshold: NOT a drag → treated as click") {
    let start = CGPoint(x: 100, y: 100)
    let current = CGPoint(x: 101, y: 100) // 1pt, < 3pt threshold
    try assertTrue(!InteractionLogic.isDrag(from: start, to: current))
}

test("fast mouse movement: IS a drag, direction detected") {
    let start = CGPoint(x: 100, y: 100)
    let current = CGPoint(x: 80, y: 95) // dx=-20, dy=-5 → drag (25pt), left direction
    try assertTrue(InteractionLogic.isDrag(from: start, to: current))
    try assertTrue(InteractionLogic.dragDirection(from: start, to: current) == .draggingLeft)
}

test("drag to screen edge gets clamped") {
    let start = CGPoint(x: 0, y: 0)
    let rawEnd = CGPoint(x: -50, y: 1000)
    try assertTrue(InteractionLogic.isDrag(from: start, to: rawEnd))
    let clamped = InteractionLogic.clampToScreen(rawEnd, screenFrame: standardScreen)
    try assertTrue(clamped.x == 20, "left edge clamped")
    try assertTrue(clamped.y == 880, "top edge clamped")
}

test("double-click within 0.1s: only first registers") {
    let now = Date()
    // First click
    try assertTrue(InteractionLogic.shouldAllowClick(lastClickTime: nil, now: now))
    let afterFirst = now.addingTimeInterval(0.1)
    // Second click too soon
    try assertTrue(!InteractionLogic.shouldAllowClick(lastClickTime: now, now: afterFirst))
}

test("double-click spaced by 0.4s: both register") {
    let now = Date()
    try assertTrue(InteractionLogic.shouldAllowClick(lastClickTime: nil, now: now))
    let afterDelay = now.addingTimeInterval(0.4)
    try assertTrue(InteractionLogic.shouldAllowClick(lastClickTime: now, now: afterDelay))
}

test("drag direction is nil for purely vertical movement") {
    let start = CGPoint(x: 100, y: 100)
    let end = CGPoint(x: 100, y: 200)
    try assertTrue(InteractionLogic.isDrag(from: start, to: end)) // 100pt > threshold
    try assertTrue(InteractionLogic.dragDirection(from: start, to: end) == nil) // vertical
}

test("tiny wiggle below threshold stays as click, not drag") {
    // Simulate hand tremor: tiny movements within 3pt
    let start = CGPoint(x: 100, y: 100)
    let wiggle1 = CGPoint(x: 101, y: 101)
    let wiggle2 = CGPoint(x: 99, y: 102)
    try assertTrue(!InteractionLogic.isDrag(from: start, to: wiggle1))
    try assertTrue(!InteractionLogic.isDrag(from: start, to: wiggle2))
}

// ══════════════════════════════════════════════════════════════════════
// MARK: - Edge cases
// ══════════════════════════════════════════════════════════════════════

print("\n--- Edge Cases ---")

test("isDrag with CGFloat boundary values is stable") {
    try assertTrue(InteractionLogic.isDrag(from: CGPoint(x: 0, y: 0), to: CGPoint(x: CGFloat.greatestFiniteMagnitude, y: 0)))
    // Note: greatestFiniteMagnitude squared overflows to inf, so >= comparison works correctly
    let result = InteractionLogic.isDrag(
        from: CGPoint(x: CGFloat.greatestFiniteMagnitude, y: 0),
        to: CGPoint(x: CGFloat.greatestFiniteMagnitude, y: 0)
    )
    try assertTrue(!result, "zero distance should not be drag even at extreme coords")
}

test("dragDirection with very large coordinates") {
    let dir = InteractionLogic.dragDirection(
        from: CGPoint(x: 1_000_000, y: 0),
        to: CGPoint(x: 1_000_000, y: 100)
    )
    try assertTrue(dir == nil, "vertical at large coords")
}

test("dragDirection with tiny horizontal dominant movement") {
    // dx=0.01, dy=0.001 → horizontal dominant
    let dir = InteractionLogic.dragDirection(from: CGPoint(x: 0, y: 0), to: CGPoint(x: -0.01, y: 0.001))
    try assertTrue(dir == .draggingLeft)
}

test("clampToScreen with extremely narrow screen") {
    let tinyScreen = CGRect(x: 0, y: 0, width: 30, height: 30)
    let result = InteractionLogic.clampToScreen(CGPoint(x: 100, y: 100), screenFrame: tinyScreen, margin: 20)
    // maxX - margin = 30-20=10, minX + margin = 20 → minX > maxX → x clamped to 10
    try assertTrue(result.x == 10, "x clamped to maxX-margin when screen is narrower than 2*margin")
    try assertTrue(result.y == 10, "y clamped similarly")
}

// ══════════════════════════════════════════════════════════════════════
// MARK: - Summary
// ══════════════════════════════════════════════════════════════════════

print("\n\(passed)/\(passed+failed) passed")
exit(failed > 0 ? 1 : 0)
