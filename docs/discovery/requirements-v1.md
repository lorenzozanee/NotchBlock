# 桌面宠物功能 — Requirements Document v1

## Metadata
- Date: 2026-06-07
- Source: 用户自然语言功能描述 + 三层追问
- Analyst: Requirements Analyst Agent
- Project: NotchBlock（增量需求 — 现有 macOS 时间块专注工具的功能扩展）

## 项目概述

### 背景
NotchBlock 已有刘海悬浮面板、全屏遮罩、任务调度等核心专注功能。本次增量需求是在桌面层增加一个可交互的陪伴宠物，增强用户情感连接和使用趣味性。

### 目标
提供一个始终可见的桌面宠物，通过动画反馈反映用户的专注状态，并作为刘海面板的快捷入口。宠物系统需具备可扩展性，支持未来添加新宠物角色。

### 目标用户
所有 NotchBlock 用户。引导流程中可选择关闭宠物功能。

### 成功标准
- 宠物在 App 运行期间始终可见（跨 Spaces）
- 动画切换响应及时（< 200ms 从状态变化到动画切换）
- GIF 动画播放流畅，不影响主线程性能
- 宠物系统可扩展：添加新宠物仅需放入素材 + 配置，无需改代码

---

## User Stories

### P0 — Must Have
- [ ] As a 专注用户, I want 桌面上有一个始终可见的宠物, so that 我能感知 NotchBlock 正在运行且陪伴我专注
- [ ] As a 专注用户, I want 单击宠物弹出时间块面板（与刘海悬浮一致）, so that 我能快速查看当前专注状态
- [ ] As a 专注用户, I want 双指拖拽移动宠物位置, so that 宠物不会遮挡我的工作区域
- [ ] As a 专注用户, I want 宠物的动画反映我的专注状态（专注中/成功/失败）, so that 我能通过视觉反馈感知当前状态
- [ ] As a 新用户, I want 在引导流程中选择是否启用宠物, so that 不需要宠物的人可以关闭它

### P1 — Should Have
- [ ] As a 专注用户, I want 宠物位置和偏好被记住, so that 重启 App 后宠物回到原位
- [ ] As a 专注用户, I want 全屏/遮罩时也能看到宠物, so that 专注过程中陪伴不中断
- [ ] As a 专注用户, I want 宠物在空闲时有随机微动作（眨眼、伸懒腰）, so that 宠物看起来更生动
- [ ] As a 专注用户, I want 鼠标悬停宠物时有视觉反馈（高亮/放大）, so that 我能感知宠物是可交互的
- [ ] As a 专注用户, I want 专注完成时有庆祝动画（跳跃+撒花粒子）, so that 获得成就感反馈
- [ ] As a 专注用户, I want 右键宠物弹出快捷菜单, so that 无需进入主窗口就能切换/隐藏宠物

### P2 — Nice to Have
- [ ] As a 专注用户, I want Mac 空闲时宠物自动进入睡眠状态, so that 宠物行为更拟真
- [ ] As a 未来用户, I want 能够选择不同宠物角色, so that 我能个性化我的专注伴侣
- [ ] As a 专注用户, I want 可选择全屏时自动隐藏宠物, so that 全屏工作时不被打扰

---

## Functional Requirements

### F1: 宠物窗口（始终可见）
- **Description**: 宠物以无边框透明窗口形式显示在桌面层，跨所有 Spaces，App 运行期间始终存在。
- **Layer**: 高于桌面壁纸，低于全屏 App（除非用户允许全屏显示）。参考现有 `OverlayWindowController` 的窗口层级方案。
- **Edge cases**: 
  - App 退出时宠物窗口同步关闭
  - 多显示器场景：宠物默认出现在主显示器，可拖到副屏
  - 用户关闭宠物后，窗口完全释放不残留

### F2: 宠物动画系统
- **Description**: 根据状态切换 GIF 动画。状态机驱动，每个状态对应特定动画。
- **状态 → 动画映射**:
  | 状态 | 动画 | 持续时间 | 触发条件 |
  |------|------|----------|----------|
  | `initial` | waving | 循环至首次交互 | 宠物首次初始化 |
  | `focusing` | waiting / idle 随机切换 | 专注期间持续 | BlockScheduler 报告专注中 |
  | `failed` | failing | 60 秒 | 时间块任务失败 |
  | `succeeded` | jumping (+ 粒子特效) | 60 秒 | 时间块任务成功 |
  | `dragging-left` | running-left | 拖拽期间 | 用户向左拖拽 |
  | `dragging-right` | running-right | 拖拽期间 | 用户向右拖拽 |
  | `idle-micro` | 眨眼/伸懒腰（随机） | 短暂 | 空闲时随机触发 |
  | `sleeping` | 睡觉动画 | Mac 空闲 N 分钟后 | 系统空闲检测 |
- **Edge cases**: 
  - 动画切换时当前 GIF 播放完当前循环再切换，避免跳帧
  - 素材缺失时显示占位图形 + 日志警告
  - 多个状态同时触发时的优先级：dragging > failed/succeeded > focusing > idle

### F3: 宠物交互系统
- **Description**: 
  - **单击**: 弹出 `NotchPanelController` 管理的悬浮面板（复用现有刘海悬浮逻辑）
  - **双指拖拽**: 移动宠物窗口位置，拖拽方向触发对应 running 动画
  - **悬停**: 宠物轻微放大（1.1x）+ 亮度提升，离开时恢复
  - **右键**: 弹出 NSMenu 快捷菜单
- **Edge cases**:
  - 拖拽到屏幕边缘时限制不超出边界
  - 快速连续点击：防抖处理（0.3s 内忽略第二次点击）
  - 双指手势识别：与系统手势（如 Mission Control）不冲突

### F4: 宠物可扩展架构
- **Description**: 宠物系统设计为数据驱动。添加新宠物仅需：
  1. 在 `pets/<pet-name>/` 放入对应动画 GIF 文件
  2. 添加一个 `PetManifest.json` 或 Swift 配置结构体定义该宠物的动画映射
  3. 无需修改核心动画/窗口逻辑
- **当前实现**: 仅 `pets/elysia/`（含 9 个 GIF 素材）
- **Edge cases**:
  - 宠物配置加载失败时降级到默认宠物（elysia）
  - 未来用户切换宠物：立即切换动画，窗口位置不变

### F5: 引导集成
- **Description**: 在 `OnboardingWindowController` 引导流程中新增宠物选择页。
  - 展示宠物预览（动图）
  - 选项：启用 elysia / 暂不启用
  - 用户选择存储到 UserDefaults
- **Edge cases**:
  - 老用户升级：默认开启宠物，可在设置中关闭
  - 跳过引导：宠物默认不启用，在 Preferences 中手动开启

### F6: 宠物偏好持久化
- **Description**: 所有宠物设置存储在 UserDefaults。
  - `pet.enabled`: Bool — 是否启用宠物
  - `pet.selected`: String — 当前选中宠物名称
  - `pet.position.x`: Double — 宠物窗口 X 坐标
  - `pet.position.y`: Double — 宠物窗口 Y 坐标
  - `pet.hideInFullscreen`: Bool — 全屏时是否隐藏
- **Edge cases**:
  - 首次启动无位置数据 → 默认右下角
  - 屏幕分辨率变化导致宠物超出边界 → 钳制到可见区域

### F7: 右键快捷菜单
- **Description**: 右键宠物弹出 NSMenu：
  - "隐藏宠物" — 关闭宠物窗口
  - "切换宠物" — 子菜单列出可用宠物（当前仅 elysia）
  - "宠物设置..." — 打开 Preferences 对应标签页
- **Edge cases**: 无可用宠物时"切换宠物"灰色不可选

### F8: 空闲睡眠状态
- **Description**: 监听系统空闲，Mac N 分钟无操作后宠物进入睡眠动画。用户操作恢复时宠物醒来（waving 一次）。
- **Edge cases**: 
  - 专注中即使系统空闲也不进入睡眠（保持 waiting/idle）
  - 睡眠动画循环播放

---

## Non-Functional Requirements

| Category | Requirement |
|----------|-------------|
| **Performance** | 动画切换延迟 < 200ms；GIF 渲染不阻塞主线程；宠物窗口内存占用 < 30MB |
| **Security** | 无敏感数据处理；偏好仅本地 UserDefaults；无网络请求 |
| **Availability** | 宠物窗口崩溃后自动恢复（不影响主 App 功能） |
| **Compatibility** | macOS 14.0+；支持多显示器；支持 notch / no-notch Mac |
| **Extensibility** | 添加新宠物零代码改动；动画配置外置 |
| **Accessibility** | 宠物窗口不拦截键盘焦点；VoiceOver 可忽略宠物窗口 |

---

## Explicit Non-Goals (Out of Scope)

- 宠物不发出声音（无音效系统）
- 宠物不连接网络（无在线下载新宠物）
- 宠物不执行任何系统操作（纯视觉陪伴）
- 不支持同时显示多个宠物
- 不在菜单栏显示宠物状态图标

---

## Constraints & Assumptions

- **技术栈**: Swift 6.1 + SwiftUI + AppKit, macOS 14.0+
- **素材格式**: GIF（现有素材均为 GIF）
- **时间**: 无硬性 deadline
- **假设**: 用户有触控板或 Magic Mouse（双指手势依赖）
- **假设**: GIF 素材尺寸适中（50-150px），无需缩放适配

---

## Open Questions (待澄清)
- [ ] 空闲检测的 N 分钟具体值？（建议 5 分钟）
- [ ] 空闲睡眠是否在专注中也触发？（建议不触发）
- [ ] 多显示器场景：宠物默认在主屏还是跟随鼠标？
- [ ] GIF 播放循环切换时的过渡策略？（建议：播放完当前循环再切）
- [ ] 拖拽时的动画是 GIF 还是需要翻转素材？
