# NotchBlock — 刘海时间块

macOS 菜单栏时间块强制执行工具：将 Mac 刘海转化为快捷预览入口，并在任务结束时通过全屏遮罩强提醒保持专注。

## Stack

- **Language:** Swift 6 (`SWIFT_VERSION = 6.0`, strict concurrency, `@Observable`, `@MainActor`)
- **UI:** SwiftUI + AppKit (`NSPanel`, `MenuBarExtra`, `Settings`)
- **Persistence:** `UserDefaults` JSON (`TimeBlockStore`) + Keychain (`WeChatNotifier`)
- **Min target:** macOS 14.0 (Sonoma)
- **Project generation:** `python3 generate_xcode_project.py`

## Build & Test

```bash
# Regenerate Xcode project after adding/removing Swift files or resources
python3 generate_xcode_project.py

# Build
xcodebuild -project NotchBlock.xcodeproj -scheme NotchBlock -configuration Debug build

# Run unit tests (XCTest via NotchBlockTests target)
xcodebuild test -project NotchBlock.xcodeproj -scheme NotchBlock -destination 'platform=macOS'

# Release DMG
bash scripts/build-dmg.sh
```

## Architecture

| Component | Role |
|---|---|
| `NotchTracker` | Polls `NSEvent.mouseLocation` at 10 Hz over the notched screen, suppresses when fullscreen (`CGWindowListCopyWindowInfo` + `CGDisplayBounds`) or main window is open. |
| `NotchPanelController` | Non-activating floating `NSPanel` anchored below the notched screen's menu bar/notch, dynamically sized via `fittingSize`. |
| `OverlayWindowController` | `CGShieldingWindowLevel()` + `.fullScreenAuxiliary` panels covering all displays on block end; 5-minute timeout marks `.missed`. |
| `BlockScheduler` | 1s structured task polling pending blocks; triggers overlay on end and cleans up stale overdue blocks. |
| `BreakScheduler` | Idempotently reconciles 5-minute break blocks between future consecutive user blocks. |
| `TimeBlockStore` | `@Observable @MainActor` store persisting blocks (90-day window) in `UserDefaults`. |
| `StatisticsStore` | `@Observable @MainActor` analytics over `TimeBlockStore` (excluding breaks). |
| `WeChatNotifier` | Keychain-backed WxPusher / WeCom webhook alerts on task end & timeout. |
| `UpdateChecker` | Checks GitHub Releases API, verifies/installs DMG updates, extracts `CHANGELOG.md` release notes. |

## Adding Files

1. Add the `.swift` file under `NotchBlock/` (`Models/`, `Managers/`, `Views/`, `Utilities/`) or `Tests/`.
2. Register it in `generate_xcode_project.py` and run `python3 generate_xcode_project.py`.
