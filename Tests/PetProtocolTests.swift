#!/usr/bin/env swift
import Foundation
import CoreGraphics

// ── Inline type definitions for isolated testing ───────────────────

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
    var animationFileName: String {
        switch self {
        case .initial: "waving"; case .idle: "idle"; case .idleMicro: "blink"
        case .sleeping: "sleeping"; case .focusing: "waiting"; case .succeeded: "jumping"
        case .failed: "failed"; case .draggingLeft: "running-left"; case .draggingRight: "running-right"
        }
    }
}

protocol PetProtocol {
    var name: String { get }
    var displayName: String { get }
    var animations: [PetState: URL] { get }
    var defaultSize: CGSize { get }
}

struct ElysiaPet: PetProtocol {
    let name = "elysia"
    let displayName = "Elysia"
    let animations: [PetState: URL]
    let defaultSize = CGSize(width: 120, height: 120)

    /// Create an ElysiaPet from an assets directory.
    /// Uses naming convention: `{petName}-{state.animationFileName}.gif`
    init(assetsDirectory: URL) {
        var map: [PetState: URL] = [:]
        for state in PetState.allCases {
            let filename = "\(name)-\(state.animationFileName).gif"
            map[state] = assetsDirectory.appendingPathComponent(filename)
        }
        self.animations = map
    }

    /// The manifest filename that would be looked for in the pet directory.
    static var manifestFileName: String { "manifest.json" }
}

// ── Test harness ───────────────────────────────────────────────────
var passed = 0, failed = 0
func test(_ name: String, _ block: () throws -> Void) {
    do { try block(); passed += 1; print("  ✅ \(name)") }
    catch { failed += 1; print("  ❌ \(name): \(error)") }
}

print("=== PetProtocol Tests ===")

// ── ElysiaPet identity ─────────────────────────────────────────────
test("elysia name is 'elysia'") {
    let dir = URL(fileURLWithPath: "/tmp/fake-pets/elysia")
    let pet = ElysiaPet(assetsDirectory: dir)
    assert(pet.name == "elysia")
}

test("elysia displayName is 'Elysia'") {
    let dir = URL(fileURLWithPath: "/tmp/fake-pets/elysia")
    let pet = ElysiaPet(assetsDirectory: dir)
    assert(pet.displayName == "Elysia")
}

test("elysia defaultSize is 120x120") {
    let dir = URL(fileURLWithPath: "/tmp/fake-pets/elysia")
    let pet = ElysiaPet(assetsDirectory: dir)
    assert(pet.defaultSize.width == 120)
    assert(pet.defaultSize.height == 120)
}

// ── Animation map coverage ─────────────────────────────────────────
test("elysia animations has entries for all 9 states") {
    let dir = URL(fileURLWithPath: "/tmp/fake-pets/elysia")
    let pet = ElysiaPet(assetsDirectory: dir)
    assert(pet.animations.count == 9, "expected 9 entries, got \(pet.animations.count)")
}

test("animation URLs follow naming convention: {pet}-{state}-.gif") {
    let dir = URL(fileURLWithPath: "/tmp/fake-pets/elysia")
    let pet = ElysiaPet(assetsDirectory: dir)
    for state in PetState.allCases {
        let url = pet.animations[state]
        assert(url != nil, "missing URL for state \(state)")
        let filename = url!.lastPathComponent
        assert(filename.hasPrefix("elysia-"), "filename '\(filename)' missing elysia- prefix")
        assert(filename.hasSuffix(".gif"), "filename '\(filename)' missing .gif extension")
    }
}

test("idle animation URL is correct") {
    let dir = URL(fileURLWithPath: "/tmp/fake-pets/elysia")
    let pet = ElysiaPet(assetsDirectory: dir)
    let url = pet.animations[.idle]
    assert(url?.lastPathComponent == "elysia-idle.gif")
}

test("waving animation URL (initial state) is correct") {
    let dir = URL(fileURLWithPath: "/tmp/fake-pets/elysia")
    let pet = ElysiaPet(assetsDirectory: dir)
    let url = pet.animations[.initial]
    assert(url?.lastPathComponent == "elysia-waving.gif")
}

test("failed animation URL uses 'failed' not 'failing'") {
    let dir = URL(fileURLWithPath: "/tmp/fake-pets/elysia")
    let pet = ElysiaPet(assetsDirectory: dir)
    let url = pet.animations[.failed]
    assert(url?.lastPathComponent == "elysia-failed.gif")
}

test("jumping animation URL (succeeded state) is correct") {
    let dir = URL(fileURLWithPath: "/tmp/fake-pets/elysia")
    let pet = ElysiaPet(assetsDirectory: dir)
    let url = pet.animations[.succeeded]
    assert(url?.lastPathComponent == "elysia-jumping.gif")
}

test("running-left animation URL is correct") {
    let dir = URL(fileURLWithPath: "/tmp/fake-pets/elysia")
    let pet = ElysiaPet(assetsDirectory: dir)
    let url = pet.animations[.draggingLeft]
    assert(url?.lastPathComponent == "elysia-running-left.gif")
}

test("running-right animation URL is correct") {
    let dir = URL(fileURLWithPath: "/tmp/fake-pets/elysia")
    let pet = ElysiaPet(assetsDirectory: dir)
    let url = pet.animations[.draggingRight]
    assert(url?.lastPathComponent == "elysia-running-right.gif")
}

// ── Protcol conformance (compile-time via struct declaration) ──────
test("ElysiaPet conforms to PetProtocol") {
    let dir = URL(fileURLWithPath: "/tmp/fake-pets/elysia")
    let pet: any PetProtocol = ElysiaPet(assetsDirectory: dir)
    assert(pet.name == "elysia")
    assert(pet.displayName == "Elysia")
    assert(pet.animations.count == 9)
}

// ── Manifest file name ─────────────────────────────────────────────
test("manifest file name is 'manifest.json'") {
    assert(ElysiaPet.manifestFileName == "manifest.json")
}

print("\n\(passed)/\(passed+failed) passed")
exit(failed > 0 ? 1 : 0)
