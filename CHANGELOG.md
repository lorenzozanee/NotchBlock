# Changelog

All notable changes to NotchBlock will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
