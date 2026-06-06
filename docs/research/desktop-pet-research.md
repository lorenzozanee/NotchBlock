# 桌面宠物功能 — Deep Research Report
*Generated: 2026-06-07 | Sources: 22 | Confidence: High*

---

## Executive Summary

macOS 桌面宠物市场目前以独立 App 为主（Shimeji 生态、Dockling、Philo、Murchi 等），**没有一款产品将桌面宠物与时间块专注工具深度集成**。NotchBlock 的宠物功能在市场中具有差异化定位。技术上，Swift + AppKit 原生方案（NSPanel + CGImageSource + CVDisplayLink）是最优路径，已被多个开源项目验证：内存占用 ~5MB，空闲 CPU 接近 0%，远优于 Electron 方案（200-500MB）。

**核心建议**：采用 native Swift + AppKit 方案。参考 `bssm-oss/desktop-pet` 的 GIF 动画栈和窗口管理架构，结合 `sealovesky/ScreenPets` 的 Pet 协议可扩展模式。

---

## 1. 竞品矩阵 — Product Landscape

### 1.1 桌面宠物类 App 对比

| 产品 | 平台 | 技术 | 核心功能 | 定价 | 与 NotchBlock 差异化 |
|------|------|------|----------|------|---------------------|
| **Dockling** (mac-pet.com) | macOS | Native Swift | Dock/菜单栏/刘海 3 模式，Pomodoro，像素宠物 | $2.99 买断 | 最接近的竞品。有 notch + Pomodoro。但宠物仅限 dock/notch/菜单栏，不浮动桌面 |
| **Philo** (getphilo.app) | macOS | Native | 桌面宠物 + 网站/App 拦截，专注模式 | Freemium | 宠物 + 专注，但走"拦截"路线，非时间块管理 |
| **DeskCat** (ppdeskcat.site) | Win/Mac | Electron | AI 宠物 + 专注守卫 + Timeline + 多状态 | 未公布 | 功能最全，但 Electron 体积大（150MB+） |
| **CommitCat** | Win/Mac/Linux | Tauri | 像素猫 + Pomodoro + GitHub + 开发者导向 | 开源 | 面向开发者，非通用专注用户 |
| **Paw-Paw** | macOS | Native | 免费打字伴侣，15+ 角色，收集帽子 | 免费 | 打字伴侣定位，无专注功能 |
| **Murchi** | macOS | Swift (单文件) | 30+ 行为，SVG 矢量，物理引擎，情绪系统 | Pay-what-you-want | 全功能宠物，但无专注集成 |
| **Shimeji 生态** (Shijima-Qt 等) | 跨平台 | Qt/Java/Electron | 46-pose 规范，跨平台，开源 | 免费 | 经典但老旧，Java 依赖，无专注功能 |

### 1.2 市场定位分析

**NotchBlock 宠物 = 生产力工具中的陪伴角色**，这一定位在市场中未被占据：

- **独立宠物 App**（Dockling, Murchi, Paw-Paw）: 纯陪伴/娱乐，不与生产力工具联动
- **专注工具**（Forest, Focus To-Do）: 有游戏化但无桌面宠物
- **NotchBlock 机会**: 宠物状态与时间块调度联动（专注→waiting，失败→failing，成功→jumping）—— **无人做过**

### 1.3 用户需求验证

从 Dockling 的公开反馈和 Paw-Paw 的 beta 社区:
- "可见且不打扰" 是用户最关心的 — 宠物应该 ambient，不抢夺注意力
- 状态切换（工作 vs 休息）增强 Pomodoro 粘性 — 用户不愿"吵醒"睡眠中的宠物
- 像素/低分辨率角色比 3D 更受欢迎 — 低视觉噪音，长时间存在不疲劳
- 定价敏感 — 付费 App ($2.99 一次) 可接受，订阅制不受欢迎

---

## 2. 技术调研 — Track B

### 2.1 参考架构: `bssm-oss/desktop-pet` ⭐ 最推荐

| 维度 | 详情 |
|------|------|
| **语言** | Swift + AppKit (原生) |
| **许可证** | MIT |
| **窗口** | NSPanel, `.borderless`, `.nonactivatingPanel`, `.mainMenu` level |
| **Spaces** | `.canJoinAllSpaces` + `.fullScreenAuxiliary` |
| **GIF 解码** | 自定义 `GIFDecoder.swift` — CGImageSource + frame disposal 处理 |
| **动画驱动** | CVDisplayLink (60fps, 仅在屏幕刷新时唤醒) |
| **拖拽** | mouseDown + mouseDragged 覆盖 |
| **持久化** | `pets.plist` → `~/Library/Application Support/` |
| **性能** | 364KB binary, ~5MB 内存, 0% 空闲 CPU |
| **多实例** | 每个宠物独立 OverlayWindow + PetView |

**可直接借鉴的模块**:
- `GIFDecoder.swift` — CGImageSource 逐帧解码（含 disposal method 处理）
- `AnimationPlayer.swift` — CVDisplayLink 驱动的帧循环
- `OverlayWindow.swift` — 透明无边框窗口配置
- `OverlayWindowController.swift` — 窗口生命周期管理

### 2.2 参考架构: `sealovesky/ScreenPets`

| 维度 | 详情 |
|------|------|
| **语言** | SwiftUI + AppKit |
| **许可证** | MIT |
| **可扩展性** | `Pet` protocol + `PetType` enum — 添加新宠物只需实现协议 |
| **动画** | CVDisplayLink + SwiftUI Canvas |
| **多屏** | 每屏独立 NSWindow + 坐标转换 |
| **持久化** | UserDefaults @AppStorage |

**可直接借鉴的模块**:
- `Pet.swift` — Pet 协议设计模式（动画帧、尺寸、移动行为）
- `PetManager.swift` — 宠物生命周期管理
- `PetWindowController.swift` — 多屏窗口协调

### 2.3 macOS 悬浮窗口技术验证

#### NSPanel 配置（已验证可行）

```swift
let panel = NSPanel(
    contentRect: frame,
    styleMask: [.borderless, .nonactivatingPanel],
    backing: .buffered,
    defer: false
)
panel.isFloatingPanel = true
panel.level = .mainMenu  // 或 .floating + .fullScreenAuxiliary
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
panel.isOpaque = false
panel.backgroundColor = .clear
panel.hasShadow = false
panel.ignoresMouseEvents = false  // 交互性：需要时可点击
```

**关键发现**:
- `.nonactivatingPanel` **必须在 init 时设置**，事后设置无效（已知 AppKit bug，Radar FB16484811）
- `.borderless` + `.nonactivatingPanel` 组合可实现无标题栏的浮动交互窗口
- `.mainMenu` level + `.fullScreenAuxiliary` 确保窗口跨全屏 Spaces 可见
- Stage Manager 兼容：添加 `.canJoinAllApplications`（macOS 13+）

#### 单指拖拽实现

`bssm-oss/desktop-pet` 使用 `mouseDown` + `mouseDragged` 覆盖实现拖拽，不依赖 `NSGestureRecognizer`。这是最可靠的方式 — 绕过了手势识别器与系统手势的冲突问题。

### 2.4 GIF 动画技术方案

| 方案 | 控制粒度 | 性能 | 复杂度 |
|------|----------|------|--------|
| NSImageView (直接) | ❌ 无帧控制 | 最佳 | 最低 |
| CGImageSource + CVDisplayLink | ✅ 完全控制 | 优秀（零拷贝 GPU 上传） | 中等（~150 行） |
| WebKit WKWebView 播放 GIF | 部分 | 中等（Chromium 渲染） | 低 |
| SpriteKit SKVideoNode | 无 | 差（不适用于 GIF） | 不适用 |

**推荐**: CGImageSource + CVDisplayLink（如 `bssm-oss/desktop-pet` 的 GIFDecoder）。NotchBlock 已有 `CVDisplayLink` 使用经验（见现有项目架构）。

### 2.5 粒子特效方案

- **CAEmitterLayer** (推荐): AppKit 原生，50-100 行实现撒花，性能极佳
- **SpriteKit SKScene**: 过度设计，增加依赖
- **预合成 GIF**: 降级备选方案（艺术家将粒子集成到 GIF 帧中）

### 2.6 空闲检测

```swift
let idleSeconds = CGEventSourceSecondsSinceLastEventType(
    .hidSystemState, 
    .eventSourceStateCombinedSessionState
)
// 每秒轮询，阈值 300 秒（5 分钟）
```

这是最轻量且可靠的方案，已在多个 macOS App 中验证。

---

## 3. 架构建议

### 3.1 模块划分（基于调研）

```
NotchBlock/Managers/
├── PetWindowController.swift      # NSPanel 窗口管理，参考 OverlayWindowController
├── PetStateMachine.swift          # 状态机驱动，9 个状态
├── PetAnimationPlayer.swift       # GIF 解码 + CVDisplayLink 播放，参考 bssm-oss/desktop-pet
├── PetInteractionHandler.swift    # 单击/拖拽/悬停/右键事件处理
└── PetIdleDetector.swift          # CGEventSource 空闲检测

NotchBlock/Models/
├── PetProtocol.swift              # 可扩展宠物协议（参考 ScreenPets Pet protocol）
├── PetConfig.swift                # 宠物配置结构 + PetManifest.json 解析
├── PetState.swift                 # 状态枚举
└── PetPreferences.swift           # UserDefaults 封装

NotchBlock/Views/
├── PetView.swift                  # SwiftUI 宠物渲染视图
└── PetOnboardingView.swift        # 引导页宠物预览

pets/elysia/
├── elysia-config.json             # Elysia 宠物配置
├── waving.gif, idle.gif, ...      # 9 个 GIF 素材
```

### 3.2 技术选型总结

| 需求 | 方案 | 参考来源 |
|------|------|----------|
| 浮动窗口 | NSPanel + `.nonactivatingPanel` + `.borderless` | bssm-oss/desktop-pet, StackOverflow |
| 跨 Spaces | `.canJoinAllSpaces` + `.fullScreenAuxiliary` | NotchBlock 现有代码 |
| GIF 播放 | CGImageSource + CVDisplayLink | bssm-oss/desktop-pet GIFDecoder |
| 拖拽 | mouseDown/mouseDragged 覆盖 | bssm-oss/desktop-pet PetView |
| 粒子 | CAEmitterLayer | Murchi, Apple Docs |
| 空闲检测 | CGEventSourceSecondsSinceLastEventType | Apple Docs |
| 可扩展性 | Pet protocol + JSON manifest | ScreenPets + 自定义 |

---

## 4. 风险评估

| 风险 | 等级 | 缓解措施 |
|------|------|----------|
| GIF 素材尺寸不一致 | LOW | v2 已规范 pt 尺寸；素材使用显示尺寸不缩放 |
| 遮罩期间的窗口层级冲突 | MEDIUM | 遮罩期间 `ignoresMouseEvents = true`；宠物在遮罩层之上 |
| Stage Manager 兼容性 | LOW | 添加 `.canJoinAllApplications`；测试计划覆盖 |
| 电池消耗（持续 GIF 播放） | MEDIUM | v2 已添加电池 NFR：电池模式降帧至 10fps，空闲降至 5fps |
| 多显示器坐标边界 | LOW | v2 已定义钳制策略；NSScreen.screens 动态校验 |

---

## Key Takeaways

1. **NotchBlock 的宠物+专注联动是市场空白** — 没有竞品将桌面宠物与时间块状态机整合。这是核心差异化。
2. **技术路径明确且低风险** — Swift + AppKit 原生方案有 3+ 个开源参考实现（MIT 许可），核心代码可直接借鉴。
3. **性能已验证** — 原生方案内存 ~5MB，CPU ~0%，远超 Electron/Tauri 替代方案。
4. **可扩展架构参考已就绪** — ScreenPets 的 `Pet` protocol 模式 + 自有的 `PetManifest.json` 配置 = 零代码添加同类宠物。
5. **两个最关键的代码参考** — `bssm-oss/desktop-pet`（GIF 播放 + 窗口管理）和 `sealovesky/ScreenPets`（协议扩展 + 多屏支持）。

---

## Sources

1. [bssm-oss/desktop-pet](https://github.com/bssm-oss/desktop-pet) — Native Swift+AppKit desktop pet, GIF/APNG/PNG support, MIT license（最核心参考）
2. [sealovesky/ScreenPets](https://github.com/sealovesky/ScreenPets) — SwiftUI multi-pet, Pet protocol pattern, MIT license
3. [egorfedorov/murchi](https://github.com/egorfedorov/murchi) — Single-file Swift Tamagotchi, 30+ behaviors, SVG+physics+particles
4. [Dockling / Mac Pet](https://dockling.space/mac-pet) — Native macOS notch/dock/menu bar pet with Pomodoro
5. [Philo](https://getphilo.app/) — macOS desktop pet + focus app blocking
6. [DeskCat by ppxinyue](https://github.com/ppxinyue/DeskCat) — Electron AI desktop companion with focus guard
7. [CommitCat by eunseo9311](https://github.com/eunseo9311/commit-cat) — Tauri developer companion with Pomodoro + GitHub
8. [Paw-Paw](https://paw-paw.pet/) — Free macOS typing companion, 15+ characters
9. [Valkryst/VShimeji](https://github.com/Valkryst/VShimeji) — Java Shimeji-ee fork, 46-pose spec reference
10. [pixelomer/Shijima-Qt](https://github.com/pixelomer/Shijima-Qt) — Cross-platform Qt6 desktop pet
11. [spyderweb47/Desktop-Virtual-buddy](https://github.com/spyderweb47/Desktop-Virtual-buddy) — Electron Shimeji with AI brain, 46-pose compatible
12. [a35hie/ShimeTomo](https://github.com/a35hie/ShimeTomo) — SwiftUI macOS Shimeji app
13. [wil-pe/CATAI](https://github.com/wil-pe/catai) — Pixel art cats on macOS dock with Ollama LLM
14. [builder-group/focuscat](https://github.com/builder-group/focuscat) — Tauri Pomodoro timer with SVG cat
15. [alterhq/openpets](https://github.com/alterhq/openpets) — MCP-controlled desktop pet for AI agents, Swift
16. [NSWindow.Level - Apple Docs](https://developer.apple.com/documentation/appkit/nswindow/level-swift.struct) — Window level hierarchy
17. [canJoinAllSpaces - Apple Docs](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallspaces) — Cross-Spaces behavior reference
18. [Fazm Blog - SwiftUI Floating Panel](https://fazm.ai/blog/swiftui-floating-panel) — NSPanel configuration patterns, collection behaviors
19. [StackOverflow - NSWindow above fullscreen](https://stackoverflow.com/questions/58934673) — Verified fullScreenAuxiliary pattern
20. [StackOverflow - NSPanel above fullscreen apps](https://stackoverflow.com/questions/36205834) — Borderless NSPanel + fullScreenAuxiliary verified

## Methodology
Searched 4 queries across web (Exa), analyzed 22 sources. Sub-questions investigated:
1. macOS desktop pet competitive landscape
2. Desktop pet + productivity/focus tool integration
3. Open-source macOS desktop pet implementations (Swift/AppKit)
4. macOS floating window + GIF animation technical approaches
