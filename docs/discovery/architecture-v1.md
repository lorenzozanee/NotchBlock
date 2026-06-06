# Desktop Pet — Architecture Design v1

## Overview

```
┌─────────────────────────────────────────────────────────┐
│                    NotchBlockApp                         │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │ TimeBlockStore│  │BlockScheduler│  │ OnboardingWC  │  │
│  │ (@Published)  │  │  (1s poll)   │  │  (existing)    │  │
│  └──────┬───────┘  └──────┬───────┘  └───────┬───────┘  │
│         │                 │                   │          │
│         ▼                 ▼                   ▼          │
│  ┌──────────────────────────────────────────────────┐   │
│  │              PetStateMachine                      │   │
│  │  ┌─────┐  ┌──────┐  ┌──────┐  ┌────────────┐    │   │
│  │  │ idle │─▶│focusing│─▶│failed│  │ succeeded   │    │   │
│  │  └─────┘  └──────┘  └──────┘  └────────────┘    │   │
│  │     ▲         │          │            │          │   │
│  │     └─────────┴──────────┴────────────┘          │   │
│  │               (60s auto-return)                   │   │
│  └──────────────────────┬───────────────────────────┘   │
│                         │ state enum                    │
│                         ▼                               │
│  ┌──────────────────────────────────────────────────┐   │
│  │            PetAnimationPlayer                      │   │
│  │  CGImageSource + CVDisplayLink + crossfade        │   │
│  └──────────────────────┬───────────────────────────┘   │
│                         │ CGImage frames                │
│                         ▼                               │
│  ┌──────────────────────────────────────────────────┐   │
│  │              PetWindowController                   │   │
│  │  NSPanel(.borderless + .nonactivatingPanel)       │   │
│  │  .fullScreenAuxiliary + .canJoinAllSpaces         │   │
│  │  mouseDown/mouseDragged + NSTrackingArea          │   │
│  └──────────────────────────────────────────────────┘   │
│                         │                               │
│                         ▼                               │
│  ┌──────────────────────────────────────────────────┐   │
│  │                 PetView (SwiftUI)                   │   │
│  │  NSHostingView wrapping PetContentView            │   │
│  │  NSMenu (right-click)                             │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## Module Design

### 1. `PetProtocol` — Extensibility Contract

```swift
protocol PetProtocol {
    var name: String { get }
    var displayName: String { get }
    var animations: [PetState: URL] { get }  // state -> GIF file URL
    var defaultSize: CGSize { get }
}

struct ElysiaPet: PetProtocol {
    let name = "elysia"
    let displayName = "Elysia"
    var animations: [PetState: URL]  // loaded from pets/elysia/
    let defaultSize = CGSize(width: 120, height: 120)
}
```

### 2. `PetState` — State Enum (9 states, priority-ordered)

```swift
enum PetState: Int, Comparable {
    case initial = 0      // waving.gif
    case idle = 1         // idle.gif (baseline)
    case idleMicro = 2    // blink.gif / stretch.gif (P1, deferred)
    case sleeping = 3     // sleeping.gif (P2, deferred)
    case focusing = 4     // waiting.gif / idle.gif random
    case succeeded = 5    // jumping.gif (60s → idle/focusing)
    case failed = 6       // failing.gif (60s → idle/focusing)
    case draggingLeft = 7
    case draggingRight = 8
}
// Priority: rawValue descending = higher priority
```

### 3. `PetStateMachine` — State Transitions

```
States active in MVP (P0):
  initial ──(first interaction)──▶ idle
  idle ──(focus starts)──▶ focusing
  focusing ──(focus ends: success)──▶ succeeded (60s timer)
  focusing ──(focus ends: miss)──▶ failed (60s timer)
  succeeded ──(60s elapsed)──▶ idle (or focusing if active)
  failed ──(60s elapsed)──▶ idle (or focusing if active)
  any ──(drag start, dx < 0)──▶ draggingLeft
  any ──(drag start, dx > 0)──▶ draggingRight
  draggingLeft/Right ──(drag end)──▶ previous state
```

### 4. `PetAnimationPlayer` — GIF Rendering

```
Input: GIF file URL
Output: CGImage frames dispatched via CVDisplayLink

Flow:
  1. CGImageSourceCreateWithURL(gifURL)
  2. Pre-decode frames 0-3 (instant playback start)
  3. CVDisplayLink callback @ display refresh rate
  4. On callback: advance frame index, lazy-decode if past preload
  5. On state change: start crossfade timer (0.2s)
     ─ double-buffer: old animation fades out, new fades in
  6. On loop end: if not crossfading, reset frame index to 0
  7. Battery mode: skip frames to hit target FPS (15→10→5)

Dependencies: ImageIO, CoreVideo, QuartzCore
Reference: bssm-oss/desktop-pet GIFDecoder.swift + AnimationPlayer.swift
```

### 5. `PetWindowController` — Window Management

```
NSPanel configuration:
  styleMask: [.borderless, .nonactivatingPanel]
  level: .mainMenu (or .floating + .fullScreenAuxiliary)
  collectionBehavior: [.canJoinAllSpaces, .fullScreenAuxiliary]
  isOpaque: false
  backgroundColor: .clear
  hasShadow: false
  isMovableByWindowBackground: false  // manual drag handling

Window lifecycle:
  - Created on app launch if pet.enabled == true
  - Position restored from UserDefaults
  - NSTrackingArea for hover detection
  - mouseDown/mouseDragged for drag
  - rightMouseDown for NSMenu
  - Watchdog: NSTimer 5s check → recreate if nil + enabled

Reference: NotchBlock OverlayWindowController (same .fullScreenAuxiliary pattern)
```

### 6. `PetInteractionHandler` — Event Processing

```
Event       → Action
click       → NotchPanelController.show() (reuse existing)
drag start  → setState(.draggingLeft/Right), begin movement
drag move   → update window position, clamp to screen bounds
drag end    → save position, restore previous state
hover enter → scale 1.1x + alpha 1.0, 0.2s ease-out
hover exit  → scale 1.0 + alpha 0.85, 0.2s ease-out
right-click → NSMenu.popUp()

Debounce: 0.3s between clicks
Edge clamp: 20pt margin from visible frame
```

### 7. `PetPreferences` — Persistence

```swift
// All stored in UserDefaults
extension UserDefaults {
    @objc dynamic var petEnabled: Bool       // default: true (new), false (upgrade skip)
    @objc dynamic var petSelected: String     // "elysia"
    @objc dynamic var petPositionX: Double    // screen coordinate
    @objc dynamic var petPositionY: Double
    @objc dynamic var petHideInFullscreen: Bool  // default: false (deferred P2)
    @objc dynamic var petHasCompletedOnboarding: Bool
}
```

## Data Flow

```
TimeBlockStore.blocks (@Published)
    │
    ▼
PetStateMachine.evaluate(currentBlocks)
    │  checks: any block .isActive? → .focusing
    │          any block .status == .completed? → .succeeded
    │          any block .status == .missed? → .failed
    │          else → .idle
    ▼
PetAnimationPlayer.setAnimation(for: newState)
    │
    ▼
PetWindowController.petView.updateContent(frames, crossfade)
```

## File Layout

```
NotchBlock/
├── Managers/
│   ├── PetWindowController.swift      (NSPanel lifecycle, ~150 lines)
│   ├── PetStateMachine.swift          (9-state FSM, ~100 lines)
│   ├── PetAnimationPlayer.swift       (CGImageSource + CVDisplayLink, ~250 lines)
│   └── PetInteractionHandler.swift    (mouse events, ~100 lines)
├── Models/
│   ├── PetProtocol.swift              (protocol + ElysiaPet, ~50 lines)
│   ├── PetState.swift                 (enum, ~30 lines)
│   ├── PetConfig.swift                (PetManifest.json parser, ~60 lines)
│   └── PetPreferences.swift           (UserDefaults wrapper, ~40 lines)
├── Views/
│   ├── PetView.swift                  (SwiftUI content, ~100 lines)
│   └── PetOnboardingView.swift        (onboarding page, ~80 lines)
pets/
└── elysia/
    ├── elysia-config.json             (manifest)
    ├── waving.gif, idle.gif, waiting.gif,
    │   failing.gif, jumping.gif,
    │   running-left.gif, running-right.gif,
    │   review.gif                     (9 existing assets)
```

## Integration Points

| Integration | Existing Component | Change Required |
|-------------|-------------------|-----------------|
| State source | `TimeBlockStore` | None — observe `$blocks` publisher |
| Focus events | `BlockScheduler` | None — hook into existing block status changes |
| Panel popup | `NotchPanelController` | None — call existing `.show()` |
| Onboarding | `OnboardingWindowController` | Add 1 page (pet selection) |
| Preferences | `MainSchedulerView` | Add 1 toggle row (future) |
| App lifecycle | `NotchBlockApp` | Initialize PetWindowController on launch |
