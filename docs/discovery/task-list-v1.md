# Desktop Pet — Task List v1

## MVP (P0 Must-Have) — Estimated 3-4 weeks

### Sprint 1: Foundation (Week 1)

| # | Task | Files | Acceptance Criteria | Est. |
|---|------|-------|---------------------|------|
| T1.1 | **PetProtocol + PetState enum** | `Models/PetProtocol.swift`, `Models/PetState.swift` | Protocol defines `name`, `displayName`, `animations`, `defaultSize`. State enum has 9 cases with `Comparable` priority. ElysiaPet conforms. Tests pass. | 0.5d |
| T1.2 | **PetConfig + PetManifest parser** | `Models/PetConfig.swift` | Parse `pets/elysia/elysia-config.json` → `PetConfig`. Map state→GIF URL. Handle missing config (fallback to naming convention). Tests pass. | 0.5d |
| T1.3 | **PetPreferences (UserDefaults)** | `Models/PetPreferences.swift` | 6 keys. Default values. Observer pattern for `petEnabled` toggling. Position clamping on screen change. Tests pass. | 0.5d |
| T1.4 | **PetAnimationPlayer — GIF decoder** | `Managers/PetAnimationPlayer.swift` | CGImageSource load GIF. Pre-decode 3-5 frames. CADisplayLink-driven playback. Loop handling. Missing/corrupt GIF fallback. Tests pass. | 1.5d |
| T1.5 | **PetAnimationPlayer — crossfade** | Same file | 0.2s opacity transition between state changes. Double-buffer rendering. Tests pass. | 0.5d |
| T1.6 | **PetWindowController — NSPanel setup** | `Managers/PetWindowController.swift` | Borderless NSPanel, `.nonactivatingPanel`, `.canJoinAllSpaces`, `.fullScreenAuxiliary`. Clear background. Position restore from UserDefaults. Tests: window config correct. | 0.5d |

### Sprint 2: State + Interaction (Week 2)

| # | Task | Files | Acceptance Criteria | Est. |
|---|------|-------|---------------------|------|
| T2.1 | **PetStateMachine** | `Managers/PetStateMachine.swift` | Observe TimeBlockStore. Transition logic: idle↔focusing↔failed/succeeded. 60s timers for succeeded/failed → auto-return. Priority chain. Tests: all transitions covered. | 1d |
| T2.2 | **PetView (SwiftUI content)** | `Views/PetView.swift` | NSHostingView wrapping GIF frame display. Alpha animation for hover. SwiftUI overlay for context menu trigger. Tests: view renders without crash. | 0.5d |
| T2.3 | **PetInteractionHandler — click + drag** | `Managers/PetInteractionHandler.swift` | mouseDown: differentiate click vs drag (3pt threshold). Click: debounce 0.3s, call NotchPanelController.show(). Drag: move window, set draggingLeft/Right state, clamp to screen bounds. Drag end: save position, restore state. Tests: gesture differentiation. | 1d |
| T2.4 | **PetInteractionHandler — hover + right-click** | Same file | NSTrackingArea for mouse enter/exit. Scale+alpha animation on hover. rightMouseDown → NSMenu (Hide/Switch/Settings). Tests: hover triggers, menu items correct. | 0.5d |
| T2.5 | **Wire all components** | `Managers/PetWindowController.swift` | Connect StateMachine → AnimationPlayer → PetView → InteractionHandler. End-to-end: focus starts → pet plays waiting.gif. Focus succeeds → pet plays jumping.gif for 60s. Tests: integration test. | 0.5d |

### Sprint 3: Integration + Polish (Week 3)

| # | Task | Files | Acceptance Criteria | Est. |
|---|------|-------|---------------------|------|
| T3.1 | **Onboarding integration** | `Views/PetOnboardingView.swift`, `Managers/OnboardingWindowController.swift` | Add pet selection page to onboarding flow. Show GIF preview (NSImageView wrapper). "Enable elysia" / "Not now" buttons. Store choice to UserDefaults. Tests: onboarding flow with pet selection. | 1d |
| T3.2 | **Watchdog + error recovery** | `Managers/PetWindowController.swift` | NSTimer 5s check: if petWindow == nil && petEnabled, recreate. Max 3 consecutive recreates, then stop + OSLog error. Tests: crash simulation. | 0.5d |
| T3.3 | **Battery-aware frame rate** | `Managers/PetAnimationPlayer.swift` | Detect power source. Battery: 10fps. Idle 30s: 5fps. AC: original FPS. Smooth transition. Tests: frame rate changes. | 0.5d |
| T3.4 | **Multi-monitor position clamping** | `Managers/PetWindowController.swift` | On screen config change: validate position is within any screen bounds. Clamp to 20pt margin. Tests: display hotplug simulation. | 0.5d |
| T3.5 | **E2E testing + bug fixes** | All | Manual test: full user journey (install → onboarding → focus → succeed → fail → drag → hide → re-enable). Multi-monitor. Stage Manager. Fullscreen. Battery. | 1d |

---

## P1 (Should Have) — Post-MVP

| # | Task | Acceptance Criteria | Depends On |
|---|------|---------------------|------------|
| T4.1 | idle-micro animations | blink.gif/stretch.gif exist in assets. Random trigger 8-20s during idle. Tests pass. | P0 shipped, assets created |
| T4.2 | Keyboard shortcut Cmd+Shift+P | Global hotkey toggles pet.show/hide. Tests pass. | P0 shipped |
| T4.3 | Preferences toggle in MainSchedulerView | "Show Desktop Pet" switch in existing UI. Tests pass. | P0 shipped |
| T4.4 | Screen saver/lock hide-restore | NSWorkspace notifications. Hide on screen saver, restore on unlock. Tests pass. | P0 shipped |

## P2 (Nice to Have) — Future

| # | Task | Acceptance Criteria |
|---|------|---------------------|
| T5.1 | Sleeping state (idle 5min) | CGEventSource polling. Sleep animation. Interrupt on activity. |
| T5.2 | Fullscreen hide option | pet.hideInFullscreen = true hides pet during fullscreen. |
| T5.3 | Multi-pet switching | PetManifest loads new pet. Right-click switch. Animated transition. |
| T5.4 | CAEmitterLayer particles (F9) | Confetti on succeeded. 30-50 particles. 3s duration. Follows pet position. |
