# NotchBlock — 刘海时间块

macOS 时间块强制执行工具。将 Mac 硬件刘海转化为隐形交互入口，通过全屏遮罩强提醒保持专注。

## Stack

- **Language:** Swift 6.1
- **UI:** SwiftUI + AppKit (NSPanel, NSTrackingArea)
- **Persistence:** UserDefaults / JSON (via `TimeBlockStore`)
- **Min target:** macOS 14.0 (Sonoma)
- **Build tool:** Xcode 16.4 (project generated via `generate_xcode_project.py`)

## Build, Test & Release

```bash
# Regenerate Xcode project (required after adding/removing .swift files)
python3 generate_xcode_project.py

# Build
xcodebuild -project NotchBlock.xcodeproj -scheme NotchBlock -configuration Debug build

# Test (XCTest — requires AppKit; swift test won't work)
xcodebuild test -project NotchBlock.xcodeproj -scheme NotchBlock -destination 'platform=macOS'

# Release DMG
bash scripts/build-dmg.sh
```

Tests live in `Tests/`. `swift test` is unsupported — AppKit/CoreGraphics APIs (`NSPanel`, `CGWindowList`, etc.) can't link under SPM.

## ECC Agents

Installed under `.claude/agents/`. Key agents for this project:

| Agent | Use |
|-------|-----|
| `swift-reviewer` | Swift-specific code review |
| `swift-build-resolver` | Fix Xcode build / Swift compilation errors |
| `code-reviewer` | General code quality review |
| `security-reviewer` | Security vulnerability scan |
| `tdd-guide` | Test-driven development workflow |

## Development Workflow

```
Research → Red/Blue Adversarial → TDD → Implement → Review → Commit → Release
```

- **Research:** Search GitHub + docs before building. Use `/discovery` for product requirements.
- **Red/Blue:** Parallel agents argue *against* and *for* the feature. Verdict: Go / No-Go / Defer.
- **TDD:** `/ecc:tdd-guide` — write tests first, define acceptance criteria, break into tasks.
- **Implement:** RED → GREEN → REFACTOR. Many small files (200-400 lines, 800 max). Immutable data patterns.
- **Review:** `/ecc:code-review` + `swift-reviewer`. Fix ALL critical/high issues.
- **Commit:** Conventional commits (`feat:`, `fix:`, `refactor:`).
- **Release:** Tag semver, `scripts/build-dmg.sh`, GitHub Release + `CHANGELOG.md`.

## Context Management

- Auto-compact when context reaches 50%
- Before compact: commit all work, update `progress.html`
- After compact: resume from last committed state

## Adding Files

1. Create `.swift` file in the appropriate subdirectory (`Managers/`, `Models/`, `Views/`, `Utilities/`)
2. Add it to `files` list + group `children()` in `generate_xcode_project.py`
3. Run `python3 generate_xcode_project.py`

> `.claude/` files (rules, agents, skills, configs) do NOT need Xcode project registration.

## Key Architecture

| Component | Role |
|-----------|------|
| **NotchTracker** | Transparent borderless window at notch position, NSTrackingArea, 0.5s hover debounce. Mutual exclusion when main window is open. Disabled during fullscreen (CGWindowList). |
| **NotchPanelController** | NSPanel with `.nonactivatingPanel`. Dynamic height via `fittingSize`. 0.35s slide-in, 0.4s fade-out. Generation counter prevents show/hide race. |
| **NotchPanelView** | Read-only glance card: active task countdown (28pt), upcoming tasks (max 5, scrollable), empty state, tap-to-open-main-window. Timer via `Timer.publish(.common)`. |
| **OverlayWindowController** | `CGShieldingWindowLevel()` + `.fullScreenAuxiliary`. 5-min timeout → auto `.missed`. |
| **BlockScheduler** | 1s polling, triggers overlay when `.pending` block's `endTime` passes. |
| **TimeBlockStore** | UserDefaults ISO 8601 JSON. `@Published var blocks` for SwiftUI reactivity. |
