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
Discovery → Deep Research → Red/Blue Adversarial → TDD → Implement → Review → Commit → Release
```

### 0. Discovery — 需求发现 (`/discovery`)

将自然语言需求转化为锁定的需求文档 v2。三步走：
1. **Phase 1** — 需求分析师三层追问（必问题 → 关键词追问 → 功能畅想），输出 `docs/discovery/requirements-v1.md`
2. **Phase 2** — 并行审查（一致性审查 + 可行性审查）
3. **Phase 3** — 合并审查意见，输出锁定的 `docs/discovery/requirements-v2.md`

适用：新功能、大重构、产品方向调整。小改动跳过此阶段。

### 1. Deep Research — 双轨调研 (`/deep-research` + `mgrep --web`)

**必须执行**，禁止跳过。需求文档 v2 锁定后，启动双轨并行调研：

#### Track A: 产品调研（PM 视角 — `mgrep --web` + `/deep-research`）
- **竞品对比**: 同类 macOS 工具的功能矩阵、UX 模式、定价策略
- **需求验证**: 目标用户真实痛点、社区反馈（Reddit、V2EX、GitHub Issues）
- **市场定位**: 差异化切入点、未被覆盖的场景

#### Track B: 技术调研（工程师视角 — `/deep-research`）
- **开源项目检索**: GitHub 搜索同类实现、可复用的库/框架
- **技术方案对比**: API 选型 tradeoff、性能基准、兼容性矩阵
- **Apple 文档深挖**: HIG、AppKit 最佳实践、macOS 版本兼容性

**输出**: `docs/research/` 下的调研报告，包含竞品矩阵、技术选型建议、风险标注。Red/Blue 阶段引用此报告。

### 2. Red/Blue Adversarial

并行启动两个 Agent，分别论证 *反对* 和 *支持* 该功能。结合 Deep Research 报告交叉验证。最终裁决：Go / No-Go / Defer。

### 3. TDD

`/ecc:tdd-guide` — 写测试先行，定义验收标准，拆分为任务。确保 80%+ 覆盖率。

### 4. Implement

RED → GREEN → REFACTOR。许多小文件（200-400 行，800 上限）。不可变数据模式。

### 5. Review

`/ecc:code-review` + `swift-reviewer`。修复所有 CRITICAL/HIGH 问题。

### 6. Commit

Conventional commits (`feat:`, `fix:`, `refactor:`)。

### 7. Release

Tag semver, `scripts/build-dmg.sh`, GitHub Release + `CHANGELOG.md`。

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
