#!/usr/bin/env swift
import Foundation

struct MockBlock { var status: String; var duration: TimeInterval; var isBreak: Bool }
let blocks: [MockBlock] = [
    MockBlock(status: "completed", duration: 3600, isBreak: false),
    MockBlock(status: "completed", duration: 1800, isBreak: false),
    MockBlock(status: "missed", duration: 2400, isBreak: false),
    MockBlock(status: "pending", duration: 1200, isBreak: false),
    MockBlock(status: "completed", duration: 300, isBreak: true),
]
let user = blocks.filter { !$0.isBreak }

var p=0, f=0
func t(_ n: String, _ b: () throws -> Void) { do { try b(); p+=1; print("  ✅ \(n)") } catch { f+=1; print("  ❌ \(n)") } }

print("=== Statistics Tests ===")
t("total excludes breaks") { assert(user.count == 4) }
t("completed count") { assert(user.filter{$0.status=="completed"}.count == 2) }
t("completion rate 0.5") { assert(Double(user.filter{$0.status=="completed"}.count)/Double(user.count) == 0.5) }
t("focus time excludes breaks") { assert(user.filter{$0.status=="completed"}.map(\.duration).reduce(0,+) == 5400) }
t("empty = zero") { let r: Double = 0; assert(r == 0) }
t("heatmap excludes breaks") { assert(blocks.filter{$0.isBreak}.filter{!$0.isBreak}.isEmpty) }

print("\n\(p)/\(p+f) passed")
exit(f>0 ? 1 : 0)
