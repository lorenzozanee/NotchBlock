#!/usr/bin/env swift
import Foundation

// ── PetState enum (inline for isolated testing) ────────────────────
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

    static func < (lhs: PetState, rhs: PetState) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Base filename for naming convention fallback (without extension or pet prefix).
    var animationFileName: String {
        switch self {
        case .initial:        return "waving"
        case .idle:           return "idle"
        case .idleMicro:      return "blink"
        case .sleeping:       return "sleeping"
        case .focusing:       return "waiting"
        case .succeeded:      return "jumping"
        case .failed:         return "failed"
        case .draggingLeft:   return "running-left"
        case .draggingRight:  return "running-right"
        }
    }

    /// Human-readable Chinese label for debugging / logging.
    var label: String {
        switch self {
        case .initial:        return "初始化"
        case .idle:           return "待机"
        case .idleMicro:      return "微动作"
        case .sleeping:       return "睡眠"
        case .focusing:       return "专注中"
        case .succeeded:      return "成功"
        case .failed:         return "失败"
        case .draggingLeft:   return "左拖拽"
        case .draggingRight:  return "右拖拽"
        }
    }
}

// ── Test harness ───────────────────────────────────────────────────
var passed = 0, failed = 0
func test(_ name: String, _ block: () throws -> Void) {
    do { try block(); passed += 1; print("  ✅ \(name)") }
    catch { failed += 1; print("  ❌ \(name): \(error)") }
}

print("=== PetState Tests ===")

// ── Raw value correctness ──────────────────────────────────────────
test("all 9 cases exist") {
    let all = PetState.allCases
    assert(all.count == 9, "expected 9 cases, got \(all.count)")
}

test("initial rawValue is 0") {
    assert(PetState.initial.rawValue == 0)
}

test("idle rawValue is 1") {
    assert(PetState.idle.rawValue == 1)
}

test("idleMicro rawValue is 2") {
    assert(PetState.idleMicro.rawValue == 2)
}

test("sleeping rawValue is 3") {
    assert(PetState.sleeping.rawValue == 3)
}

test("focusing rawValue is 4") {
    assert(PetState.focusing.rawValue == 4)
}

test("succeeded rawValue is 5") {
    assert(PetState.succeeded.rawValue == 5)
}

test("failed rawValue is 6") {
    assert(PetState.failed.rawValue == 6)
}

test("draggingLeft rawValue is 7") {
    assert(PetState.draggingLeft.rawValue == 7)
}

test("draggingRight rawValue is 8") {
    assert(PetState.draggingRight.rawValue == 8)
}

// ── Comparable (priority = descending rawValue) ────────────────────
test("draggingRight has highest priority") {
    let states = PetState.allCases.sorted(by: >)
    assert(states.first == .draggingRight, "expected draggingRight highest, got \(String(describing: states.first))")
}

test("initial has lowest priority") {
    let states = PetState.allCases.sorted(by: >)
    assert(states.last == .initial, "expected initial lowest, got \(String(describing: states.last))")
}

test("full priority chain (descending)") {
    let expected: [PetState] = [
        .draggingRight, .draggingLeft, .failed, .succeeded,
        .focusing, .sleeping, .idleMicro, .idle, .initial
    ]
    let sorted = PetState.allCases.sorted(by: >)
    assert(sorted == expected, "priority chain mismatch: \(sorted.map(\.rawValue))")
}

test("draggingLeft > failed (higher priority)") {
    assert(PetState.draggingLeft > PetState.failed)
}

test("failed > succeeded (higher priority)") {
    assert(PetState.failed > PetState.succeeded)
}

test("succeeded > focusing (higher priority)") {
    assert(PetState.succeeded > PetState.focusing)
}

test("focusing > idle (higher priority)") {
    assert(PetState.focusing > PetState.idle)
}

test("idle > initial (higher priority)") {
    assert(PetState.idle > PetState.initial)
}

// ── CaseIterable ───────────────────────────────────────────────────
test("allCases is non-empty") {
    assert(!PetState.allCases.isEmpty)
}

test("allCases contains every enum case") {
    let names = Set(PetState.allCases.map { $0 })
    assert(names.count == 9)
}

// ── animationFileName mapping ──────────────────────────────────────
test("initial maps to waving") {
    assert(PetState.initial.animationFileName == "waving")
}

test("idle maps to idle") {
    assert(PetState.idle.animationFileName == "idle")
}

test("idleMicro maps to blink") {
    assert(PetState.idleMicro.animationFileName == "blink")
}

test("sleeping maps to sleeping") {
    assert(PetState.sleeping.animationFileName == "sleeping")
}

test("focusing maps to waiting") {
    assert(PetState.focusing.animationFileName == "waiting")
}

test("succeeded maps to jumping") {
    assert(PetState.succeeded.animationFileName == "jumping")
}

test("failed maps to failed") {
    assert(PetState.failed.animationFileName == "failed")
}

test("draggingLeft maps to running-left") {
    assert(PetState.draggingLeft.animationFileName == "running-left")
}

test("draggingRight maps to running-right") {
    assert(PetState.draggingRight.animationFileName == "running-right")
}

test("all animation file names are unique") {
    let names = PetState.allCases.map { $0.animationFileName }
    assert(Set(names).count == 9, "duplicate animation file names found")
}

// ── Label ──────────────────────────────────────────────────────────
test("every state has a non-empty label") {
    for state in PetState.allCases {
        assert(!state.label.isEmpty, "\(state) label is empty")
    }
}

// ── RawValue initialization ────────────────────────────────────────
test("init from rawValue round-trips") {
    for state in PetState.allCases {
        let restored = PetState(rawValue: state.rawValue)
        assert(restored == state, "round-trip failed for \(state)")
    }
}

test("invalid rawValue returns nil") {
    assert(PetState(rawValue: 999) == nil)
    assert(PetState(rawValue: -1) == nil)
}

print("\n\(passed)/\(passed+failed) passed")
exit(failed > 0 ? 1 : 0)
