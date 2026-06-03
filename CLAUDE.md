# NotchBlock — 刘海时间块

macOS 时间块强制执行工具。将 Mac 硬件刘海转化为隐形交互入口，通过全屏遮罩强提醒保持专注。

## Stack

- **Language:** Swift 6.1
- **UI:** SwiftUI + AppKit (NSPanel, NSTrackingArea)
- **Persistence:** UserDefaults / JSON (via `TimeBlockStore`)
- **Min target:** macOS 14.0 (Sonoma)
- **Build tool:** Xcode 16.4 (project generated via `generate_xcode_project.py`)

## Build

```bash
# Regenerate Xcode project (after adding/removing files)
python3 generate_xcode_project.py

# Build from CLI
xcodebuild -project NotchBlock.xcodeproj -scheme NotchBlock -configuration Debug build

# Open in Xcode
open NotchBlock.xcodeproj
```

## Run

1. Open `NotchBlock.xcodeproj` in Xcode
2. Select **NotchBlock** scheme → **My Mac**
3. ⌘R to build & run
4. App appears as menu bar icon (no Dock icon — `LSUIElement = YES`)
5. Grant **Accessibility** permission when prompted (System Settings → Privacy)

## Project Structure

```
NotchBlock/
├── Models/          # TimeBlock, BlockStatus
├── Managers/        # TimeBlockStore, NotchTracker, NotchPanelController,
│                    # OverlayWindowController, BlockScheduler
├── Views/           # MainSchedulerView, TimeBlockRowView, AddEditBlockView,
│                    # NotchPanelView, OverlayView
└── Utilities/       # DateExtensions, LaunchManager
```

## Adding Files

1. Create the `.swift` file in the appropriate subdirectory
2. Add it to the `files` list in `generate_xcode_project.py`
3. Add it to the correct group's `children()` list
4. Run `python3 generate_xcode_project.py`

## Key Architecture Notes

- **NotchTracker** creates a transparent borderless window at the notch position with NSTrackingArea for mouse enter/exit. Uses 0.5s debounce before triggering. Disabled during fullscreen (CGWindowList detection).
- **NotchPanelController** manages an NSPanel with `.nonactivatingPanel` style — floats above other windows without stealing focus.
- **OverlayWindowController** uses `CGShieldingWindowLevel()` + `.fullScreenAuxiliary` to appear over fullscreen spaces. 5-minute timeout before auto-marking as `.missed`.
- **BlockScheduler** polls every 1s checking for `.pending` blocks whose `endTime` has passed.
- **TimeBlockStore** persists to UserDefaults as ISO8601 JSON. Exposes `@Published var blocks` for SwiftUI reactivity.
