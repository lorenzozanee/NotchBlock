#!/usr/bin/env swift
import Foundation
import CoreGraphics

// ── Inline PetPreferences for isolated testing ─────────────────────

struct PetPreferences {
    private let defaults: UserDefaults

    /// Key constants — must match between App and test.
    private enum Key {
        static let enabled = "pet.enabled"
        static let selected = "pet.selected"
        static let positionX = "pet.position.x"
        static let positionY = "pet.position.y"
        static let hideInFullscreen = "pet.hideInFullscreen"
        static let idleSleepMinutes = "pet.idleSleepMinutes"
    }

    /// Default values used when no stored value exists.
    private enum Defaults {
        static let enabled = true
        static let selected = "elysia"
        static let hideInFullscreen = false
        static let idleSleepMinutes = 5
        // Position defaults are resolved at access time (screen-dependent)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Stored Properties

    var isEnabled: Bool {
        get {
            if defaults.object(forKey: Key.enabled) == nil {
                return Defaults.enabled
            }
            return defaults.bool(forKey: Key.enabled)
        }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    var selectedPet: String {
        get { defaults.string(forKey: Key.selected) ?? Defaults.selected }
        set { defaults.set(newValue, forKey: Key.selected) }
    }

    var positionX: Double {
        get { defaults.double(forKey: Key.positionX) }
        set { defaults.set(newValue, forKey: Key.positionX) }
    }

    var positionY: Double {
        get { defaults.double(forKey: Key.positionY) }
        set { defaults.set(newValue, forKey: Key.positionY) }
    }

    var hideInFullscreen: Bool {
        get {
            if defaults.object(forKey: Key.hideInFullscreen) == nil {
                return Defaults.hideInFullscreen
            }
            return defaults.bool(forKey: Key.hideInFullscreen)
        }
        set { defaults.set(newValue, forKey: Key.hideInFullscreen) }
    }

    var idleSleepMinutes: Int {
        get {
            if defaults.object(forKey: Key.idleSleepMinutes) == nil {
                return Defaults.idleSleepMinutes
            }
            return defaults.integer(forKey: Key.idleSleepMinutes)
        }
        set { defaults.set(newValue, forKey: Key.idleSleepMinutes) }
    }

    // MARK: - Position

    /// Default position offset from bottom-right of the primary screen.
    static let defaultEdgeMargin: CGFloat = 20

    /// Resolve position, falling back to the bottom-right of the given screen frame
    /// if no position has been saved yet (both x and y are zero).
    func resolvedPosition(fallbackScreenFrame screenFrame: CGRect) -> CGPoint {
        let x = positionX
        let y = positionY
        // If both are 0, no position has been saved — use fallback
        if x == 0 && y == 0 {
            let margin = Self.defaultEdgeMargin
            return CGPoint(
                x: screenFrame.maxX - margin,
                y: screenFrame.maxY - margin
            )
        }
        return CGPoint(x: x, y: y)
    }

    /// Clamp a point so it stays within the visible screen area,
    /// respecting an edge margin.
    func clampPosition(_ point: CGPoint, to screenFrame: CGRect, margin: CGFloat = defaultEdgeMargin) -> CGPoint {
        let minX = screenFrame.minX + margin
        let maxX = screenFrame.maxX - margin
        let minY = screenFrame.minY + margin
        let maxY = screenFrame.maxY - margin
        return CGPoint(
            x: min(max(point.x, minX), maxX),
            y: min(max(point.y, minY), maxY)
        )
    }

    /// Reset position to defaults (clears stored coordinates).
    mutating func resetPosition() {
        defaults.removeObject(forKey: Key.positionX)
        defaults.removeObject(forKey: Key.positionY)
    }

    /// Remove all pet-related keys from UserDefaults.
    func removeAll() {
        for key in [Key.enabled, Key.selected, Key.positionX, Key.positionY,
                    Key.hideInFullscreen, Key.idleSleepMinutes] {
            defaults.removeObject(forKey: key)
        }
    }
}

// ── Test harness ───────────────────────────────────────────────────
var passed = 0, failed = 0
func test(_ name: String, _ block: () throws -> Void) {
    do { try block(); passed += 1; print("  ✅ \(name)") }
    catch { failed += 1; print("  ❌ \(name): \(error)") }
}

// Each test uses an isolated UserDefaults suite
func makeSuite() -> UserDefaults {
    let name = "notchblock-test-prefs-\(UUID().uuidString)"
    let suite = UserDefaults(suiteName: name)!
    suite.removePersistentDomain(forName: name)
    return suite
}

print("=== PetPreferences Tests ===")

// ── Default values ─────────────────────────────────────────────────
test("isEnabled defaults to true") {
    let prefs = PetPreferences(defaults: makeSuite())
    assert(prefs.isEnabled == true)
}

test("selectedPet defaults to 'elysia'") {
    let prefs = PetPreferences(defaults: makeSuite())
    assert(prefs.selectedPet == "elysia")
}

test("hideInFullscreen defaults to false") {
    let prefs = PetPreferences(defaults: makeSuite())
    assert(prefs.hideInFullscreen == false)
}

test("idleSleepMinutes defaults to 5") {
    let prefs = PetPreferences(defaults: makeSuite())
    assert(prefs.idleSleepMinutes == 5)
}

test("positionX defaults to 0 when no value stored") {
    let prefs = PetPreferences(defaults: makeSuite())
    assert(prefs.positionX == 0)
}

test("positionY defaults to 0 when no value stored") {
    let prefs = PetPreferences(defaults: makeSuite())
    assert(prefs.positionY == 0)
}

// ── Read / Write ───────────────────────────────────────────────────
test("can set and get isEnabled") {
    let suite = makeSuite()
    var prefs = PetPreferences(defaults: suite)
    prefs.isEnabled = false
    assert(prefs.isEnabled == false)
    // Verify persistence via a new instance
    let prefs2 = PetPreferences(defaults: suite)
    assert(prefs2.isEnabled == false)
}

test("can set and get selectedPet") {
    let suite = makeSuite()
    var prefs = PetPreferences(defaults: suite)
    prefs.selectedPet = "test-pet"
    assert(prefs.selectedPet == "test-pet")
    let prefs2 = PetPreferences(defaults: suite)
    assert(prefs2.selectedPet == "test-pet")
}

test("can set and get positionX") {
    let suite = makeSuite()
    var prefs = PetPreferences(defaults: suite)
    prefs.positionX = 500.0
    assert(prefs.positionX == 500.0)
}

test("can set and get positionY") {
    let suite = makeSuite()
    var prefs = PetPreferences(defaults: suite)
    prefs.positionY = 300.0
    assert(prefs.positionY == 300.0)
}

test("can set and get hideInFullscreen") {
    let suite = makeSuite()
    var prefs = PetPreferences(defaults: suite)
    prefs.hideInFullscreen = true
    assert(prefs.hideInFullscreen == true)
}

test("can set and get idleSleepMinutes") {
    let suite = makeSuite()
    var prefs = PetPreferences(defaults: suite)
    prefs.idleSleepMinutes = 10
    assert(prefs.idleSleepMinutes == 10)
}

test("all 6 keys persist independently") {
    let suite = makeSuite()
    var prefs = PetPreferences(defaults: suite)
    prefs.isEnabled = false
    prefs.selectedPet = "custom"
    prefs.positionX = 100.5
    prefs.positionY = 200.5
    prefs.hideInFullscreen = true
    prefs.idleSleepMinutes = 15

    let prefs2 = PetPreferences(defaults: suite)
    assert(prefs2.isEnabled == false)
    assert(prefs2.selectedPet == "custom")
    assert(prefs2.positionX == 100.5)
    assert(prefs2.positionY == 200.5)
    assert(prefs2.hideInFullscreen == true)
    assert(prefs2.idleSleepMinutes == 15)
}

// ── Position clamping ──────────────────────────────────────────────
test("clampPosition keeps point within screen bounds") {
    let prefs = PetPreferences(defaults: makeSuite())
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let result = prefs.clampPosition(CGPoint(x: 500, y: 400), to: screen)
    assert(result.x == 500)
    assert(result.y == 400)
}

test("clampPosition clamps x below minimum") {
    let prefs = PetPreferences(defaults: makeSuite())
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let result = prefs.clampPosition(CGPoint(x: 5, y: 400), to: screen, margin: 20)
    assert(result.x == 20, "expected clamped to 20, got \(result.x)")
}

test("clampPosition clamps x above maximum") {
    let prefs = PetPreferences(defaults: makeSuite())
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let result = prefs.clampPosition(CGPoint(x: 2000, y: 400), to: screen, margin: 20)
    assert(result.x == 1420, "expected clamped to 1420, got \(result.x)")
}

test("clampPosition clamps y below minimum") {
    let prefs = PetPreferences(defaults: makeSuite())
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let result = prefs.clampPosition(CGPoint(x: 500, y: 5), to: screen, margin: 20)
    assert(result.y == 20, "expected clamped to 20, got \(result.y)")
}

test("clampPosition clamps y above maximum") {
    let prefs = PetPreferences(defaults: makeSuite())
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let result = prefs.clampPosition(CGPoint(x: 500, y: 950), to: screen, margin: 20)
    assert(result.y == 880, "expected clamped to 880, got \(result.y)")
}

test("clampPosition handles negative coordinates") {
    let prefs = PetPreferences(defaults: makeSuite())
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let result = prefs.clampPosition(CGPoint(x: -100, y: -50), to: screen, margin: 20)
    assert(result.x == 20)
    assert(result.y == 20)
}

test("clampPosition uses 20pt default margin") {
    let prefs = PetPreferences(defaults: makeSuite())
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let result = prefs.clampPosition(CGPoint(x: 0, y: 0), to: screen)
    assert(result.x == 20)
    assert(result.y == 20)
}

// ── Resolved position (fallback) ───────────────────────────────────
test("resolvedPosition falls back to bottom-right when no position stored") {
    let prefs = PetPreferences(defaults: makeSuite())
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let pos = prefs.resolvedPosition(fallbackScreenFrame: screen)
    assert(pos.x == 1420, "expected 1440-20=1420, got \(pos.x)")
    assert(pos.y == 880, "expected 900-20=880, got \(pos.y)")
}

test("resolvedPosition returns stored position when set") {
    let suite = makeSuite()
    var prefs = PetPreferences(defaults: suite)
    prefs.positionX = 300
    prefs.positionY = 400
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let pos = prefs.resolvedPosition(fallbackScreenFrame: screen)
    assert(pos.x == 300)
    assert(pos.y == 400)
}

test("resolvedPosition on secondary screen uses its coordinates") {
    let prefs = PetPreferences(defaults: makeSuite())
    let screen = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
    let pos = prefs.resolvedPosition(fallbackScreenFrame: screen)
    // bottom-right of secondary screen: x=1440+1920-20, y=1080-20
    assert(pos.x == 3340, "expected 1440+1920-20=3340, got \(pos.x)")
    assert(pos.y == 1060, "expected 1080-20=1060, got \(pos.y)")
}

// ── Reset position ─────────────────────────────────────────────────
test("resetPosition clears stored coordinates") {
    let suite = makeSuite()
    var prefs = PetPreferences(defaults: suite)
    prefs.positionX = 500
    prefs.positionY = 300
    prefs.resetPosition()
    assert(prefs.positionX == 0)
    assert(prefs.positionY == 0)
}

// ── Remove all ─────────────────────────────────────────────────────
test("removeAll clears all pet keys") {
    let suite = makeSuite()
    var prefs = PetPreferences(defaults: suite)
    prefs.isEnabled = false
    prefs.selectedPet = "x"
    prefs.positionX = 1
    prefs.positionY = 2
    prefs.hideInFullscreen = true
    prefs.idleSleepMinutes = 99
    prefs.removeAll()

    // All back to defaults
    let fresh = PetPreferences(defaults: suite)
    assert(fresh.isEnabled == true)
    assert(fresh.selectedPet == "elysia")
    assert(fresh.positionX == 0)
    assert(fresh.positionY == 0)
    assert(fresh.hideInFullscreen == false)
    assert(fresh.idleSleepMinutes == 5)
}

// ── Edge cases ─────────────────────────────────────────────────────
test("very large idleSleepMinutes is preserved") {
    let suite = makeSuite()
    var prefs = PetPreferences(defaults: suite)
    prefs.idleSleepMinutes = Int.max
    assert(prefs.idleSleepMinutes == Int.max)
}

test("positionX negative values are preserved (clamping is separate)") {
    let suite = makeSuite()
    var prefs = PetPreferences(defaults: suite)
    prefs.positionX = -500
    assert(prefs.positionX == -500)
}

print("\n\(passed)/\(passed+failed) passed")
exit(failed > 0 ? 1 : 0)
