# NotchBlock — 刘海时间块

macOS 时间块强制执行工具。将 Mac 硬件刘海转化为隐形交互入口，通过全屏遮罩强提醒保持专注。

## Stack

- **Language:** Swift 6.1
- **UI:** SwiftUI + AppKit (NSPanel, NSTrackingArea)
- **Persistence:** UserDefaults / JSON (via `TimeBlockStore`)
- **Min target:** macOS 14.0 (Sonoma)
- **Build tool:** Xcode 16.4 (project generated via `generate_xcode_project.py`)

## Build & Release

```bash
python3 generate_xcode_project.py        # Regenerate Xcode project
xcodebuild -project NotchBlock.xcodeproj -scheme NotchBlock -configuration Debug build
bash scripts/build-dmg.sh                # Build Release + DMG
```

## Development Workflow (MANDATORY CYCLE)

每个功能迭代必须严格遵循此循环：

```
Product Research → Red/Blue Adversarial → TDD Plan → Implement → Code Review → Git Commit → HTML Visualize → Release
```

### Phase 0: Product Research (产品调研)
- Use **Explore agents** to research competing products, technical feasibility, user needs
- Use **ecc:planner** agent to evaluate market fit and scope
- Search GitHub for existing implementations before building new

### Phase 1: Red/Blue Adversarial Analysis (红蓝对抗)
- **RED team:** Argue why the feature will fail — technical blockers, UX problems, scope creep, maintenance burden
- **BLUE team:** Defend the feature — user value, feasibility, competitive advantage
- **VERDICT:** Go / No-Go / Defer with concrete reasoning
- Use parallel agents with opposing prompts for genuine adversarial analysis

### Phase 2: TDD Plan (测试驱动规划)
- Use **ecc:tdd-guide** agent
- Write test specifications FIRST
- Define acceptance criteria
- Break into granular tasks

### Phase 3: Implement (实现)
- Write tests first (RED) → Implement (GREEN) → Refactor (IMPROVE)
- Files: MANY SMALL FILES > FEW LARGE FILES (200-400 lines, 800 max)
- Immutability: NEVER mutate, ALWAYS create new instances
- Follow existing patterns in the codebase

### Phase 4: Code Review (代码审查)
- Use **ecc:code-reviewer** for general quality
- Use **ecc:swift-reviewer** for Swift-specific issues
- Fix ALL critical and high issues before proceeding

### Phase 5: Git Archive (存档)
- `git commit` with conventional commit format (`feat:`, `fix:`, `refactor:`)
- Commit message MUST describe what changed and WHY

### Phase 6: HTML Visualization (可视化)
- Update `progress.html` with new version, features, AC status
- Visual diff from previous version

### Phase 7: Release (发布)
- Tag with semantic versioning (`v0.2.0`, `v0.3.0`, …)
- Build signed DMG via `scripts/build-dmg.sh`
- GitHub Release with changelog

## Agent Usage

ALWAYS use agents for:
- **Research/Exploration:** Explore agents (parallel fan-out)
- **Planning:** ecc:planner
- **Testing:** ecc:tdd-guide
- **Review:** ecc:code-reviewer, ecc:swift-reviewer, ecc:security-reviewer
- **Quality:** ecc:code-simplifier, ecc:silent-failure-hunter

## Context Management

- Auto-compact when context reaches 50%
- Before compact: commit all work, update progress.html
- After compact: resume from the last committed state

## Project Structure

```
NotchBlock/
├── Models/               TimeBlock · BlockStatus
├── Managers/             TimeBlockStore · NotchTracker · NotchPanelController
│                         OverlayWindowController · BlockScheduler
├── Views/                MainSchedulerView · TimeBlockRowView · AddEditBlockView
│                         NotchPanelView · OverlayView
├── Utilities/            DateExtensions · LaunchManager
├── Resources/            Assets.xcassets (AppIcon)
├── scripts/              build-dmg.sh
├── CLAUDE.md             This file
├── progress.html         Development dashboard
├── CHANGELOG.md          Release history
└── entitlements.plist    Code signing entitlements
```

## Adding Files

1. Create `.swift` file in the appropriate subdirectory
2. Add it to `files` list + group `children()` in `generate_xcode_project.py`
3. Run `python3 generate_xcode_project.py`

## Key Architecture Notes

- **NotchTracker** — transparent borderless window at notch position with NSTrackingArea. 0.5s hover debounce. Disabled during fullscreen (CGWindowList).
- **NotchPanelController** — NSPanel with `.nonactivatingPanel`. Floats without stealing focus.
- **OverlayWindowController** — `CGShieldingWindowLevel()` + `.fullScreenAuxiliary`. 5-min timeout → auto `.missed`.
- **BlockScheduler** — 1s polling, triggers overlay when `.pending` block's `endTime` passes.
- **TimeBlockStore** — UserDefaults ISO 8601 JSON. `@Published var blocks` for SwiftUI reactivity.
