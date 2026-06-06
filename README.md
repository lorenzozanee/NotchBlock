# NotchBlock

<p align="center">
  <img src="icon.png" alt="NotchBlock Icon" width="128" height="128">
</p>

<p align="center">
  <strong>Turn the Mac hardware notch into a time-blocking gateway.</strong>
</p>

<p align="center">
  <a href="https://github.com/lorenzozanee/NotchBlock/releases"><img src="https://img.shields.io/github/v/release/lorenzozanee/NotchBlock?color=blue" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="License: MIT"></a>
  <a href="#"><img src="https://img.shields.io/badge/platform-macOS%2014.0%2B-orange" alt="macOS 14.0+"></a>
  <a href="#"><img src="https://img.shields.io/badge/swift-6.1-FA7343?logo=swift" alt="Swift 6.1"></a>
</p>

<p align="center">
  <sub>English | <a href="README_ZH.md">中文</a> | <a href="README_FR.md">Français</a> | <a href="README_ES.md">Español</a> | <a href="README_JA.md">日本語</a> | <a href="README_KO.md">한국어</a></sub>
</p>

---

NotchBlock is a minimalist, **enforced** time-blocking scheduler for macOS. It transforms the hardware notch into an invisible interaction point, and uses an unmissable full-screen overlay to interrupt you when a task ends — keeping you focused by force.

> 🎯 Hover over the notch → see today's schedule → full-screen reminder at task end → must confirm completion

## ✨ Features

| Feature | Description |
|---|---|
| 🔲 **Notch Hover Panel** | Hover over the notch for 0.5s — your schedule slides out gracefully |
| 🛡️ **Fullscreen Aware** | Auto-pauses notch detection during video, gaming, and presentations |
| ⚡ **Hard Interrupt Overlay** | Full-screen dimming overlay at task end — blocks all other interaction |
| ⏱️ **5‑Minute Timeout** | Unacknowledged blocks are auto-marked "missed" with a system notification |
| 📋 **Daily Scheduler** | Minimal timeline list with automatic time‑conflict detection |
| 🔄 **History Correction** | Manually adjust task status for accurate time‑tracking review |
| 🚀 **Launch at Login** | One‑click toggle from the menu bar; runs quietly in the background |
| 💾 **Local Storage** | All data stored locally — no network, fully private |

## 📥 Installation

Download the latest `NotchBlock-*.dmg` from [Releases](https://github.com/lorenzozanee/NotchBlock/releases).

### 3‑Step Setup

After opening the DMG, follow the on‑window instructions:

1. **Drag to Applications** — drop `NotchBlock.app` into your `Applications` folder
2. **Double‑click `FixQuarantine.command`** — removes the quarantine attribute and launches the app (first launch requires right‑click → Open)
3. **Done** — the menu bar icon appears; you're ready to go

> 💡 Why step 2? NotchBlock is not notarized by Apple (requires a $99/yr developer account). macOS quarantines downloaded apps. `FixQuarantine.command` runs `xattr -cr /Applications/NotchBlock.app` to clear this flag.

After first launch, grant these permissions:

| Permission | Purpose | Settings Path |
|---|---|---|
| **Accessibility** | Detecting fullscreen apps | System Settings → Privacy & Security → Accessibility |
| **Notifications** | Task timeout alerts | System Settings → Notifications → NotchBlock |

### Manual Install

```bash
# If the DMG script won't run, do it manually:
xattr -cr /Applications/NotchBlock.app
open /Applications/NotchBlock.app
```

## 🏗️ Architecture

```
macOS 14.0+ · Swift 6.1 · SwiftUI + AppKit
```

**Key APIs:**

- `NSTrackingArea` — notch‑region mouse tracking
- `NSPanel` + `.nonactivatingPanel` — dropdown panel (doesn't steal focus)
- `CGShieldingWindowLevel()` + `.fullScreenAuxiliary` — overlay that punches through
- `CGWindowList` — fullscreen state detection
- `SMAppService` — login item registration
- `UserNotifications` — timeout banner alerts
- `UserDefaults` / ISO 8601 JSON — local persistence

**Project structure:**

```
NotchBlock/
├── Models/           TimeBlock · BlockStatus
├── Managers/         TimeBlockStore · NotchTracker · NotchPanelController
│                     OverlayWindowController · BlockScheduler
├── Views/            MainSchedulerView · TimeBlockRowView · AddEditBlockView
│                     NotchPanelView · OverlayView
└── Utilities/        DateExtensions · LaunchManager
```

## ⌨️ Shortcuts

| Shortcut | Action |
|---|---|
| `⌘O` | Open scheduler panel |
| `⌘Q` | Quit NotchBlock |

## 📝 Development

```bash
# Regenerate the Xcode project after adding/removing .swift files
python3 generate_xcode_project.py

# CLI build
xcodebuild -project NotchBlock.xcodeproj -scheme NotchBlock -configuration Release build

# Create DMG
./scripts/build-dmg.sh
```

## 📄 License

[MIT License](LICENSE)

---

<p align="center">
  <sub>Built with ❤️ for focused work · macOS Apple Silicon</sub>
</p>
