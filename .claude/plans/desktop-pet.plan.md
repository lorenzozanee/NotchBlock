# Plan: Desktop Pet Feature

**Source PRD**: `.claude/prds/desktop-pet.prd.md`
**Selected Milestone**: Milestone 1 — Pet Window + Animation
**Complexity**: Medium

## Summary
实现桌面宠物 P0 功能（浮动窗口 + 9 状态动画机 + 交互 + 引导集成）。基于已完成的模型层（Sprint 1），现在构建 Managers 层和 Views 层。参考 `bssm-oss/desktop-pet` 的 GIF 解码栈和 `OverlayWindowController` 的窗口管理模式。

## Patterns to Mirror

| Category | Source | Pattern |
|----------|--------|---------|
| Naming | `OverlayWindowController.swift:14` | `final class` + descriptive PascalCase, private properties, `// MARK: -` sections |
| Errors | `OverlayWindowController.swift:5` | `Logger(subsystem: "com.notchblock.app", category: "Pet")` via OSLog |
| Logging | `TimeBlockStore.swift:4` | `private let logger = Logger(...)` at file top, category matches module |
| Data access | `TimeBlockStore.swift:8` | `final class: ObservableObject` + `@Published var` + copy-then-assign immutability |
| Window mgmt | `OverlayWindowController.swift:35-44` | NSPanel init with `screen.frame`, `collectionBehavior`, generation counter race prevention |
| Panel show/hide | `NotchPanelController.swift:39-52` | `dismiss()/hideGeneration += 1`, `NSAnimationContext.runAnimationGroup` for fade |
| Tests | `TimeBlockTests.swift:1-28` | `#!/usr/bin/env swift`, mirrored model struct, `test(_:_:)` helper, `✅/❌` output |
| Immutability | `TimeBlockStore.swift:23-26` | `var updated = array; updated.append(item); array = updated` — never mutate in place |

## Files to Change

| File | Action | Why |
|------|--------|------|
| `NotchBlock/Managers/PetWindowController.swift` | CREATE | NSPanel lifecycle for pet window |
| `NotchBlock/Managers/PetStateMachine.swift` | CREATE | 9-state FSM observing TimeBlockStore |
| `NotchBlock/Managers/PetAnimationPlayer.swift` | CREATE | CGImageSource GIF decoder + CVDisplayLink |
| `NotchBlock/Managers/PetInteractionHandler.swift` | CREATE | Click/drag/hover/right-click events |
| `NotchBlock/Views/PetView.swift` | CREATE | SwiftUI pet content with GIF frame display |
| `NotchBlock/Views/PetOnboardingView.swift` | CREATE | Onboarding pet selection page |
| `NotchBlock/NotchBlockApp.swift` | UPDATE | Initialize PetWindowController on launch |
| `NotchBlock/Managers/OnboardingWindowController.swift` | UPDATE | Add pet selection page to flow |
| `NotchBlock/Managers/BlockScheduler.swift` | UPDATE | Emit focus/succeeded/failed events for pet |
| `generate_xcode_project.py` | UPDATE | Register new source files + Managers group |
| `Tests/PetStateMachineTests.swift` | CREATE | State transition tests |
| `Tests/PetAnimationPlayerTests.swift` | CREATE | GIF decoder + playback tests |
| `Tests/PetWindowControllerTests.swift` | CREATE | Window config + lifecycle tests |
| `Tests/PetInteractionTests.swift` | CREATE | Gesture differentiation + debounce tests |

## Dependency Graph

```
  PetState (done)     PetProtocol (done)    PetConfig (done)    PetPreferences (done)
       │                    │                    │                     │
       └────────────────────┼────────────────────┼─────────────────────┘
                            │                    │
                   ┌────────▼────────┐  ┌────────▼────────┐
                   │ PetAnimationPlayer│  │ PetStateMachine  │
                   │ (CGImageSource +  │  │ (observe Store,   │
                   │  CVDisplayLink)   │  │  transition logic)│
                   └────────┬────────┘  └────────┬────────┘
                            │                    │
                            └─────────┬──────────┘
                                      │
                            ┌─────────▼──────────┐
                            │ PetInteractionHandler│
                            │ (mouse events, menu) │
                            └─────────┬──────────┘
                                      │
                            ┌─────────▼──────────┐
                            │ PetWindowController │
                            │ (NSPanel lifecycle)  │
                            └─────────┬──────────┘
                                      │
                            ┌─────────▼──────────┐
                            │     PetView         │
                            │  (SwiftUI render)   │
                            └─────────┬──────────┘
                                      │
                            ┌─────────▼──────────┐
                            │ PetOnboardingView   │
                            │ (Guide integration) │
                            └────────────────────┘
```

## Tasks

### Sprint 2A: PetAnimationPlayer (GIF 渲染引擎)

#### Task A1: GIF Decoder
- **Action**: 创建 `PetAnimationPlayer.swift`，实现 CGImageSource 逐帧解码。预解码前 4 帧即时播放，惰性解码后续帧。处理 GIF disposal method。
- **Mirror**: 模块结构参考 `OverlayWindowController`（`final class` + `private` 属性 + `// MARK: -` 分组），日志使用 `Logger(subsystem: "com.notchblock.app", category: "PetAnimation")`
- **Validate**: `swift Tests/PetAnimationPlayerTests.swift` 全部通过

#### Task A2: CVDisplayLink 帧驱动
- **Action**: 添加 CVDisplayLink 回调，帧时序管理，loop 处理。添加 crossfade 双缓冲（0.2s opacity 过渡）。
- **Mirror**: 参考 bssm-oss/desktop-pet 的 AnimationPlayer 实现模式
- **Validate**: GIF 循环播放无跳帧，crossfade 视觉平滑

#### Task A3: 电池感知帧率
- **Action**: 检测 `NSApplication.isFullKeyboardAccessEnabled` → power source。电池模式 10fps，空闲 30s 降至 5fps，AC 恢复原始帧率。
- **Mirror**: 无现有模式 — 新建。参考 `IOKit` 或 `NSProcessInfo` 电源检测
- **Validate**: 帧率切换不丢帧、不崩溃

### Sprint 2B: PetStateMachine (状态机)

#### Task B1: 状态机核心
- **Action**: 创建 `PetStateMachine.swift`（`final class: ObservableObject`）。观察 `TimeBlockStore.$blocks`。实现 9 状态优先级判定和转换逻辑。
- **Mirror**: `TimeBlockStore` 的 `@Published` + Combine 模式；`OverlayWindowController` 的 `@Published` 属性声明
- **Validate**: `swift Tests/PetStateMachineTests.swift` — 覆盖所有 20+ 转换路径

#### Task B2: failed/succeeded 60s 定时器
- **Action**: `failed`/`succeeded` 状态启动 `Timer.scheduledTimer(withTimeInterval: 60)`. 到期后过渡到 `idle`（无活跃专注）或 `focusing`（有活跃专注）。
- **Mirror**: `OverlayWindowController` 的 300s timeout timer 模式
- **Validate**: 定时器正确触发、取消、不泄漏

### Sprint 2C: PetInteractionHandler (交互)

#### Task C1: 鼠标事件处理
- **Action**: `mouseDown`/`mouseDragged`/`mouseUp` 覆盖。3pt 阈值区分 click vs drag。Drag 方向触发 `draggingLeft`/`draggingRight`。Edge clamping (20pt margin)。
- **Mirror**: `NotchPanelController` 的视图绑定模式（`bind(to:)`方法）
- **Validate**: `swift Tests/PetInteractionTests.swift` — click/drag 区分、边界钳制、方向正确

#### Task C2: 悬停 + 右键菜单
- **Action**: `NSTrackingArea` 鼠标进入/离开。进入 → scale 1.1x + alpha 1.0 (0.2s ease-out)。离开→ scale 1.0 + alpha 0.85。右键 → `NSMenu.popUp`。
- **Mirror**: `NotchTracker` 的 `NSTrackingArea` 模式
- **Validate**: 悬停动画不闪烁、右键菜单项正确

#### Task C3: 点击防抖 + 面板集成
- **Action**: 0.3s 防抖（两次点击间隔 < 0.3s 忽略第二次）。单击 → 调用现有 `NotchPanelController.show()`.
- **Mirror**: `NotchTracker` 的 0.5s hover debounce 模式
- **Validate**: 快速双击仅触发一次面板弹出

### Sprint 2D: PetWindowController + PetView (窗口 + 视图)

#### Task D1: NSPanel 配置
- **Action**: 创建 `PetWindowController.swift`。NSPanel `.borderless` + `.nonactivatingPanel`，`.mainMenu` level，`.canJoinAllSpaces` + `.fullScreenAuxiliary`。位置从 UserDefaults 恢复。透明背景。
- **Mirror**: `OverlayWindowController.show()` NSPanel init 模式 + `NotchPanelController` 位置计算
- **Validate**: 窗口跨 Spaces 可见、全屏时可见、位置正确恢复

#### Task D2: PetView (SwiftUI)
- **Action**: 创建 `PetView.swift`。`NSHostingView` 嵌入 SwiftUI。渲染当前动画帧。Alpha 动画（悬停）。NSMenu 右击集成。
- **Mirror**: `NotchPanelView` 的 SwiftUI 内容 + `NSHostingView` 模式
- **Validate**: GIF 帧正确渲染、alpha 动画平滑

#### Task D3: 组件集成
- **Action**: `PetWindowController` 连接 `PetStateMachine` → `PetAnimationPlayer` → `PetView` → `PetInteractionHandler`。端到端：TimeBlockStore 变化 → 状态机 → 动画 → 视图更新。
- **Mirror**: 无现有模式（新集成）— 使用依赖注入 `init(store:animationPlayer:...)`
- **Validate**: 专注开始 → 宠物播 waiting.gif；专注成功 → 宠物播 jumping.gif 60s → 回到 idle

### Sprint 3: 集成 + 引导 (Week 3)

#### Task E1: Onboarding 集成
- **Action**: 在 `OnboardingWindowController` 添加宠物选择页。GIF 预览（NSImageView）。"启用 elysia" / "暂不启用" 按钮。存储到 UserDefaults。
- **Mirror**: 现有 `OnboardingView.swift` 的页面结构模式
- **Validate**: 引导流程正确，新老用户路径正确

#### Task E2: Watchdog 恢复
- **Action**: `Timer.scheduledTimer(withTimeInterval: 5)` 检测 petWindow 存活。丢失 + enabled → 重建。连续 3 次失败 → 停止 + OSLog 错误。
- **Mirror**: `BlockScheduler` 的 1s polling timer 模式
- **Validate**: 强制关闭窗口后自动重建，3 次失败后停止

#### Task E3: NotchBlockApp 初始化
- **Action**: 在 `NotchBlockApp.swift` 中按需初始化 `PetWindowController`。`pet.enabled == true` 时创建窗口。
- **Mirror**: 现有 Manager 初始化模式
- **Validate**: App 启动时宠物窗口出现（若 enabled），构建成功

## Validation

```bash
# 模型测试（已完成 — 88 通过）
swift Tests/PetStateTests.swift
swift Tests/PetProtocolTests.swift
swift Tests/PetConfigTests.swift
swift Tests/PetPreferencesTests.swift

# 新测试（待实现）
swift Tests/PetStateMachineTests.swift
swift Tests/PetAnimationPlayerTests.swift
swift Tests/PetWindowControllerTests.swift
swift Tests/PetInteractionTests.swift

# 已有测试不要退化
swift Tests/TimeBlockTests.swift
swift Tests/StatisticsTests.swift

# 构建验证
python3 generate_xcode_project.py
xcodebuild -project NotchBlock.xcodeproj -scheme NotchBlock -configuration Debug build
```

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| CGImageSource GIF disposal 处理错误 → 残影 | Medium | Medium | 参考 bssm-oss/desktop-pet GIFDecoder 的 disposal method 处理；每个 GIF 单独测试 |
| .nonactivatingPanel init 后失效 | Low | High | 必须在 NSPanel init 时设置（已知 Radar FB16484811），代码审查时检查 |
| 状态机转换遗漏 | Medium | Medium | 所有 20+ 转换路径写测试覆盖；Red Team 论证时已识别此风险 |
| AppKit 依赖的测试无法 swift 直接运行 | High | Medium | 交互/窗口测试使用 mock 抽象；纯逻辑测试用 `swift Tests/`；窗口集成测试需手动验证 |
| 电源检测 API 变更 | Low | Low | 使用 `Notification.Name.NSProcessInfoPowerStateDidChange` 标准通知 |
| 多显示器坐标 bug | Medium | Medium | 钳制策略 + NSScreen.screens 动态校验；P0 仅需主屏正确 |

## Acceptance

- [ ] 所有 8 个新测试套件通过（4 个已有 + 4 个新增）
- [ ] `xcodebuild build` 成功
- [ ] 已有测试不退化（TimeBlock 9/9, Statistics 6/6）
- [ ] 代码遵循现有模式：final class、OSLog、immutable copy-then-assign
- [ ] 所有 14 个新文件注册到 generate_xcode_project.py
- [ ] 宠物窗口在 App 启动时正确出现（若 enabled）
- [ ] 单击宠物 → NotchPanel 弹出
- [ ] 拖拽移动宠物 → 方向动画 + 位置保存
- [ ] 专注开始/成功/失败 → 对应动画切换
