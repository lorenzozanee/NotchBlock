# Consistency Review Report

## Summary
- Requirements reviewed: 22 (14 user stories + 8 functional requirements)
- Conflicts found: 4
- Ambiguities found: 12
- Gaps found: 11
- Dependency mismatches: 2
- **Verdict**: FAIL — must resolve CONFLICT-1, DEP-1, and at minimum the P0-blocking AMBIG/GAP items before locking v2.

---

## Conflicts

### CONFLICT-1: Default fullscreen visibility — F1 vs P1-2
- **R1 (F1, Layer)**: "高于桌面壁纸，低于全屏 App（除非用户允许全屏显示）" — pet window sits BELOW fullscreen apps by default.
- **R2 (P1-2 user story)**: "全屏/遮罩时也能看到宠物，so that 专注过程中陪伴不中断" — pet MUST be visible during fullscreen/overlay so focus companionship is uninterrupted.
- **Why they conflict**: F1 encodes "below fullscreen" as the architectural default. P1-2 asserts the opposite as a P1 requirement. If the pet window is below fullscreen apps, the P1-2 user story is unfulfillable without a code change to raise the window level. F1's parenthetical "(除非用户允许全屏显示)" suggests a per-user opt-in, but P1-2 frames this as the DEFAULT behavior ("也能看到"), not an opt-in. P2-3 then adds a separate opt-OUT, creating a three-way pull: F1 default=hidden, P1-2 default=visible, P2-3 toggle=user-controlled.
- **Suggested resolution**: Align F1's default with P1-2. Change F1's layer spec to: "默认高于全屏 App（使用 `.fullScreenAuxiliary` collection behavior，与现有 OverlayWindowController 一致），用户可通过 `pet.hideInFullscreen` 偏好选择隐藏。" This makes P1-2 the default, P2-3 the override, and aligns with the existing `OverlayWindowController` pattern (`CGShieldingWindowLevel` + `.fullScreenAuxiliary`).

### CONFLICT-2: P0-1 "始终可见" vs P0-5/F5 onboarding disable
- **R1 (P0-1)**: "桌面上有一个始终可见的宠物" — "始终可见" means "always visible."
- **R2 (P0-5)**: "在引导流程中选择是否启用宠物，so that 不需要宠物的人可以关闭它" — user can disable pet entirely.
- **Why they conflict**: "始终" (always) is absolute language that conflicts with the opt-out mechanism. If the user opts out in onboarding, the pet is never visible, violating P0-1's literal guarantee.
- **Suggested resolution**: Reword P0-1 to: "当宠物功能启用时，桌面上有一个持续可见的宠物" — scope the "always" to the enabled state. This is a wording fix, not a design change.

### CONFLICT-3: P1-2 "visible during overlay" vs existing OverlayWindowController behavior
- **R1 (P1-2)**: Pet should be visible even during fullscreen/overlay.
- **R2 (Existing OverlayWindowController)**: The overlay uses `CGShieldingWindowLevel()` — the highest possible window level. If the pet uses a lower level, it will be occluded by the overlay. If the pet uses the same or higher level, it could appear ABOVE the overlay, potentially obscuring overlay buttons.
- **Why they conflict**: The overlay is a hard-interrupt mechanism (AC 3.1) designed to cover ALL content. Showing the pet above or alongside the overlay could either (a) break the overlay's purpose by creating unblocked click targets, or (b) render the pet invisible despite P1-2's requirement.
- **Suggested resolution**: Define pet z-order relative to overlay explicitly. Recommendation: pet appears at the same level as the overlay but in a non-interactive corner zone during overlay, or the pet is visible but `.ignoresMouseEvents = true` during overlay to prevent interaction bypass. Add an explicit requirement: "宠物在遮罩叠加层之上可见但不拦截点击事件（遮罩优先级不可绕过）。"

### CONFLICT-4: F2 animation priority list omits `initial` and `sleeping` states
- **R1 (F2 Edge case)**: "多个状态同时触发时的优先级：dragging > failed/succeeded > focusing > idle"
- **R2 (F2 state table)**: Defines 8 states: `initial`, `focusing`, `failed`, `succeeded`, `dragging-left`, `dragging-right`, `idle-micro`, `sleeping`.
- **Why they conflict**: The priority list uses `idle` but the state table has `idle-micro` and no `idle`. The `initial` and `sleeping` states are entirely absent from the priority chain. If the pet is in `initial` (waving) and a focus session starts, which wins? If the pet is `sleeping` and the user starts dragging, does dragging override sleep?
- **Suggested resolution**: Rewrite the priority chain to include all 8 states: `dragging-left/dragging-right > failed > succeeded > focusing > sleeping > idle-micro > initial`. Add a clarification that `sleeping` is interruptible by user interaction; `initial` is the lowest priority and transitions to `focusing` or `idle-micro` on first interaction.

---

## Ambiguities

### AMBIG-1: P0-1 "始终可见" is unmeasurable
- **Requirement**: "桌面上有一个始终可见的宠物"
- **Problem**: "始终" (always) is absolute without qualification. When exactly is the pet visible? During screen saver? Lock screen? When other NotchBlock windows are open? When the overlay is shown? The qualifier "App 运行期间" in the success criteria helps, but the user story itself omits this boundary.
- **Suggested rewrite**: "当 NotchBlock 运行且宠物功能启用时，宠物窗口在桌面层持续可见（跨所有 Spaces），例外场景见 F1 边界情况。"

### AMBIG-2: F2 `idle-micro` trigger interval undefined
- **Requirement**: F2 states "空闲时随机触发" for `idle-micro` animations (blink, stretch).
- **Problem**: "随机" without a frequency range is unmeasurable. Is it every 2 seconds? Every 30 seconds? Random between 3 and 15 seconds? Without a range, a test cannot validate correctness — any implementation is "correct" by the spec, including once per hour or 60 times per second.
- **Suggested rewrite**: "空闲时每隔 8-20 秒随机触发一次微动作动画（每次间隔在 8-20 秒范围内均匀随机选取）。"

### AMBIG-3: F2 `idle-micro` duration "短暂" undefined
- **Requirement**: F2 duration column says "短暂" for `idle-micro`.
- **Problem**: "短暂" (brief) is not a measurable duration. Animations in the state table have either concrete durations (60s, "循环至首次交互", "专注期间持续") or this one ambiguous adjective.
- **Suggested rewrite**: "持续时间: 动画文件自身时长（播放一次，不循环），约 1-3 秒。"

### AMBIG-4: F8 "N 分钟" for idle sleep threshold unbound
- **Requirement**: F8: "Mac N 分钟无操作后宠物进入睡眠动画。" Open question suggests 5 minutes.
- **Problem**: N is a variable placeholder, not a locked requirement. The open questions section acknowledges this but the spec body must resolve it. A requirement with a free variable cannot be implemented.
- **Suggested rewrite**: "Mac 5 分钟无用户输入操作后宠物进入睡眠动画。（可通过 `pet.idleSleepMinutes` UserDefaults key 配置，默认 5。）"

### AMBIG-5: F3 hover "亮度提升" undefined
- **Requirement**: F3: "宠物轻微放大（1.1x）+ 亮度提升，离开时恢复"
- **Problem**: "亮度提升" (brightness increase) has no quantitative spec. Is it a Core Image filter? Opacity change? Saturation boost? The 1.1x scale is measurable but the brightness component is not.
- **Suggested rewrite**: "鼠标悬停时宠物缩放至 1.1x 且 alpha 从 0.85 提升至 1.0；鼠标离开时 0.2s ease-out 恢复至原始 scale 1.0 和 alpha 0.85。"

### AMBIG-6: F6 "默认右下角" undefined for multi-monitor
- **Requirement**: F6: "首次启动无位置数据 → 默认右下角"
- **Problem**: "右下角" of which screen? On a multi-monitor setup, which monitor's bottom-right? Does it respect the notch screen? Is it relative to the visible frame (excluding Dock) or the full screen frame?
- **Suggested rewrite**: "首次启动无位置数据 → 默认位于主显示器可见区域（排除 Dock 和菜单栏）右下角，距右边缘 20pt、距下边缘 20pt。"

### AMBIG-7: P1-5 "撒花粒子" entirely un-specified
- **Requirement**: P1-5: "专注完成时有庆祝动画（跳跃+撒花粒子）"; F2 `succeeded` state: "jumping (+ 粒子特效)"
- **Problem**: "撒花粒子" is a significant visual feature mentioned in both a P1 user story and a core F2 state, yet has zero specification: no particle count, no animation duration, no rendering technology (SpriteKit? CAEmitterLayer? Canvas?), no color palette, no z-order relative to other windows.
- **Suggested rewrite**: "专注成功时播放跳跃 GIF 动画并触发粒子特效：使用 CAEmitterLayer，发射 30-50 个彩色五角星/圆形粒子，从宠物位置向上抛洒，持续 3 秒，粒子不拦截鼠标事件，不超出宠物窗口 ±100pt 范围。"

### AMBIG-8: "支持多显示器" strategy undefined
- **Requirement**: NFR Compatibility: "支持多显示器"
- **Problem**: Does "support" mean the pet appears on exactly one monitor (which one?), or clones across all? The Open Questions ask this but the NFR asserts support without defining what support means. A test cannot verify "multi-monitor support."
- **Suggested rewrite**: "宠物窗口出现在主显示器上。用户可拖拽至任意副屏；位置按显示器独立记忆。不克隆到多屏。拔插显示器后位置钳制到当前可用屏幕区域。"

### AMBIG-9: "素材尺寸适中（50-150px）" — units unclear
- **Requirement**: Constraints & Assumptions: "GIF 素材尺寸适中（50-150px），无需缩放适配"
- **Problem**: "px" is ambiguous on Retina displays. Does 50-150px mean logical points (1x) or native pixels (@2x = 100-300 native)? If the GIF is 100 native pixels and displayed at 50 logical points on a @2x display, does that count as "within range" or "needs scaling"?
- **Suggested rewrite**: "GIF 素材逻辑尺寸 50-150pt（在 @2x 屏幕上对应 100-300 原生像素）。宠物窗口按素材原生尺寸显示，不做额外缩放。"

### AMBIG-10: P1-5 "专注完成" trigger definition vague
- **Requirement**: P1-5: "专注完成时有庆祝动画"
- **Problem**: "专注完成" is ambiguous in the NotchBlock context. Does this mean: a single time block marked as completed? A session (chain of blocks) ended? Every completed block regardless of context? The first completed block of the day?
- **Suggested rewrite**: "每当任一个时间块被标记为「完成」时触发庆祝动画（每次专注会话完成独立触发）。"

### AMBIG-11: F2 "60 秒" post-failed/succeeded behavior undefined
- **Requirement**: F2: `failed` state lasts 60 seconds, `succeeded` state lasts 60 seconds.
- **Problem**: What happens after the 60-second animation completes? Does the pet revert to `idle-micro`? `focusing` (if another block is active)? Stay in the last frame of the animation? Transition to a default idle? The state machine has no defined exit transitions for `failed` and `succeeded`.
- **Suggested rewrite**: "60 秒后自动过渡到 `idle-micro` 状态（若当前无活跃专注任务），或 `focusing` 状态（若有活跃专注任务）。过渡遵循 F2 边界的 `播放完当前循环再切换` 规则。"

### AMBIG-12: "空闲" (idle) definition differs between idl-micro and sleeping
- **Requirement**: F2 `idle-micro` trigger: "空闲时随机触发"; F8 `sleeping` trigger: "Mac N 分钟无操作后"
- **Problem**: Both use "空闲" but they define different detection criteria. F8 uses system-level idle (no mouse/keyboard input). Does `idle-micro` use the same system idle tracking, or does it mean "no pet interaction"? If both use system idle, how do they interact — does `idle-micro` run during the N minutes before sleep kicks in?
- **Suggested rewrite**: "`idle-micro` 和 `sleeping` 共享同一系统空闲检测器：0-N 分钟无用户操作时随机触发 `idle-micro`（每 8-20s）；达到 N 分钟阈值后持续播放 `sleeping`（不再触发 `idle-micro`）。用户恢复操作时退出 `sleeping` 并播放一次 waving。"

---

## Gaps

### GAP-1: No default non-focusing idle state
- **What's missing**: After `initial` ends (first interaction), if the user is NOT in a focus session, there is no base idle state defined. `idle-micro` (P1) is an overlay with random triggers, not a persistent default state. The state machine has no `idle` baseline.
- **Why it matters**: Without a default idle, if a P1-only user (no `idle-micro`) opens the pet but never starts a focus session, the pet would be stuck in `initial` (waving forever) or have no animation at all. This breaks P0-1's "宠物反映专注状态" expectation for the non-focusing case.
- **Suggested addition**: Add an `idle` base state: "非专注期间的默认状态，宠物播放 idle GIF 循环。" Make it the post-`initial` default, preempted by `idle-micro` when enabled.

### GAP-2: Particle effect system is referenced but not defined as a functional requirement
- **What's missing**: P1-5 and F2 mention "粒子特效" but there is no F-x requirement defining the particle system architecture, rendering pipeline, or confetti animation spec.
- **Why it matters**: Without a requirement, the particle system may be built ad-hoc or skipped during implementation, making P1-5 unverifiable. If CAEmitterLayer is chosen, it has AppKit-specific integration concerns; if SpriteKit, it adds a dependency.
- **Suggested addition**: Add F9: "粒子特效系统 — 使用 CAEmitterLayer 实现撒花效果。粒子发射源锚定在宠物窗口坐标，粒子层添加在宠物窗口上方独立透明层，不拦截鼠标事件。支持配置粒子数量、颜色、持续时间。"

### GAP-3: No z-order specification relative to other NotchBlock windows
- **What's missing**: The requirements never specify whether the pet should appear above or below the NotchPanel (when opened via click), the Preferences window, or the overlay.
- **Why it matters**: If the pet appears above the NotchPanel, it could obscure panel content. If below, it might be hidden behind the panel. The click interaction (P0-2) opens the panel — should the pet remain visible or hide?
- **Suggested addition**: "宠物窗口层级：高于桌面壁纸，低于 NotchPanel 和主窗口，等于全屏遮罩（`.fullScreenAuxiliary`）。单击打开 NotchPanel 时，宠物保持在下方层不动。遮罩激活时宠物在遮罩之上但 `ignoresMouseEvents = true`。"

### GAP-4: No error recovery mechanism spec
- **What's missing**: NFR says "宠物窗口崩溃后自动恢复" but specifies no recovery mechanism, detection strategy, or recovery SLA.
- **Why it matters**: "自动恢复" without a mechanism is wishful thinking, not a requirement. A watcher process, internal retry loop, or AppKit window restoration are all different architectures with different tradeoffs.
- **Suggested addition**: "宠物窗口由 PetWindowController 管理。`NSWindow.didCloseNotification` 监听窗口关闭事件：若非用户主动隐藏（`pet.enabled == true`），在 1 秒内重建窗口并在原位置恢复。连续崩溃 3 次后停止恢复并写入 OSLog 错误。"

### GAP-5: No single-finger / other-gesture behavior spec
- **What's missing**: F3 specifies two-finger drag behavior but never defines what single-finger drag, three-finger drag, or force-click does on the pet.
- **Why it matters**: macOS interprets gesture counts differently. A single-finger drag might move the window unexpectedly if not explicitly handled. Force-click could trigger system Look Up. Without spec, the implementation may inadvertently allow behaviors that conflict with the intended two-finger gesture.
- **Suggested rewrite of F3 Edge case**: Add: "单指拖拽和三点以上手势不触发任何宠物行为（透传到下层）。Force-click 不触发系统查询功能。"

### GAP-6: No dark mode / appearance change consideration
- **What's missing**: The pet uses fixed GIF assets. There is no mention of how the pet should look in dark mode vs. light mode, or whether assets should be swapped.
- **Why it matters**: A brightly-colored pet GIF designed for a light desktop may look jarring or have halo artifacts on a dark desktop. The transparent borderless window may also render GIF edges differently in different appearance modes.
- **Suggested addition**: "宠物窗口背景始终透明。GIF 素材在深浅色模式下通用（素材设计需兼容两种桌面背景）。若未来需区分，支持通过 `PetManifest.json` 指定 `appearance: light | dark | universal`。"

### GAP-7: No specification for pet behavior during screen saver or lock screen
- **What's missing**: No requirement covers what the pet does when the screen saver activates or the user locks the screen.
- **Why it matters**: The pet at an elevated window level might appear ABOVE the lock screen (security risk) or the screen saver (ugly). Conversely, if it disappears, should it reappear on unlock at the same state?
- **Suggested addition**: "屏幕保护程序激活或屏幕锁定时，宠物窗口隐藏。解锁后宠物在原有位置恢复，动画重置为 `idle` 或当前活跃状态。"

### GAP-8: Pet switching UX flow across multiple entry points undefined
- **What's missing**: Pet selection can happen in onboarding (F5), right-click menu (F7), and presumably Preferences. But the interaction between these entry points is undefined — does onboarding offer a full preview? Does right-click switching require a confirmation dialog?
- **Why it matters**: Without a unified UX flow, each entry point may implement pet switching differently, leading to inconsistent user experience.
- **Suggested addition**: "宠物切换统一入口：① 引导流程（F5）：展示预览动图 + 单选列表，选择后进入主界面；② 右键菜单（F7）：列出可用宠物，点击即切换（无确认对话框），切换时播放 0.3s 过渡动画；③ Preferences > 宠物标签页：与引导流程相同的预览界面。所有入口操作写入同一 `pet.selected` UserDefaults key。"

### GAP-9: No battery / energy impact consideration
- **What's missing**: No non-functional requirement addresses battery impact. A continuously-looping GIF animation on a laptop could significantly drain battery.
- **Why it matters**: This is a desktop companion that runs "always" during focus sessions, which could be hours. Continuous GIF decoding and rendering at 10-30fps is a persistent energy cost not accounted for.
- **Suggested addition**: "NFR Performance: 宠物在 Mac 使用电池供电时，GIF 帧率降至 10fps；接入电源时恢复至原始帧率。空闲 30 秒无交互后降至 5fps。"

### GAP-10: No corrupted GIF handling spec
- **What's missing**: F2 edge case covers "素材缺失" (missing assets) but not corrupted/unreadable GIF files.
- **Why it matters**: A corrupt GIF in the `pets/` directory could crash the animation system or show garbled visuals. The difference between "missing" and "corrupt" requires different error handling.
- **Suggested addition**: "F2 Edge case 补充: GIF 文件存在但解码失败时，显示占位图形并输出 OSLog 错误，标记该动画状态为不可用，降级使用该宠物的 `idle` 动画替代。不崩溃。"

### GAP-11: No spec for animation file naming convention
- **What's missing**: F4 says "在 `pets/<pet-name>/` 放入对应动画 GIF 文件" but doesn't define the file naming convention. Does `waving.gif` map to the `initial` state? Is it `idle.gif` or `waiting.gif` for `focusing`?
- **Why it matters**: Without a naming convention, PetManifest.json must map every filename to every state, defeating F4's goal of "无需改代码." A convention reduces configuration burden.
- **Suggested addition**: "F4 补充: GIF 文件命名约定 — 文件名（不含扩展名）与 F2 状态表中的「动画」列名完全一致：`waving.gif`, `waiting.gif`, `idle.gif`, `failing.gif`, `jumping.gif`, `running-left.gif`, `running-right.gif`, `blink.gif`, `stretch.gif`, `sleeping.gif`。PetManifest.json 仅在动画名与约定不一致或需要额外映射时才需要声明。"

---

## Dependency Mismatches

### DEP-1: P1-5 celebration particle system has no functional requirement (P0-blocking)
- **Dependent requirement (P1)**: "专注完成时有庆祝动画（跳跃+撒花粒子）" — references a particle effect system.
- **Missing prerequisite**: No F-x requirement defines the particle system. F2 mentions "粒子特效" in the `succeeded` state row but doesn't define how it works. The particle system is undefined infrastructure that P1-5 depends on.
- **Suggested fix**: Add F9 ("粒子特效系统") as a P1 functional requirement. Without this, P1-5 cannot be implemented beyond the jumping GIF — the confetti component is vapor. Alternatively, if confetti is deferred, demote P1-5's "撒花粒子" to P2 and keep "跳跃动画" as P1.

### DEP-2: F2 `idle-micro` and F8 `sleeping` depend on idle detection infrastructure that is not defined as a requirement
- **Dependent requirements**: F2 `idle-micro` (P1) and F8 `sleeping` (P2) both depend on a system idle detection mechanism.
- **Missing prerequisite**: No F-x requirement defines the idle detection system — which API (`CGEventSourceSecondsSinceLastEventType`? `IOPMAssertion`?), polling frequency, or accuracy threshold. F8 mentions "监听系统空闲" but doesn't specify HOW.
- **Suggested fix**: Add a small requirement or add to F8: "使用 `CGEventSourceSecondsSinceLastEventType(kCGEventSourceStateHIDSystemState)` 轮询系统最后输入时间，每秒轮询一次。`idle-micro` 和 `sleeping` 共享同一检测器，避免重复轮询。"

---

## Orthogonality Matrix

Key: US1-US14 = user stories; F1-F8 = functional requirements

### User Stories vs User Stories

| | US1 | US2 | US3 | US4 | US5 | US6 | US7 | US8 | US9 | US10 | US11 | US12 | US13 | US14 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **US1** | - | OK | OK | OK | CONFLICT-2 | OK | OK | OK | OK | OK | OK | OK | OK | AMBIG-1 |
| **US2** | - | - | OK | OK | OK | OK | OK | OK | OK | OK | OK | OK | OK | OK |
| **US3** | - | - | - | OK | OK | OK | OK | OK | OK | OK | OK | OK | OK | OK |
| **US4** | - | - | - | - | OK | OK | OK | OK | OK | COMPLEMENT | OK | OK | OK | OK |
| **US5** | - | - | - | - | - | OK | OK | OK | OK | OK | OK | OK | OK | OK |
| **US6** | - | - | - | - | - | - | OK | OK | OK | OK | OK | OK | OK | OK |
| **US7** | - | - | - | - | - | - | - | OK | OK | OK | OK | OK | OK | COMPLEMENT |
| **US8** | - | - | - | - | - | - | - | - | OK | OK | OK | AMBIG-12 | OK | OK |
| **US9** | - | - | - | - | - | - | - | - | - | OK | OK | OK | OK | OK |
| **US10** | - | - | - | - | - | - | - | - | - | - | OK | OK | OK | OK |
| **US11** | - | - | - | - | - | - | - | - | - | - | - | OK | OK | OK |
| **US12** | - | - | - | - | - | - | - | - | - | - | - | - | OK | OK |
| **US13** | - | - | - | - | - | - | - | - | - | - | - | - | - | OK |
| **US14** | - | - | - | - | - | - | - | - | - | - | - | - | - | - |

### User Stories vs Functional Requirements

| | F1 | F2 | F3 | F4 | F5 | F6 | F7 | F8 |
|---|---|---|---|---|---|---|---|---|---|
| **US1** | COVERS | OK | OK | OK | OK | OK | OK | OK |
| **US2** | OK | OK | COVERS | OK | OK | OK | OK | OK |
| **US3** | OK | COVERS | COVERS | OK | OK | OK | OK | OK |
| **US4** | OK | COVERS | OK | OK | OK | OK | OK | OK |
| **US5** | OK | OK | OK | OK | COVERS | OK | OK | OK |
| **US6** | OK | OK | OK | OK | OK | COVERS | OK | OK |
| **US7** | **CONFLICT-1** | OK | OK | OK | OK | OK | OK | OK |
| **US8** | OK | **AMBIG-2,3** | OK | OK | OK | OK | OK | **AMBIG-12** |
| **US9** | OK | OK | **AMBIG-5** | OK | OK | OK | OK | OK |
| **US10** | OK | **GAP-2** | OK | OK | OK | OK | OK | OK |
| **US11** | OK | OK | OK | OK | OK | OK | COVERS | OK |
| **US12** | OK | **CONFLICT-4** | OK | OK | OK | OK | OK | COVERS |
| **US13** | OK | OK | OK | COVERS | OK | OK | OK | OK |
| **US14** | COMPLEMENT | OK | OK | OK | OK | COVERS | OK | OK |

### Functional Requirements vs Functional Requirements

| | F1 | F2 | F3 | F4 | F5 | F6 | F7 | F8 |
|---|---|---|---|---|---|---|---|---|---|
| **F1** | - | OK | OK | OK | OK | OK | OK | OK |
| **F2** | - | - | OK | OK | OK | OK | OK | **AMBIG-12** |
| **F3** | - | - | - | OK | OK | OK | OK | OK |
| **F4** | - | - | - | - | OK | OK | OK | OK |
| **F5** | - | - | - | - | - | OK | OK | OK |
| **F6** | - | - | - | - | - | - | OK | OK |
| **F7** | - | - | - | - | - | - | - | OK |
| **F8** | - | - | - | - | - | - | - | - |

---

## Open Questions Resolution Status

The document lists 5 open questions. Some are already resolved in the document body:

| Question | Status | Body Answer | Recommendation |
|----------|--------|-------------|----------------|
| 空闲检测 N 分钟？ | **OPEN** | F8 uses "N 分钟" placeholder | Lock at 5 minutes (AMBIG-4) |
| 空闲睡眠在专注中也触发？ | **RESOLVED** | F8 edge case: "专注中即使系统空闲也不进入睡眠" | Remove from open questions |
| 多显示器：主屏还是跟随鼠标？ | **OPEN** | F1 says "默认出现在主显示器" but Open Question contradicts | Lock at "主显示器，可拖拽" (AMBIG-8) |
| GIF 切换过渡策略？ | **RESOLVED** | F2 edge case: "播放完当前循环再切换" | Remove from open questions |
| 拖拽动画是 GIF 还是翻转？ | **OPEN** | F2 shows `running-left`/`running-right` as separate states implying separate GIFs | Lock: "使用独立方向 GIF 文件（running-left.gif, running-right.gif），不做运行时翻转" |

---

## Pre-v2 Lock Checklist

Before promoting to requirements-v2.md, the following MUST be resolved:

1. **[BLOCKING]** CONFLICT-1: Resolve F1 window level vs P1-2 fullscreen visibility default
2. **[BLOCKING]** DEP-1: Add functional requirement for particle effect system or demote confetti from P1-5
3. **[BLOCKING]** AMBIG-4: Lock N = 5 minutes for idle sleep threshold
4. **[BLOCKING]** AMBIG-8: Lock multi-monitor strategy
5. **[BLOCKING]** AMBIG-11: Define post-60s transition for failed/succeeded states
6. **[BLOCKING]** GAP-1: Add default `idle` baseline state
7. **[HIGH]** AMBIG-7: Specify particle effect system details
8. **[HIGH]** GAP-3: Define z-order relative to other NotchBlock windows
9. **[HIGH]** CONFLICT-3: Define pet behavior during overlay
10. **[MEDIUM]** GAP-5: Specify non-two-finger gesture behavior
11. **[MEDIUM]** GAP-7: Define screen saver / lock screen behavior
12. **[MEDIUM]** Resolve stale Open Questions (items 2 and 4 already answered in body)
