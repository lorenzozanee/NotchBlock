# 桌面宠物功能 — Requirements Document v2 【LOCKED】

## Metadata
- Date: 2026-06-07
- Source: requirements-v1.md + 一致性审查 + 可行性审查
- Analyst: Discovery Workflow (Phase 3 Merge)
- Project: NotchBlock（增量需求）
- Status: LOCKED

---

## 项目概述

### 背景
NotchBlock 已有刘海悬浮面板、全屏遮罩、任务调度等核心专注功能。本次增量需求是在桌面层增加一个可交互的陪伴宠物，增强用户情感连接和使用趣味性。

### 目标
提供一个始终可见的桌面宠物，通过动画反馈反映用户的专注状态，并作为刘海面板的快捷入口。宠物系统需具备可扩展性，支持未来添加新宠物角色。

### 目标用户
所有 NotchBlock 用户。引导流程中可选择关闭宠物功能。

### 成功标准
- 宠物功能启用时，App 运行期间宠物窗口在桌面层持续可见（跨所有 Spaces）
- 动画切换响应及时，使用 crossfade 过渡（0.2s），切换延迟 < 200ms
- GIF 动画播放流畅，不阻塞主线程；所有动画内存占用 < 30MB
- 宠物系统可扩展：添加同类宠物仅需素材 + 配置，无需改核心代码

---

## User Stories

### P0 — Must Have
- [ ] As a 专注用户, I want 宠物功能启用时桌面上有一个持续可见的宠物, so that 我能感知 NotchBlock 正在运行且陪伴我专注
- [ ] As a 专注用户, I want 单击宠物弹出时间块面板（与刘海悬浮一致）, so that 我能快速查看当前专注状态
- [ ] As a 专注用户, I want 单指拖拽移动宠物位置, so that 宠物不会遮挡我的工作区域
- [ ] As a 专注用户, I want 宠物的动画反映我的专注状态（专注中/成功/失败）, so that 我能通过视觉反馈感知当前状态
- [ ] As a 新用户, I want 在引导流程中选择是否启用宠物, so that 不需要宠物的人可以关闭它

### P1 — Should Have
- [ ] As a 专注用户, I want 宠物位置和偏好被记住, so that 重启 App 后宠物回到原位
- [ ] As a 专注用户, I want 全屏/遮罩时也能看到宠物, so that 专注过程中陪伴不中断
- [ ] As a 专注用户, I want 宠物在空闲时有随机微动作（眨眼、伸懒腰）, so that 宠物看起来更生动
- [ ] As a 专注用户, I want 鼠标悬停宠物时有视觉反馈（缩放至 1.1x + alpha 0.85→1.0）, so that 我能感知宠物是可交互的
- [ ] As a 专注用户, I want 专注完成时有庆祝动画（跳跃+撒花粒子）, so that 获得成就感反馈
- [ ] As a 专注用户, I want 右键宠物弹出快捷菜单, so that 无需进入主窗口就能切换/隐藏宠物

### P2 — Nice to Have
- [ ] As a 专注用户, I want Mac 5 分钟无操作后宠物自动进入睡眠状态, so that 宠物行为更拟真
- [ ] As a 未来用户, I want 能够选择不同宠物角色, so that 我能个性化我的专注伴侣
- [ ] As a 专注用户, I want 可选择全屏时自动隐藏宠物, so that 全屏工作时不被打扰

---

## Functional Requirements

### F1: 宠物窗口（始终可见）
- **Description**: 宠物以无边框透明窗口形式显示在桌面层，跨所有 Spaces。默认使用 `.fullScreenAuxiliary` collection behavior（与现有 `OverlayWindowController` 一致），在专注全屏遮罩激活时保持可见（`ignoresMouseEvents = true` 于遮罩期间）。用户可通过 `pet.hideInFullscreen` 偏好选择全屏时隐藏。
- **Window Level**: 高于桌面壁纸，等于 OverlayWindow 层级（`.fullScreenAuxiliary`），低于 NotchPanel 和主窗口。
- **Z-Order 完整链**（从低到高）: 桌面壁纸 < 宠物窗口 < NotchPanel < 主窗口/Preferences
- **Edge cases**: 
  - App 退出时宠物窗口同步关闭
  - 多显示器：宠物默认出现在主显示器可见区域右下角（距右/下边缘各 20pt），位置按显示器独立记忆，不克隆到多屏。可拖拽至任意副屏。拔插显示器后位置钳制到当前可用屏幕区域
  - 用户关闭宠物后（`pet.enabled = false`），窗口完全释放不残留
  - 屏幕保护程序激活或屏幕锁定时，宠物窗口自动隐藏；解锁后在原位置恢复，动画重置为当前活跃状态
  - Stage Manager 下宠物窗口出现在所有 Stage 组中（`canJoinAllSpaces` 行为）
  - 宠物窗口使用 `.nonactivatingPanel` 风格，永不成为 key window

### F2: 宠物动画系统
- **Description**: 状态机驱动的 GIF 动画系统。使用 `CGImageSource` 逐帧解码，`CADisplayLink` 驱动帧时序。动画切换使用 0.2s opacity crossfade 过渡（不等待当前循环结束）。
- **状态定义与优先级**（从高到低）:
  1. `dragging-left` — 单指拖拽向左
  2. `dragging-right` — 单指拖拽向右
  3. `failed` — 任务失败，持续 60s 后自动过渡到默认状态
  4. `succeeded` — 任务成功，持续 60s 后自动过渡到默认状态
  5. `focusing` — 专注中，waiting/idle 随机切换
  6. `sleeping` — Mac 空闲（P2，可被用户交互中断）
  7. `idle-micro` — 空闲微动作（P1）
  8. `idle` — 默认非专注状态（基线状态）
  9. `initial` — 首次初始化（最低优先级，首次交互后退出）
- **状态 → 动画映射**:
  | 状态 | 动画文件 | 持续时间 | 触发条件 |
  |------|----------|----------|----------|
  | `initial` | waving.gif | 循环至首次交互 | 宠物首次初始化 |
  | `idle` | idle.gif | 循环（默认基线） | 非专注期间的默认状态 |
  | `focusing` | waiting.gif / idle.gif 随机切换 | 专注期间持续 | BlockScheduler 报告专注中 |
  | `failed` | failing.gif | 60 秒 → 过渡到 idle/focusing | 时间块任务失败 |
  | `succeeded` | jumping.gif + 粒子特效 | 60 秒 → 过渡到 idle/focusing | 时间块任务成功 |
  | `dragging-left` | running-left.gif | 拖拽期间 | 用户向左拖拽 |
  | `dragging-right` | running-right.gif | 拖拽期间 | 用户向右拖拽 |
  | `idle-micro` | 随机 blink.gif / stretch.gif | 播一次（1-3s） | 非专注空闲时每隔 8-20s 随机触发 |
  | `sleeping` | sleeping.gif | 系统空闲期间循环 | 5 分钟无用户输入（非专注期间） |
- **后 60s 过渡规则**: `failed` 和 `succeeded` 状态 60 秒结束后：
  - 若当前有活跃专注任务 → 过渡到 `focusing`
  - 否则 → 过渡到 `idle`
- **性能约束**: GIF 限制 15fps、单文件最多 30 秒循环（≤450 帧）；前 3-5 帧预解码即时播放，其余惰性解码；素材使用显示尺寸，避免运行时缩放
- **Edge cases**: 
  - 素材缺失时显示占位图形（纯色圆 + 宠物名文字）+ OSLog 警告
  - GIF 文件解码失败时标记该动画状态不可用，降级使用 `idle` 动画替代
  - 状态切换不等待 GIF 循环结束：立即 0.2s crossfade 到新动画
  - `sleeping` 被用户交互中断 → 播放一次 waving，然后进入 `idle`

### F3: 宠物交互系统
- **Description**: 
  - **单击**: 弹出 `NotchPanelController` 管理的悬浮面板（复用现有刘海悬浮逻辑）。0.3s 内连续点击忽略第二次（防抖）
  - **单指拖拽**: 移动宠物窗口位置（`NSPanGestureRecognizer`，`numberOfTouchesRequired = 1`）。拖拽方向（水平位移分量）触发对应 running 动画。**注：原始需求为双指拖拽，但 macOS 系统层保留双指手势（滚动/右键），改为单指拖拽是 macOS 上最可靠的可拖拽方案。**
  - **悬停**: `NSTrackingArea` 检测鼠标进入/离开。进入时宠物 scale 至 1.1x + alpha 0.85→1.0（0.2s ease-out）；离开时恢复 scale 1.0 + alpha 0.85
  - **右键**: 弹出 NSMenu 快捷菜单（见 F7）
- **手势行为规范**:
  - 单指拖拽 → 移动宠物
  - 双指及以上手势 → 不触发任何宠物行为，透传到下层
  - Force-click → 不触发系统查询功能
- **Edge cases**:
  - 拖拽到屏幕边缘时钳制不超出可见区域边界（预留 20pt 边距）
  - 快速连续点击防抖（0.3s）
  - 遮罩激活期间：宠物可见但 `ignoresMouseEvents = true`（遮罩优先级不可绕过）

### F4: 宠物可扩展架构
- **Description**: 宠物系统设计为数据驱动。添加同类宠物仅需：
  1. 在 `pets/<pet-name>/` 放入对应动画 GIF 文件
  2. GIF 文件命名遵循约定：`idle.gif`, `waving.gif`, `waiting.gif`, `failing.gif`, `jumping.gif`, `running-left.gif`, `running-right.gif`, `blink.gif`, `stretch.gif`, `sleeping.gif`
  3. 若动画映射偏离约定，通过 `PetManifest.json` 声明映射关系
  4. 无需修改核心动画/窗口逻辑
- **命名约定**: 文件名（不含扩展名）与 F2 状态表的「动画文件」列完全一致。`PetManifest.json` 仅在映射不一致时需要
- **当前实现**: 仅 `pets/elysia/`（含 9 个 GIF 素材）
- **Edge cases**:
  - 宠物配置加载失败时降级到默认宠物（elysia）
  - 未来用户切换宠物：立即切换动画并 crossfade，窗口位置不变
  - **注意**: "零代码改动"仅限于同类宠物（相同动画集+行为模型）。若未来宠物需要不同动画集或交互行为，需扩展 PetManifest schema

### F5: 引导集成
- **Description**: 在 `OnboardingWindowController` 引导流程中新增宠物选择页。
  - 展示宠物预览（GIF 动图，需 `NSViewRepresentable` 包装 `NSImageView` 若页面为 SwiftUI 实现）
  - 选项：启用 elysia / 暂不启用
  - 用户选择存储到 UserDefaults
- **统一切换入口**: 
  - 引导流程（F5）：展示预览动图 + 单选列表
  - 右键菜单（F7）：列出可用宠物，点击即切换（无确认对话框），切换时播放 0.3s 过渡动画
  - Preferences > 宠物标签页（未来）：与引导流程相同的预览界面
  - 所有入口操作写入同一 `pet.selected` UserDefaults key
- **Edge cases**:
  - 老用户升级：默认开启宠物（elysia），可在设置中关闭
  - 跳过引导：宠物默认不启用，在 Preferences 中手动开启

### F6: 宠物偏好持久化
- **Description**: 所有宠物设置存储在 UserDefaults。
  - `pet.enabled`: Bool — 是否启用宠物（默认 `true` 于新用户，`true` 于升级用户）
  - `pet.selected`: String — 当前选中宠物名称（默认 `"elysia"`）
  - `pet.position.x`: Double — 宠物窗口 X 坐标（主显示器坐标系）
  - `pet.position.y`: Double — 宠物窗口 Y 坐标（主显示器坐标系）
  - `pet.hideInFullscreen`: Bool — 全屏时是否隐藏（默认 `false`）
  - `pet.idleSleepMinutes`: Int — 空闲睡眠阈值分钟数（默认 `5`）
- **Edge cases**:
  - 首次启动无位置数据 → 默认主显示器可见区域右下角，距右边缘 20pt、距下边缘 20pt
  - 屏幕分辨率变化导致宠物超出边界 → 钳制到当前可用屏幕可见区域
  - 拔插显示器后位置校验 → 若保存位置不在任何当前屏幕范围内，重置到主显示器右下角

### F7: 右键快捷菜单
- **Description**: 右键宠物弹出 NSMenu：
  - "隐藏宠物" — 设置 `pet.enabled = false`，关闭宠物窗口
  - "切换宠物" — 子菜单列出可用宠物（当前仅 elysia），点击即切换
  - "宠物设置..." — 打开 Preferences 对应标签页
- **Edge cases**: 无可用宠物时"切换宠物"灰色不可选

### F8: 空闲检测与睡眠状态
- **Description**: 使用 `CGEventSourceSecondsSinceLastEventType(kCGEventSourceStateHIDSystemState)` 每秒轮询系统最后输入时间。`idle-micro` 和 `sleeping` 共享同一检测器。
  - 0-N 分钟无操作：宠物处于 `idle` 基线，每隔 8-20s 随机触发一次 `idle-micro`
  - 达到 N 分钟阈值：持续播放 `sleeping`，不再触发 `idle-micro`
  - 用户恢复操作：退出 `sleeping`，播放一次 waving 后进入 `idle`
- **Edge cases**: 
  - 专注中即使系统空闲也不进入 `sleeping`，保持 `focusing` 状态；`idle-micro` 在专注中也不触发
  - `sleeping` 循环播放直至用户交互

### F9: 粒子特效系统
- **Description**: 专注成功时在宠物窗口上方叠加粒子庆祝效果。
  - 技术方案：`CAEmitterLayer`，粒子层添加在宠物窗口上方独立透明层
  - 发射源：锚定在宠物窗口中心坐标
  - 粒子规格：30-50 个彩色五角星/圆形粒子，从宠物位置向上抛洒
  - 持续 3 秒后自动移除
  - 粒子层不拦截鼠标事件（`emitterLayer.isAccessibilityElement = false`）
- **Edge cases**:
  - 多显示器：粒子发射源跟随宠物窗口实际位置
  - 粒子播放期间宠物被拖拽：粒子跟随宠物窗口移动（`emitterLayer.position` 绑定到宠物窗口中心）
  - 降级方案：若 `CAEmitterLayer` 实现复杂度超预期，使用预合成 GIF（艺术家将粒子集成到 GIF 帧中）

---

## Non-Functional Requirements

| Category | Requirement |
|----------|-------------|
| **Performance** | 动画切换延迟 < 200ms（含 crossfade）；GIF 帧率 ≤ 15fps，单文件 ≤ 30s 循环（≤ 450 帧）；前 3-5 帧预解码即时播放；主线程不阻塞；所有动画内存 < 30MB；素材使用显示尺寸避免运行时缩放 |
| **Battery** | Mac 使用电池时宠物 GIF 帧率降至 10fps；接入电源恢复原始帧率；无交互 30s 后降至 5fps |
| **Security** | 无敏感数据处理；偏好仅本地 UserDefaults；无网络请求 |
| **Availability** | 宠物异常不影响主应用功能：宠物状态通过 optional 属性隔离，主应用在宠物状态为 nil 时优雅降级。使用 NSTimer 5 秒间隔 watchdog 检测宠物窗口是否存活，若丢失且 `pet.enabled == true` 则重建。连续重建失败 3 次后停止并报告 OSLog 错误 |
| **Compatibility** | macOS 14.0+；支持多显示器（主屏显示，可拖拽至副屏，位置按屏独立记忆）；支持 notch / no-notch Mac；Stage Manager 兼容 |
| **Extensibility** | 添加同类宠物（相同动画集+行为模型）：素材 + 配置，零代码改动。不同行为模型的宠物需扩展 PetManifest schema |
| **Accessibility** | 宠物窗口永不成为 key window（`.nonactivatingPanel`）；`accessibilityLabel` 设置为宠物名称；`accessibilityRole(.image)` 供 VoiceOver 发现；不拦截键盘焦点 |

---

## Explicit Non-Goals (Out of Scope)

- 宠物不发出声音（无音效系统）
- 宠物不连接网络（无在线下载新宠物）
- 宠物不执行任何系统操作（纯视觉陪伴）
- 不支持同时显示多个宠物
- 不在菜单栏显示宠物状态图标
- 不区分深浅色模式的独立素材（GIF 素材通用；未来可通过 PetManifest 扩展）

---

## Constraints & Assumptions

- **技术栈**: Swift 6.1 + SwiftUI + AppKit, macOS 14.0+
- **素材格式**: GIF（现有素材均为 GIF）
- **素材尺寸**: GIF 逻辑尺寸 50-150pt（@2x 屏幕对应 100-300 原生像素）；宠物窗口按素材原生尺寸显示
- **拖拽方式**: 单指拖拽（替代原始双指方案，因 macOS 系统层保留双指手势）
- **时间**: 无硬性 deadline；预估 3-4 周（1 人全职）
- **空闲检测**: `CGEventSourceSecondsSinceLastEventType`，每秒轮询

---

## 审查追溯

### 一致性审查采纳
- **[CONFLICT-1]** F1 默认窗口层级低于全屏 vs P1-2 要求全屏可见 → F1 默认改为 `.fullScreenAuxiliary`（与 OverlayWindowController 一致），全屏可见为默认，用户可 opt-out
- **[CONFLICT-2]** P0-1 "始终可见" 绝对语言 vs 用户可选关闭 → P0-1 重写为 "宠物功能启用时，桌面上有一个持续可见的宠物"
- **[CONFLICT-3]** 遮罩期间宠物可见性 vs 遮罩不可绕过 → 遮罩期间宠物可见但 `ignoresMouseEvents = true`
- **[CONFLICT-4]** F2 优先级链不完整 → 补全 9 个状态的完整优先级
- **[AMBIG-1]** "始终可见" 不可度量 → 添加 "当 NotchBlock 运行且宠物功能启用时" 限定
- **[AMBIG-2]** idle-micro 触发间隔 → 锁定为 8-20s 随机
- **[AMBIG-3]** idle-micro 持续时间 → 锁定为播放一次，1-3s
- **[AMBIG-4]** 空闲睡眠 N 分钟 → 锁定为 5 分钟，可通过 UserDefaults 配置
- **[AMBIG-5]** 悬停 "亮度提升" → 锁定为 alpha 0.85→1.0
- **[AMBIG-6]** "默认右下角" 多屏歧义 → 锁定为主显示器可见区域右下角，距边缘 20pt
- **[AMBIG-7]** 粒子特效未定义 → 新增 F9 完整规格
- **[AMBIG-8]** 多显示器策略 → 锁定为主屏显示 + 可拖拽 + 按屏独立记忆 + 不克隆
- **[AMBIG-9]** px vs pt 歧义 → 统一使用 pt（逻辑点）
- **[AMBIG-10]** "专注完成" 触发条件 → 锁定为任一时间块标记完成
- **[AMBIG-11]** failed/succeeded 后 60s 行为 → 锁定为过渡到 idle 或 focusing
- **[AMBIG-12]** idle-micro 和 sleeping 空闲定义不一致 → 统一共享检测器
- **[GAP-1]** 无默认 idle 基线状态 → 新增 `idle` 状态作为非专注默认
- **[GAP-2]** 粒子特效无功能需求 → 新增 F9
- **[GAP-3]** Z-order 未定义 → 添加完整层级链
- **[GAP-4]** 崩溃恢复无机制 → 添加 NSTimer watchdog + 3 次重试上限
- **[GAP-5]** 非双指手势行为 → 明确单指/多指/Force-click 行为
- **[GAP-6]** 深浅色模式 → 添加 Non-Goal 声明
- **[GAP-7]** 屏保/锁屏行为 → 添加 F1 edge case
- **[GAP-8]** 宠物切换 UX 不统一 → 统一三个入口的行为
- **[GAP-9]** 电池影响 → 新增电池 NFR
- **[GAP-10]** 损坏 GIF 处理 → 添加 F2 edge case（降级到 idle 动画）
- **[GAP-11]** 文件命名约定 → 添加 F4 命名约定
- **[DEP-1]** P1-5 依赖未定义的粒子系统 → 新增 F9
- **[DEP-2]** idle-micro+sleeping 依赖未定义的空闲检测 → F8 补充具体 API 和轮询策略

### 可行性审查采纳
- **[HIGH-1]** 双指拖拽系统手势冲突 → **采纳**：改为单指拖拽（`NSPanGestureRecognizer`，`numberOfTouchesRequired = 1`），在 F3 中标注原需求变更理由
- **[HIGH-2]** 崩溃恢复需 XPC 进程隔离 → **采纳降级方案**：NFR 改为 watchdog 模式（NSTimer 5s 检测 + 3 次重试上限）
- **[MED-1]** GIF 循环结束切换需自定义渲染器 → **采纳替代方案**：使用 0.2s crossfade 过渡，不等待循环结束
- **[MED-2]** Cross-Spaces 边缘情况 → **采纳**：F1 中记录 Stage Manager 兼容性说明
- **[MED-3]** 可访问性 vs 交互性取舍 → **采纳折中方案**：保持交互性，使用 `.nonactivatingPanel` 避免成为 key window
- **[MED-4]** 性能三点兼顾需帧管理约束 → **采纳**：添加 GIF 15fps / 30s 循环 / 惰性解码约束
- **[LOW-1]** "零代码改动" 声明过于绝对 → 限定为同类宠物
- **[LOW-3]** CAEmitterLayer 复杂度 → 添加 GIF 预合成降级方案

### 未采纳的审查意见
- 无。所有 BLOCKING/HIGH 审查意见均已采纳。

---

## 上游挑战记录
（空白，留给后续 Stage 的架构师填写）

---

## 锁定声明
本文档于 2026-06-07 锁定。后续阶段不得直接修改。
如需修改，必须通过「上游挑战记录」正式提出，经需求阶段回溯确认后方可变更。
