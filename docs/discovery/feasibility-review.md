# Feasibility Review Report

## Summary
- Requirements reviewed: 8 functional + 6 non-functional
- Blockers: 0 / High: 2 / Medium: 4 / Low: 4
- **Verdict**: PASS WITH RISKS

No requirement is physically impossible or self-contradictory. Two HIGH-risk items need descoping before implementation proceeds.

---

## Blockers

None.

---

## High Risk

### HIGH-1: Two-finger drag gesture conflicts with system gesture reservation
- **Requirement**: F3 — "双指拖拽移动宠物位置" via two-finger trackpad drag; edge case note says "与系统手势（如 Mission Control）不冲突"
- **Why risky**: macOS reserves multi-finger trackpad gestures at the OS level: two-finger scroll is universal, two-finger tap is right-click by default, three-finger drag is a common Mission Control gesture. `NSPanGestureRecognizer` with `numberOfTouchesRequired = 2` exists as an API, but the window server dispatches trackpad events to system gesture recognizers before delivering them to individual app windows. On a borderless transparent window, the OS has no visual anchor to distinguish "user is interacting with a pet" from "user is performing a system gesture on empty desktop space." There is no AppKit escape hatch to override system-wide gesture reservation — this is enforced by the HID driver stack, not AppKit. If the system claims the two-finger gesture, the app never sees it.
- **Must change to**: Use single-finger drag (the standard macOS idiom for moving things — every other draggable macOS element uses one finger). Alternatively, if two-finger is non-negotiable for UX reasons, restrict it to click-and-hold + single-finger drag (no gesture reservation conflict) and drop two-finger entirely.

### HIGH-2: "Crash recovery without affecting main app" implies process isolation
- **Requirement**: Non-functional — "宠物窗口崩溃后自动恢复（不影响主 App 功能）"
- **Why risky**: True crash isolation requires the pet to run in a separate process. On macOS, the supported mechanism is an XPC service (`NSXPCConnection`) embedded in the app bundle. This adds: a second code-signed executable target, a separate entitlements plist, an XPC service Info.plist, launchd registration, an async IPC protocol between the main app and the pet service, and handling of service launch/relaunch/termination edge cases. For a single-developer project with an existing codebase of moderate size, this roughly doubles the architectural complexity of the pet feature alone. The alternative — defensive coding with `guard`/`try?` to prevent a pet-side crash from propagating — does not satisfy "auto-recovery" if the crash is a segfault or memory corruption rather than a caught error.
- **Mitigation**: Downgrade this requirement. Change "崩溃后自动恢复" to "宠物异常不影响主应用功能" (pet exceptions do not affect the main app). This is achievable without process isolation by: (a) isolating all pet state behind optional properties that the main app gracefully degrades when nil, (b) wrapping pet window creation/teardown in do-catch, (c) ensuring no shared mutable state between pet controllers and core time-block controllers. If the user insists on auto-restart, add a `NSTimer`-based watchdog that checks `petWindow != nil` every 5 seconds and re-creates if missing — this handles 80% of crash scenarios without XPC.

---

## Medium Risk

### MED-1: "播完当前循环再切换" requires manual GIF frame management
- **Requirement**: F2 — "动画切换时当前 GIF 播放完当前循环再切换，避免跳帧"
- **Why concerning**: `NSImageView` with an animated GIF (set via `NSImage`) plays the animation but does not expose: current frame index, loop boundary events, or a completion callback. To implement "wait for loop end, then swap," the developer must bypass NSImageView entirely and build a custom GIF renderer using `CGImageSource` / `CGImageSourceCreateImageAtIndex` to decode frames, `CADisplayLink` or `Timer` to drive frame timing, and manual tracking of frame index vs. frame count to detect loop boundaries. This is roughly 200-400 lines of custom rendering code for a feature that, at NSImageView level, would be 5 lines.
- **Alternative**: Relax this requirement. Allow immediate animation swap on state change. The visual discontinuity is typically acceptable if a brief crossfade (0.2s opacity transition) is used between animations. If smooth transitions are critical, pre-render the last frame of the outgoing GIF and crossfade from that still frame into the new GIF. Both alternatives avoid custom GIF rendering.

### MED-2: Cross-Spaces window behavior has known edge cases on macOS 14+
- **Requirement**: F1 — "跨所有 Spaces" (appear on all Spaces); plus multi-display support
- **Why concerning**: The codebase already uses `collectionBehavior = [.canJoinAllSpaces]` in `NotchPanelController` and `OverlayWindowController`, so the team understands the API. However, `canJoinAllSpaces` has documented edge cases on macOS 14+ Sonoma and later: (a) **Stage Manager** (introduced macOS 13) groups windows into sets — a `canJoinAllSpaces` window appears in all sets, but its z-order relative to staged windows is unpredictable. (b) **Multiple displays**: each display has its own Space collection; `canJoinAllSpaces` joins the Spaces of *the display the window is currently on*. If the pet is on display 1, moving to a Space on display 2 makes the pet disappear from display 2. The user would need to drag the pet to display 2 for it to follow Spaces there. (c) **Mission Control**: a `canJoinAllSpaces` window appears as a floating element in Mission Control, not anchored to any Space thumbnail — this may confuse users.
- **Alternative**: These are fundamental OS behaviors, not bugs. The mitigation is documentation and testing: explicitly test on multi-display setups, with Stage Manager enabled, and during Mission Control. The `stationary` collection behavior (already used in `OverlayWindowController`) can help with z-order stability.

### MED-3: Accessibility non-interference vs. pet interactivity is a tension, not an API call
- **Requirement**: NFR — "宠物窗口不拦截键盘焦点；VoiceOver 可忽略宠物窗口" vs. F3 — click/drag/right-click interaction
- **Why concerning**: `NSWindow.ignoresMouseEvents = true` satisfies the non-interference requirement completely but makes the pet unclickable. `ignoresMouseEvents = false` allows interaction but means clicks on the pet are NOT passed through to the app underneath. The compromise — toggle `ignoresMouseEvents` based on `NSTrackingArea` mouse proximity — is fragile because: (a) `NSTrackingArea` fires `mouseEntered`/`mouseExited` on the main thread, introducing a 1-frame delay; (b) rapid mouse movement can race with the toggle; (c) VoiceOver users navigate by keyboard, not mouse, so `setAccessibilityElement(false)` hides the pet from VoiceOver but also prevents any VoiceOver user from discovering it.
- **Alternative**: Accept a design tradeoff. Make the pet 40-60px in size (small enough that accidental clicks are unlikely). Always use `ignoresMouseEvents = false` so the pet IS interactive, and add `accessibilityLabel` / `accessibilityRole(.image)` so VoiceOver users can discover it. The non-interference requirement becomes: "宠物窗口不拦截键盘焦点" — use `NSWindow.worksWhenModal = false` and `.nonactivatingPanel` style (already used in `NotchPanelController`) so the pet never becomes key window. For VoiceOver, make the pet's accessibility element informational rather than interactive.

### MED-4: Performance triad (sub-200ms switch + non-blocking + sub-30MB) requires disciplined frame management
- **Requirement**: NFR — "动画切换延迟 < 200ms；GIF 渲染不阻塞主线程；宠物窗口内存占用 < 30MB"
- **Why concerning**: Each of these is individually achievable, but together they create tension. Decoding all frames of a long GIF (e.g., a 60-second `focusing` idle animation at 12fps = 720 frames) and holding them in memory can easily exceed 30MB if each frame is ~50KB decoded. Background-thread decoding helps main-thread responsiveness but doesn't reduce memory. Lazy frame decoding (decode on demand per frame) keeps memory low but adds decode latency that may push frame delivery past the <200ms switch target.
- **Alternative**: Set per-animation constraints: limit GIFs to 15fps and 30-second loops (450 frames max). Pre-decode the first 3-5 frames for instant playback start, decode the rest lazily. Size all source GIFs to the display size (avoid runtime scaling). This keeps memory under 30MB for all 9 animations combined and stays well under 200ms for switch latency.

---

## Low Risk

### LOW-1: "零代码改动" extensibility claim is aspirational
- **Requirement**: F4 / NFR — "添加新宠物仅需放入素材 + 配置，无需改代码" and "动画配置外置"
- **Note**: Achievable for pets that share the exact same animation set and behavior model as `elysia`. However, if a future pet needs a different animation set (e.g., 12 states instead of 9), or different interaction behavior (e.g., pet that follows the cursor), the manifest schema would need to evolve, which requires code changes. Recommend framing as "zero code for same-category pets" rather than "zero code for any pet." The `PetManifest.json` approach is sound; just scope the claim.

### LOW-2: Multi-display support expands the testing matrix
- **Requirement**: F1 — "宠物默认出现在主显示器，可拖到副屏"; NFR — "支持多显示器"
- **Note**: Each additional display has its own coordinate system and NSScreen instance. Window positioning across displays uses the unified Cocoa coordinate space (origin at bottom-left of primary display, secondary displays extend the coordinate system), so window movement between displays works naturally. However, `canJoinAllSpaces` behavior differs per display (see MED-2), and restoring a saved position from UserDefaults when the display configuration changed requires NSScreen.screens validation. Not high-risk, but these edge cases need explicit test coverage.

### LOW-3: Particle effects for celebration animation adds CoreAnimation complexity
- **Requirement**: F2 — succeeded state: "跳跃+撒花粒子"
- **Note**: `CAEmitterLayer` is the standard AppKit particle system, available since macOS 10.6. It is well-documented and widely used. Implementation effort is moderate (50-100 lines for a basic confetti emitter). If this proves more complex than anticipated, simplify by using a pre-rendered GIF that includes the particle effect (the artist composites particles into the GIF frames). This eliminates all particle system code.

### LOW-4: Animated GIF preview in onboarding may not play in SwiftUI
- **Requirement**: F5 — "展示宠物预览（动图）"
- **Note**: SwiftUI `Image` does not animate GIFs. `NSImageView` with an animated GIF works in AppKit but requires `NSViewRepresentable` to embed in SwiftUI. The onboarding window (`OnboardingWindowController`) appears to be AppKit-based (uses `NSWindowController`), so this may be a non-issue. If the onboarding is SwiftUI-hosted, factor the GIF preview into an `NSViewRepresentable` wrapper (~30 lines).

---

## Complexity Estimate
- **Category**: Medium (for a solo developer)
- **Minimum viable team**: 1 engineer (the stated solo developer)
- **Minimum viable timeline**: 3-4 weeks (assuming full-time focus, existing codebase familiarity, and accepting the descope recommendations above)
- **Key risk factor**: Two-finger gesture conflict is the highest schedule risk — if the team insists on two-finger drag and it proves infeasible after implementation, the rebuild to single-finger drag touches F3 (interaction), F2 (dragging-left/right animations), and F6 (position persistence) simultaneously. Decide the drag gesture model before any implementation begins.

### Timeline breakdown (post-descoping to single-finger drag + no XPC isolation)

| Week | Deliverable |
|------|-------------|
| 1 | Pet window (F1): borderless NSWindow, correct window level, cross-Spaces, multi-display positioning |
| 2 | GIF animation system (F2): state machine, CGImageSource-based playback, crossfade transitions, state-driven animation selection |
| 3 | Interaction (F3): click-to-open-panel, single-finger drag-to-move, hover highlight, right-click menu. Persistence (F6) + idle detection (F8) |
| 4 | Extensible architecture (F4): PetManifest.json, pet loader. Onboarding integration (F5). Polish: performance tuning, multi-display testing, edge case hardening |

---

## Appendix: Requirement-by-Requirement Verdict

| ID | Requirement | Verdict |
|----|------------|---------|
| F1 | 宠物窗口始终可见，跨Spaces | PASS (MED-2 edge cases) |
| F2 | 宠物动画系统，状态机驱动GIF | PASS (MED-1, MED-4 for perf) |
| F3 | 宠物交互（点击/拖拽/悬停/右键） | PASS WITH CHANGE (HIGH-1: drop two-finger) |
| F4 | 宠物可扩展架构 | PASS (LOW-1: scope claim) |
| F5 | 引导集成 | PASS (LOW-4: GIF preview in SwiftUI) |
| F6 | 偏好持久化 | PASS |
| F7 | 右键快捷菜单 | PASS |
| F8 | 空闲睡眠状态 | PASS |
| NFR-P | 动画 < 200ms，不阻塞主线程，< 30MB | PASS (MED-4: frame discipline needed) |
| NFR-A | 崩溃自动恢复，不影响主App | PASS WITH CHANGE (HIGH-2: drop auto-restart) |
| NFR-C | macOS 14.0+，多显示器，notch兼容 | PASS |
| NFR-E | 零代码添加新宠物 | PASS (LOW-1: aspirational) |
| NFR-A11y | 不拦截焦点，VoiceOver可忽略 | PASS (MED-3: design tradeoff) |
| NFR-S | 无敏感数据，仅本地UserDefaults | PASS |
