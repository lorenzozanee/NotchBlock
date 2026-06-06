# NotchBlock 刘海时间块

<p align="center">
  <img src="icon.png" alt="NotchBlock Icon" width="128" height="128">
</p>

<p align="center">
  <strong>将 Mac 硬件刘海转化为时间管理入口</strong>
</p>

<p align="center">
  <a href="https://github.com/lorenzozanee/NotchBlock/releases"><img src="https://img.shields.io/github/v/release/lorenzozanee/NotchBlock?color=blue" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="License: MIT"></a>
  <a href="#"><img src="https://img.shields.io/badge/platform-macOS%2014.0%2B-orange" alt="macOS 14.0+"></a>
  <a href="#"><img src="https://img.shields.io/badge/swift-6.1-FA7343?logo=swift" alt="Swift 6.1"></a>
</p>

<p align="center">
  <sub><a href="README.md">English</a> | 中文 | <a href="README_FR.md">Français</a> | <a href="README_ES.md">Español</a> | <a href="README_JA.md">日本語</a> | <a href="README_KO.md">한국어</a></sub>
</p>

---

NotchBlock 是一款极简但**强制执行**的时间块（Time-Blocking）日程管理工具。它将 Mac 的硬件刘海转化为隐形交互入口，通过不容忽视的全屏弹窗中断机制，强迫你保持专注。

> 🎯 鼠标悬停刘海 → 查看今日排程 → 任务结束时强制全屏提醒 → 必须确认完成状态

## ✨ 功能特性

| 功能 | 说明 |
|---|---|
| 🔲 **刘海悬停面板** | 鼠标在刘海区域停留 0.5 秒，优雅滑出今日日程简报 |
| 🛡️ **全屏避让** | 看视频、打游戏、放 PPT 时自动暂停刘海检测 |
| ⚡ **硬中断遮罩** | 任务结束时强制全屏变暗，拦截所有操作 |
| ⏱️ **5 分钟超时** | 未响应自动标记「未完成」+ 系统通知 |
| 📋 **今日排班器** | 极简时间轴列表，时间冲突自动检测 |
| 🔄 **历史补录** | 手动修正任务状态，精准复盘 |
| 🚀 **开机启动** | 菜单栏一键开关，安静常驻后台 |
| 💾 **本地存储** | 数据完全本地，无需网络，隐私安全 |

## 📥 安装

从 [Releases](https://github.com/lorenzozanee/NotchBlock/releases) 页面下载最新 `NotchBlock-*.dmg`。

### 三步安装

打开 DMG 后，按照窗口背景提示操作：

1. **拖入 Applications** — 将 `NotchBlock.app` 拖到 `Applications` 文件夹
2. **双击 `FixQuarantine.command`** — 一键移除隔离标记并启动应用（首次需右键→打开）
3. **完成** — 菜单栏会出现图标，开始使用

> 💡 为什么需要第 2 步？NotchBlock 未经过 Apple 公证（需要 $99/年 的开发者账号），macOS 会对下载的应用标记隔离属性。`FixQuarantine.command` 会自动执行 `xattr -cr /Applications/NotchBlock.app` 移除此标记。

首次运行后需授权：

| 权限 | 用途 | 设置路径 |
|---|---|---|
| **辅助功能** (Accessibility) | 检测全屏应用状态 | 系统设置 → 隐私与安全性 → 辅助功能 |
| **通知** (Notifications) | 任务超时提醒 | 系统设置 → 通知 → NotchBlock |

### 手动安装

```bash
# 如果 DMG 内的脚本无法运行，手动执行：
xattr -cr /Applications/NotchBlock.app
open /Applications/NotchBlock.app
```

## 🏗️ 技术架构

```
macOS 14.0+ · Swift 6.1 · SwiftUI + AppKit
```

**关键 API：**

- `NSTrackingArea` — 刘海区域鼠标追踪
- `NSPanel` + `.nonactivatingPanel` — 下拉面板（不抢焦点）
- `CGShieldingWindowLevel()` + `.fullScreenAuxiliary` — 全屏遮罩穿透
- `CGWindowList` — 全屏状态检测
- `SMAppService` — 开机启动注册
- `UserNotifications` — 超时横幅通知
- `UserDefaults` / ISO 8601 JSON — 本地持久化

**项目结构：**

```
NotchBlock/
├── Models/           TimeBlock · BlockStatus
├── Managers/         TimeBlockStore · NotchTracker · NotchPanelController
│                     OverlayWindowController · BlockScheduler
├── Views/            MainSchedulerView · TimeBlockRowView · AddEditBlockView
│                     NotchPanelView · OverlayView
└── Utilities/        DateExtensions · LaunchManager
```

## ⌨️ 快捷键

| 快捷键 | 操作 |
|---|---|
| `⌘O` | 打开排程面板 |
| `⌘Q` | 退出 NotchBlock |

## 📝 开发

```bash
# 添加新文件后重新生成 Xcode 项目
python3 generate_xcode_project.py

# CLI 构建
xcodebuild -project NotchBlock.xcodeproj -scheme NotchBlock -configuration Release build

# 创建 DMG
./scripts/build-dmg.sh
```

## 📄 许可

[MIT License](LICENSE)

---

<p align="center">
  <sub>Built with ❤️ for focused work · macOS Apple Silicon</sub>
</p>
