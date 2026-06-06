# NotchBlock

<p align="center">
  <img src="icon.png" alt="NotchBlock 아이콘" width="128" height="128">
</p>

<p align="center">
  <strong>Mac 하드웨어 노치를 타임블로킹 게이트웨이로 전환하세요.</strong>
</p>

<p align="center">
  <a href="https://github.com/lorenzozanee/NotchBlock/releases"><img src="https://img.shields.io/github/v/release/lorenzozanee/NotchBlock?color=blue" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="License: MIT"></a>
  <a href="#"><img src="https://img.shields.io/badge/platform-macOS%2014.0%2B-orange" alt="macOS 14.0+"></a>
  <a href="#"><img src="https://img.shields.io/badge/swift-6.1-FA7343?logo=swift" alt="Swift 6.1"></a>
</p>

<p align="center">
  <sub><a href="README.md">English</a> | <a href="README_ZH.md">中文</a> | <a href="README_FR.md">Français</a> | <a href="README_ES.md">Español</a> | <a href="README_JA.md">日本語</a> | 한국어</sub>
</p>

---

NotchBlock은 macOS를 위한 미니멀하고 **강제적인** 타임블로킹 스케줄러입니다. 하드웨어 노치를 보이지 않는 상호작용 지점으로 변환하고, 작업이 끝나면 무시할 수 없는 전체 화면 오버레이로 방해하여 강제로 집중력을 유지합니다.

> 🎯 노치에 마우스를 올리면 → 오늘의 일정 확인 → 작업 종료 시 전체 화면 알림 → 완료 확인 필수

## ✨ 기능

| 기능 | 설명 |
|---|---|
| 🔲 **노치 호버 패널** | 노치에 0.5초간 마우스를 올리면 일정이 우아하게 슬라이드 표시 |
| 🛡️ **전체 화면 감지** | 동영상, 게임, 프레젠테이션 중에는 노치 감지를 자동 일시 중지 |
| ⚡ **강제 인터럽트 오버레이** | 작업 종료 시 전체 화면이 어두워지며 다른 모든 상호작용 차단 |
| ⏱️ **5분 타임아웃** | 확인되지 않은 블록은 시스템 알림과 함께 자동으로 '놓침'으로 표시 |
| 📋 **일일 스케줄러** | 시간 충돌을 자동 감지하는 미니멀한 타임라인 목록 |
| 🔄 **기록 수정** | 작업 상태를 수동으로 조정하여 정확한 시간 추적 검토 가능 |
| 🚀 **로그인 시 실행** | 메뉴 바에서 원클릭 토글, 백그라운드에서 조용히 실행 |
| 💾 **로컬 저장소** | 모든 데이터를 로컬에 저장 — 네트워크 불필요, 완전한 프라이버시 |

## 📥 설치

[Releases](https://github.com/lorenzozanee/NotchBlock/releases) 페이지에서 최신 `NotchBlock-*.dmg`를 다운로드하세요.

### 3단계 설정

DMG를 연 후, 창의 안내에 따라 진행하세요:

1. **응용 프로그램으로 드래그** — `NotchBlock.app`를 `응용 프로그램` 폴더에 드롭
2. **`FixQuarantine.command` 더블 클릭** — 격리 속성을 제거하고 앱을 실행 (최초 실행 시 우클릭 → 열기 필요)
3. **완료** — 메뉴 바 아이콘이 나타나면 사용 준비 완료

> 💡 왜 2단계가 필요한가요? NotchBlock은 Apple 공증을 받지 않았습니다 (연 $99 개발자 계정 필요). macOS는 다운로드한 앱에 격리 속성을 부여합니다. `FixQuarantine.command`가 `xattr -cr /Applications/NotchBlock.app`를 실행하여 이 플래그를 제거합니다.

최초 실행 후 다음 권한을 허용하세요:

| 권한 | 용도 | 설정 경로 |
|---|---|---|
| **손쉬운 사용** | 전체 화면 앱 감지 | 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용 |
| **알림** | 작업 타임아웃 알림 | 시스템 설정 → 알림 → NotchBlock |

### 수동 설치

```bash
# DMG 스크립트가 실행되지 않는 경우 수동으로:
xattr -cr /Applications/NotchBlock.app
open /Applications/NotchBlock.app
```

## 🏗️ 아키텍처

```
macOS 14.0+ · Swift 6.1 · SwiftUI + AppKit
```

**주요 API:**

- `NSTrackingArea` — 노치 영역 마우스 추적
- `NSPanel` + `.nonactivatingPanel` — 드롭다운 패널 (포커스를 빼앗지 않음)
- `CGShieldingWindowLevel()` + `.fullScreenAuxiliary` — 모든 것을 관통하는 오버레이
- `CGWindowList` — 전체 화면 상태 감지
- `SMAppService` — 로그인 항목 등록
- `UserNotifications` — 타임아웃 배너 알림
- `UserDefaults` / ISO 8601 JSON — 로컬 지속성

**프로젝트 구조:**

```
NotchBlock/
├── Models/           TimeBlock · BlockStatus
├── Managers/         TimeBlockStore · NotchTracker · NotchPanelController
│                     OverlayWindowController · BlockScheduler
├── Views/            MainSchedulerView · TimeBlockRowView · AddEditBlockView
│                     NotchPanelView · OverlayView
└── Utilities/        DateExtensions · LaunchManager
```

## ⌨️ 단축키

| 단축키 | 동작 |
|---|---|
| `⌘O` | 스케줄러 패널 열기 |
| `⌘Q` | NotchBlock 종료 |

## 📝 개발

```bash
# .swift 파일 추가/제거 후 Xcode 프로젝트 재생성
python3 generate_xcode_project.py

# CLI 빌드
xcodebuild -project NotchBlock.xcodeproj -scheme NotchBlock -configuration Release build

# DMG 생성
./scripts/build-dmg.sh
```

## 📄 라이선스

[MIT License](LICENSE)

---

<p align="center">
  <sub>집중 작업을 위한 ❤️로 제작 · macOS Apple Silicon</sub>
</p>
