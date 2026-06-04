#!/usr/bin/env swift
import Foundation

// Mirror of TimeBlock model for isolated testing
struct TimeBlock: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String; var startTime: Date; var endTime: Date
    var status: BlockStatus; var notes: String; var isBreak: Bool
    init(id: UUID = UUID(), title: String, startTime: Date, endTime: Date,
         status: BlockStatus = .pending, notes: String = "", isBreak: Bool = false) {
        self.id = id; self.title = title; self.startTime = startTime
        self.endTime = endTime; self.status = status; self.notes = notes; self.isBreak = isBreak
    }
    var duration: TimeInterval { endTime.timeIntervalSince(startTime) }
    func overlaps(with other: TimeBlock) -> Bool { startTime < other.endTime && other.startTime < endTime }
    var hasValidTimeRange: Bool { startTime < endTime }
    func with(status: BlockStatus) -> TimeBlock {
        TimeBlock(id: id, title: title, startTime: startTime, endTime: endTime, status: status, notes: notes, isBreak: isBreak)
    }
    enum CodingKeys: String, CodingKey { case id, title, startTime, endTime, status, notes, isBreak }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        startTime = try c.decode(Date.self, forKey: .startTime)
        endTime = try c.decode(Date.self, forKey: .endTime)
        status = try c.decode(BlockStatus.self, forKey: .status)
        notes = (try? c.decode(String.self, forKey: .notes)) ?? ""
        isBreak = (try? c.decode(Bool.self, forKey: .isBreak)) ?? false
    }
}
enum BlockStatus: String, Codable, CaseIterable { case pending, completed, missed }

var passed = 0, failed = 0
func test(_ name: String, _ block: () throws -> Void) {
    do { try block(); passed += 1; print("  ✅ \(name)") }
    catch { failed += 1; print("  ❌ \(name): \(error)") }
}

let now = Date()
let b1 = TimeBlock(title: "A", startTime: now, endTime: now.addingTimeInterval(3600))

print("=== TimeBlock Model Tests ===")

test("overlap detection") { assert(b1.overlaps(with: TimeBlock(title: "B", startTime: now.addingTimeInterval(1800), endTime: now.addingTimeInterval(5400)))) }
test("non-overlap detection") { assert(!b1.overlaps(with: TimeBlock(title: "C", startTime: now.addingTimeInterval(3600), endTime: now.addingTimeInterval(7200)))) }
test("duration calculation") { assert(abs(b1.duration - 3600) < 1) }
test("valid time range") { assert(TimeBlock(title: "X", startTime: now, endTime: now.addingTimeInterval(3600)).hasValidTimeRange) }
test("invalid time range rejected") { assert(!TimeBlock(title: "Bad", startTime: now, endTime: now.addingTimeInterval(-1)).hasValidTimeRange) }

test("decodes v0.1.0 JSON (no notes/isBreak)") {
    let json = """
    [{"id":"A1B2C3D4-E5F6-7890-ABCD-EF1234567890","title":"Task","startTime":"2026-06-04T09:00:00Z","endTime":"2026-06-04T10:00:00Z","status":"pending"}]
    """
    let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
    let blocks = try d.decode([TimeBlock].self, from: json.data(using: .utf8)!)
    assert(blocks[0].notes == ""); assert(blocks[0].isBreak == false)
}

test("decodes v0.3.1 JSON (notes but no isBreak)") {
    let json = """
    [{"id":"A1B2C3D4-E5F6-7890-ABCD-EF1234567890","title":"Task","startTime":"2026-06-04T09:00:00Z","endTime":"2026-06-04T10:00:00Z","status":"pending","notes":"focus work"}]
    """
    let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
    let blocks = try d.decode([TimeBlock].self, from: json.data(using: .utf8)!)
    assert(blocks[0].notes == "focus work"); assert(blocks[0].isBreak == false)
}

test("with(status:) preserves notes + isBreak") {
    let b = TimeBlock(title: "A", startTime: now, endTime: now.addingTimeInterval(3600), notes: "important", isBreak: true)
    let c = b.with(status: .completed)
    assert(c.notes == "important"); assert(c.isBreak == true); assert(c.status == .completed)
}

test("Codable round-trip preserves all fields") {
    let original = TimeBlock(title: "Test", startTime: now, endTime: now.addingTimeInterval(3600), notes: "n", isBreak: true)
    let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    let data = try encoder.encode([original])
    let decoded = try decoder.decode([TimeBlock].self, from: data)
    assert(decoded[0].title == "Test"); assert(decoded[0].notes == "n"); assert(decoded[0].isBreak == true)
}

print("\n\(passed)/\(passed+failed) passed")
exit(failed > 0 ? 1 : 0)
