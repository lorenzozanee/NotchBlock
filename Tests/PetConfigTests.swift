#!/usr/bin/env swift
import Foundation

// ── Inline type definitions for isolated testing ───────────────────

enum PetState: Int, Comparable, CaseIterable {
    case initial = 0; case idle = 1; case idleMicro = 2; case sleeping = 3
    case focusing = 4; case succeeded = 5; case failed = 6
    case draggingLeft = 7; case draggingRight = 8
    static func < (lhs: PetState, rhs: PetState) -> Bool { lhs.rawValue < rhs.rawValue }
    var animationFileName: String {
        switch self {
        case .initial: "waving"; case .idle: "idle"; case .idleMicro: "blink"
        case .sleeping: "sleeping"; case .focusing: "waiting"; case .succeeded: "jumping"
        case .failed: "failed"; case .draggingLeft: "running-left"; case .draggingRight: "running-right"
        }
    }
    /// State key used as JSON dictionary key in manifest files.
    var manifestKey: String {
        switch self {
        case .initial: "initial"; case .idle: "idle"; case .idleMicro: "idleMicro"
        case .sleeping: "sleeping"; case .focusing: "focusing"; case .succeeded: "succeeded"
        case .failed: "failed"; case .draggingLeft: "draggingLeft"; case .draggingRight: "draggingRight"
        }
    }
}

// ── PetConfig ──────────────────────────────────────────────────────

struct PetConfig: Codable, Equatable {
    let name: String
    let displayName: String
    /// Maps state manifest key → GIF filename (e.g. "idle" → "elysia-idle.gif")
    let animationFiles: [String: String]

    enum CodingKeys: String, CodingKey {
        case name, displayName, animationFiles = "animations"
    }

    init(name: String, displayName: String, animationFiles: [String: String]) {
        self.name = name
        self.displayName = displayName
        self.animationFiles = animationFiles
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        displayName = (try? c.decode(String.self, forKey: .displayName)) ?? name
        animationFiles = (try? c.decode([String: String].self, forKey: .animationFiles)) ?? [:]
    }

    /// Resolve a GIF URL for the given state.
    /// 1. If manifest has an explicit mapping, use it.
    /// 2. Otherwise, fall back to naming convention: `{petName}-{state.animationFileName}.gif`
    func url(for state: PetState, in directory: URL) -> URL {
        if let filename = animationFiles[state.manifestKey] {
            return directory.appendingPathComponent(filename)
        }
        // Naming convention fallback
        let fallback = "\(name)-\(state.animationFileName).gif"
        return directory.appendingPathComponent(fallback)
    }

    /// Load config from a pet directory.
    /// Returns nil if manifest JSON is missing or malformed.
    static func load(petName: String, from directory: URL) -> PetConfig? {
        let manifestURL = directory.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: manifestURL) else {
            // No manifest — build from naming convention
            return PetConfig(name: petName, displayName: petName, animationFiles: [:])
        }
        guard let config = try? JSONDecoder().decode(PetConfig.self, from: data) else {
            return nil
        }
        return config
    }

    /// Default manifest file name inside each pet directory.
    static let manifestFileName = "manifest.json"
}

// ── Test harness ───────────────────────────────────────────────────
var passed = 0, failed = 0
func test(_ name: String, _ block: () throws -> Void) {
    do { try block(); passed += 1; print("  ✅ \(name)") }
    catch { failed += 1; print("  ❌ \(name): \(error)") }
}

// Helper to create a temp directory with a manifest file
func makeTempDirWithManifest(_ json: String, petName: String = "elysia") throws -> URL {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("notchblock-test-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    let manifestURL = tmp.appendingPathComponent("manifest.json")
    try json.write(to: manifestURL, atomically: true, encoding: .utf8)
    return tmp
}

print("=== PetConfig Tests ===")

// ── Valid manifest parsing ─────────────────────────────────────────
test("parses valid manifest JSON with name and displayName") {
    let json = #"{"name":"elysia","displayName":"Elysia","animations":{"idle":"elysia-idle.gif"}}"#
    let data = json.data(using: .utf8)!
    let config = try JSONDecoder().decode(PetConfig.self, from: data)
    assert(config.name == "elysia")
    assert(config.displayName == "Elysia")
}

test("parses manifest with full animation mapping") {
    let json = """
    {
        "name": "elysia",
        "displayName": "Elysia",
        "animations": {
            "initial": "elysia-waving.gif",
            "idle": "elysia-idle.gif",
            "idleMicro": "elysia-blink.gif",
            "sleeping": "elysia-sleeping.gif",
            "focusing": "elysia-waiting.gif",
            "succeeded": "elysia-jumping.gif",
            "failed": "elysia-failed.gif",
            "draggingLeft": "elysia-running-left.gif",
            "draggingRight": "elysia-running-right.gif"
        }
    }
    """
    let data = json.data(using: .utf8)!
    let config = try JSONDecoder().decode(PetConfig.self, from: data)
    assert(config.animationFiles.count == 9)
    assert(config.animationFiles["idle"] == "elysia-idle.gif")
    assert(config.animationFiles["failed"] == "elysia-failed.gif")
    assert(config.animationFiles["draggingLeft"] == "elysia-running-left.gif")
}

test("displayName falls back to name when missing") {
    let json = #"{"name":"elysia","animations":{}}"#
    let data = json.data(using: .utf8)!
    let config = try JSONDecoder().decode(PetConfig.self, from: data)
    assert(config.displayName == "elysia")
}

test("animations field defaults to empty when missing") {
    let json = #"{"name":"elysia","displayName":"Elysia"}"#
    let data = json.data(using: .utf8)!
    let config = try JSONDecoder().decode(PetConfig.self, from: data)
    assert(config.animationFiles.isEmpty)
}

// ── URL resolution ─────────────────────────────────────────────────
test("url resolution uses manifest mapping when available") {
    let dir = URL(fileURLWithPath: "/tmp/fake-pets/elysia")
    let config = PetConfig(name: "elysia", displayName: "Elysia", animationFiles: [
        "idle": "custom-idle.gif"
    ])
    let url = config.url(for: .idle, in: dir)
    assert(url.lastPathComponent == "custom-idle.gif")
}

test("url resolution falls back to naming convention for unmapped state") {
    let dir = URL(fileURLWithPath: "/tmp/fake-pets/elysia")
    let config = PetConfig(name: "elysia", displayName: "Elysia", animationFiles: [:])
    let url = config.url(for: .idle, in: dir)
    assert(url.lastPathComponent == "elysia-idle.gif")
}

test("url resolution falls back to naming convention for failed state") {
    let dir = URL(fileURLWithPath: "/tmp/fake-pets/elysia")
    let config = PetConfig(name: "elysia", displayName: "Elysia", animationFiles: [:])
    let url = config.url(for: .failed, in: dir)
    assert(url.lastPathComponent == "elysia-failed.gif")
}

test("url resolution: all 9 states produce non-empty filenames via fallback") {
    let dir = URL(fileURLWithPath: "/tmp/fake-pets/elysia")
    let config = PetConfig(name: "elysia", displayName: "Elysia", animationFiles: [:])
    for state in PetState.allCases {
        let url = config.url(for: state, in: dir)
        let filename = url.lastPathComponent
        assert(!filename.isEmpty, "empty filename for \(state)")
        assert(filename.hasSuffix(".gif"), "\(filename) missing .gif")
    }
}

// ── Load from manifest file ────────────────────────────────────────
test("load returns config from valid manifest file") {
    let json = #"{"name":"testpet","displayName":"Test Pet","animations":{"idle":"test-idle.gif"}}"#
    let tmp = try makeTempDirWithManifest(json, petName: "testpet")
    defer { try? FileManager.default.removeItem(at: tmp) }

    let config = PetConfig.load(petName: "testpet", from: tmp)
    assert(config != nil)
    assert(config?.name == "testpet")
    assert(config?.displayName == "Test Pet")
    assert(config?.animationFiles["idle"] == "test-idle.gif")
}

test("load falls back to naming convention when no manifest file exists") {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("notchblock-nomanifest-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let config = PetConfig.load(petName: "elysia", from: tmp)
    assert(config != nil, "config should not be nil (falls back to convention)")
    assert(config?.name == "elysia")
    assert(config?.animationFiles.isEmpty == true, "should have empty mapping")
}

test("load returns nil for malformed JSON") {
    let json = "{ this is not valid }"
    let tmp = try makeTempDirWithManifest(json, petName: "bad")
    defer { try? FileManager.default.removeItem(at: tmp) }

    let config = PetConfig.load(petName: "bad", from: tmp)
    assert(config == nil)
}

test("load returns nil for empty JSON file") {
    let tmp = try makeTempDirWithManifest("", petName: "empty")
    defer { try? FileManager.default.removeItem(at: tmp) }

    let config = PetConfig.load(petName: "empty", from: tmp)
    assert(config == nil)
}

// ── Equatable ──────────────────────────────────────────────────────
test("identical configs are equal") {
    let a = PetConfig(name: "x", displayName: "X", animationFiles: ["idle": "x-idle.gif"])
    let b = PetConfig(name: "x", displayName: "X", animationFiles: ["idle": "x-idle.gif"])
    assert(a == b)
}

test("different configs are not equal") {
    let a = PetConfig(name: "a", displayName: "A", animationFiles: [:])
    let b = PetConfig(name: "b", displayName: "B", animationFiles: [:])
    assert(a != b)
}

// ── Manifest file name constant ────────────────────────────────────
test("manifestFileName is 'manifest.json'") {
    assert(PetConfig.manifestFileName == "manifest.json")
}

print("\n\(passed)/\(passed+failed) passed")
exit(failed > 0 ? 1 : 0)
