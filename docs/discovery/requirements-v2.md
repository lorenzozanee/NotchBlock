# NotchBlock v0.5.1 — Requirements Document v2 【LOCKED】

**锁定日期**: 2026-06-05 | **复杂度**: Small（≤1月）

---

## 项目概述

NotchBlock 是 macOS 时间块强制执行工具。v0.6.0 核心功能已就绪。v0.5.1 聚焦 UI/UX 打磨和用户引导。

---

## 用户故事

### Feature 3: 自定义图标 + UI 美化
- **P0**: 自定义菜单栏图标（预设 4 种样式） + 排版面板视觉升级
- **P0**: 统一品牌色（靛蓝 #4F46E5 系）+ 卡片化布局
- **P1**: NotchPanel 动画优化、Overlay 视觉改进

### Feature 4: 首次启动配置向导
- **P0**: 3 步引导窗口（欢迎 → 偏好 → 完成），替换现有欢迎通知
- **P0**: 配置数据持久化 UserDefaults（defaultFocusStart/End, launchAtLogin）
- **P1**: 引导后自动创建今日示例任务

### Feature 5: 排程面板优化
- **P0**: 时间轴可视化（左侧时间刻度 06:00-24:00，右侧任务块按时间比例）
- **P0**: 状态颜色编码（品牌蓝 pending / 绿 active / 灰 completed / 红 missed）
- **P1**: 空状态引导卡片 + 任务行 hover 快捷操作

---

## 功能需求

### FR-3: 图标与 UI
| ID | 需求 | 优先级 |
|----|------|--------|
| FR-3.1 | 生成 App 图标：靛蓝底色 + 白色计时器/方块图形（AI 生成 1024x1024） | P0 |
| FR-3.2 | 菜单栏图标选项：`timer` / `clock` / `square` / `circle` — UserDefaults 存储 | P0 |
| FR-3.3 | 排程面板卡片化：`.continuous` 圆角、`.ultraThinMaterial` 背景、8pt 卡片间距 | P0 |
| FR-3.4 | 统一品牌色：`accentColor = Color(hex: "#4F46E5")`，Light/Dark 自适应 | P0 |
| FR-3.5 | NotchPanel 动画：spring(response: 0.35, dampingFraction: 0.75) | P1 |
| FR-3.6 | Overlay 倒计时字体增大 33%、背景增加 radial gradient | P1 |

### FR-4: 首次启动配置
| ID | 需求 | 优先级 |
|----|------|--------|
| FR-4.1 | OnboardingView：3 页 TabView，`.page` 样式，右上角「跳过」按钮 | P0 |
| FR-4.2 | 第 1 页：简介 3 大功能（刘海预览、时间块排程、全屏专注）+ 插图 | P0 |
| FR-4.3 | 第 2 页：DatePicker 设置「每日起始时间」和「每日结束时间」，Toggle 开机自启 | P0 |
| FR-4.4 | 第 3 页：确认 + 「开始使用」Button，关闭向导、打开主窗口 | P0 |
| FR-4.5 | `hasCompletedOnboarding` key in UserDefaults，后续启动跳过 | P0 |
| FR-4.6 | 引导完成后自动创建 3 条今日示例 block（如果当天无任务） | P1 |

### FR-5: 排程面板
| ID | 需求 | 优先级 |
|----|------|--------|
| FR-5.1 | TimelineView：ScrollView 内 Canvas/GeometryReader 绘制时间轴 | P0 |
| FR-5.2 | 状态色：pending=`.blue`、active=`.green`（pulsing）、completed=`.secondary`、missed=`.red` | P0 |
| FR-5.3 | 空状态：首次无任务时显示引导卡片「⌘N 添加第一个任务」+ SF Symbol 动画 | P1 |
| FR-5.4 | 列表/时间轴切换 Toggle（Picker segmented） | P1 |

---

## 审查追溯

### 一致性审查采纳
- **AMBIGUOUS** 「UI要有吸引力」→ 具体化为 FR-3.3~FR-3.6 可量化指标
- **AMBIGUOUS** 「App 图标设计」→ FR-3.1 明确 AI 生成 + 靛蓝/白色配色
- **GAP** 引导后用户不知道下一步 → FR-4.6 自动创建示例任务填补
- **DEPENDENCY MISMATCH** FR-5.5 拖拽功能依赖 FR-5.1 时间轴 → 降为 P2，本次不做

### 可行性审查采纳
- **MEDIUM** SwiftUI 纯时间轴视图 → 用 `Canvas` + `GeometryReader` 可行
- **LOW** 自定义图标生成 → AI 工具 + sips 转 icns
- **LOW** 向导页面 → 标准 SwiftUI TabView
- **无 BLOCKER**

---

## 锁定声明
本文档于 2026-06-05 锁定。后续阶段不得直接修改。
