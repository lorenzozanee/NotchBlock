# Changelog

All notable changes to NotchBlock will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.2] — 2026-06-05

### Added

- **Auto-update:** Checks GitHub Releases every 6h, one-click download + install + relaunch
- **Extend time block:** +5min/+10min/custom buttons on timeout overlay; shifts subsequent tasks
- **Shift-all toggle:** Push all subsequent tasks with affected count display

### Changed

- **Timeline:** Column layout prevents overlapping blocks; adaptive height
- **Notch detection:** Instant panel trigger (0.0s debounce)
- **Live timers:** Menu bar countdown ticks every 1s; toggleable

---

## [0.6.1] — 2026-06-05

### Added

- **Custom menu bar icons:** 4 styles (timer/clock/hourglass/blocks)
- **Onboarding wizard:** 3-step first-launch setup, replaces welcome notification
- **Timeline view:** 06:00-24:00 vertical timeline, list/timeline toggle
- **Custom alert sounds:** 6 NSSound presets with menu bar picker
- **Daily summary notification:** 21:00 stats recap
- **Brand color palette:** Indigo accent (#4F46E5), semantic status colors

### Changed

- Card-based main window UI, improved empty state
- NotchPanel: smoother animations, dual-layer shadow, hover micro-interactions
- Overlay: radial gradient, larger countdown
- Custom app icon (indigo rounded rect + time blocks)

---

## [0.6.0] — 2026-06-05

### Changed

- **NotchTracker architecture rewritten:** Replaced the NSTrackingArea-based approach with `NSEvent.mouseLocation` polling at 10 Hz. Root cause discovery: macOS Window Server permanently intercepts mouse events in the menu bar region (top ~37px) regardless of NSWindow level. No window level — not `.statusBar` (25), `.popUpMenu` (101), or `overlayWindow+1` (103) — can receive NSTrackingArea events in this zone. The new polling approach reads cursor position directly from Window Server shared memory, completely bypassing the event delivery pipeline. **This is the first release where notch hover detection actually works.**

### Fixed

- **Five stacked bugs from v0.1.0 preventing notch hover:**
  1. `start()` only in `Window.onAppear` — LSUIElement apps don't auto-show windows
  2. NSTrackingArea rect was `.zero` before layout → 0×0 tracking area
  3. Tracking window entirely within menu bar event-interception zone
  4. Timer scheduled in `init()` before the run loop started processing
  5. `@StateObject` deallocated before deferred timer dispatch fired
- **`isMainWindowOpen`** now auto-detects window state via `NSApp.windows` (computed property), no longer dependent on unreliable `onAppear`/`onDisappear`
- **Main window** auto-closes at launch so notch tracking isn't permanently blocked

### Verified

- CGWarpMouseCursorPosition test: cursor held at trigger zone → `inZone=true` → 0.5s debounce → panel 320×149px appeared ✅

## [0.5.9] — 2026-06-04

### Fixed

- **Notch tracking never starts on cold launch:** `notchTracker.start()` was called only in `Window.onAppear`. Since NotchBlock is an `LSUIElement` app (no Dock icon), the main window doesn't auto-show — so the tracking window at the notch was never created on any launch after the first. Moved `start()`, `scheduler.start()`, and `requestNotificationPermission()` to `NotchBlockApp.init()` so all background services begin immediately at app launch.

## [0.5.8] — 2026-06-04

### Added

- **NotchPanel V2 redesign:** Complete overhaul of the notch-triggered dropdown panel. Frosted-glass UI with 18px radius, gradient border, large 28pt countdown timer, dynamic height, empty state. Read-only glance surface — tap any task to open the main scheduler. Supports up to 5 upcoming tasks (scrollable). Mouse-on-panel keeps it visible; 0.5s leave debounce for gentle fade-out.
- **Mutual exclusion:** Main scheduler window open → notch hover suppressed. No double-panel scenarios.
- **Thread safety:** `NSScreen.main` hoisted to main thread before `CGWindowListCopyWindowInfo` background dispatch. Timer uses `Timer.publish(.common)` to prevent countdown freeze during tracking-area interactions.
- **Show/hide race protection:** Generation counter prevents stale hide-completion from overriding a new show animation.

### Fixed

- **Menu bar "打开排程面板" unresponsive:** `WindowGroup` → `Window(id: "main")` + `@Environment(\.openWindow)`. Closed windows can now be reopened programmatically from the menu bar.
- **Notch hover detection dead:** `ignoresMouseEvents = true` was blocking all `NSTrackingArea` callbacks. Set to `false` — tracking window is at notch position (no menu bar items underneath).

### Changed

- **Animation tuning:** Leave debounce 0.3s → 0.5s for slower, more natural dismissal. Panel fade-out 0.25s → 0.4s.

## [0.5.7] — 2026-06-04

### Added

- **ECC project-local harness:** Installed minimal Swift-focused ECC modules (swift-apple, workflow-quality, agents-core, commands-core, platform-configs). 257 files under `.claude/`. Includes swift-reviewer, swift-build-resolver agents, and swiftui-patterns/swift-concurrency-6-2 skills.
- **Quarantine removal guidance:** Added `xattr -cr` instructions for local test distribution. `build-dmg.sh` now prints a post-build hint; README replaced right-click workaround with the definitive `xattr -cr` command.

### Changed

- **CLAUDE.md:** Optimized — condensed 7-phase workflow to bullet list, added test command, ECC agent reference table, architecture table. 98 → 73 lines (-25%).

## [0.5.6] — 2026-06-04

### Changed

- **App icon:** Redesigned from placeholder white oval to custom icon with notch silhouette + blue-purple focus block + pause symbol. All sizes generated programmatically (16→1024px). Build verified.

## [0.1.1] — 2026-06-04

### Fixed

- **Code signing:** Deep ad-hoc signing with resource sealing. Info.plist now bound (25 entries), Sealed Resources v2. Fixes Gatekeeper "code has no resources but signature indicates they must be present" error.
- **First-launch experience:** LSUIElement apps show no Dock icon — users thought the app crashed. Now auto-shows main scheduler window + sends welcome notification on first launch.
- **README:** Added 5-step installation guide with Gatekeeper right-click workaround.

### Known Limitations

- Ad-hoc signed apps require right-click → Open on first launch. Full Gatekeeper pass requires Apple Developer Program ($99/year) + notarization.

## [0.1.0] — 2026-06-04

### Added

- **Menu bar app** — Lightweight macOS status bar item, no Dock icon (`LSUIElement`)
- **Time block scheduler** — Plan your day with time-blocked tasks, visual timeline list
- **Conflict detection** — Real-time overlap validation prevents double-booking (AC 1.1)
- **Local persistence** — UserDefaults JSON storage, survives restarts (AC 1.3)
- **Notch hover panel** — Hover Mac notch for 0.5s to reveal today's schedule (AC 2.1, 2.2)
- **Auto-dismiss panel** — Panel slides away 0.3s after mouse leaves (AC 2.3)
- **Fullscreen avoidance** — Notch detection pauses during fullscreen apps (AC 2.4)
- **Hard-interrupt overlay** — 70% opacity fullscreen overlay blocks all interaction at block end (AC 3.1)
- **Completion check** — "Did you finish?" dialog with [Complete] / [Adjust Schedule] buttons (AC 3.2)
- **5-minute timeout** — Unanswered overlays auto-mark tasks as missed + local notification (AC 3.3)
- **Fullscreen penetration** — `CGShieldingWindowLevel` overlay over fullscreen spaces (AC 3.4)
- **History retrofitting** — Right-click to change status, tap to edit time range (AC 4.1)
- **Launch at login** — Menu bar toggle via `SMAppService` (AC 1.2)
- **Screen change handling** — Tracking window repositions on display connect/disconnect

[0.1.0]: https://github.com/lorenzozanee/NotchBlock/releases/tag/v0.1.0
