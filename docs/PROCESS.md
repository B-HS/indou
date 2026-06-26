# PROCESS — Indou 작업 체크리스트

> AI 작업의 단일 상태 출처(ai-process 원칙 1·14). 매 스텝 상태를 갱신하며 진행한다.
> 기준 문서: 글로벌 `~/.claude/CLAUDE.md` 컨벤션 + `docs/acknowledge/*` + `docs/memory/architecture.md`.
> 범위가 크므로 **컴파일·실행되는 코어 루프 먼저(M1) → 기능 확장(M2~)** 의 마일스톤으로 쌓는다. 우선순위 P0(필수)/P1/P2.

## 진행 원칙
- 매 스텝 `swift build` 로 검증하고 통과 후 다음으로.
- 코드 주석 금지(`///` 영문 doc 만 예외). 설명은 이 `docs/`.
- 사설 API 는 `PrivateWindowServer` 에만. graceful degradation 필수.

---

## M0 — 기획·조사 ✅
- [x] AltTab 전 기능 인벤토리 + macOS API 9개 차원 조사 (워크플로우 `whutv50av`)
- [x] 아키텍처/체크리스트 종합 → `docs/memory/architecture.md`, `research-raw.json`
- [x] 초기 결정(`acknowledge/0001`)·미결 해소(`0002`)·사설 API 리스크(`private-api.md`)
- [x] PROCESS.md 작성

## M1 — 컴파일/실행되는 코어 루프 (P0)
부트스트랩 → 핫키 → 윈도우 열거 → 오버레이 그리드 → 포커스 전환 → 메뉴바/Quit. "최소 동작 제품".

### M1.1 프로젝트 스캐폴딩 ✅
- [x] `Package.swift` (swift-tools **6.2**, `platforms:[.macOS(.v26)]`, `defaultLocalization:"en"`, 타겟 `IndouKit`+`PrivateWindowServer`+`Indou`). SkyLight 는 `dlopen`/`dlsym` 으로 런타임 로드(링크 취약성 회피)라 `.linkedFramework` 불필요
- [x] `Resources/Info.plist` (LSUIElement, LSMinimumSystemVersion=26.0, NSApplicationSupportsSecureRestorableState, 고정 CFBundleIdentifier)
- [x] `Resources/Indou.entitlements` (App Sandbox 비활성 — 빈 dict)
- [x] `scripts/build-app.sh`·`setup-dev-identity.sh`·`reset-permissions.sh` (tiny-razer 패턴)
- [x] `.gitignore`, `main.swift`+`AppDelegate`(메뉴바 StatusItem+Quit). `swift build`/`swift test` 통과, `build-app.sh release` 로 .app 번들·**Developer ID 서명**·실행 검증 완료

### M1.2 IndouKit 코어 모델 + 순수 로직 (테스트 우선) ✅
- [x] `Model/`: `WindowState`/`AppInfo`/`ScreenInfo`/`SpaceInfo`
- [x] `Search/FuzzyMatcher`(6-tier) + `HangulMatcher`(초성) + `WindowSearch` + `MatchResult`
- [x] `Filter/WindowFilter`(`WindowFilterResolver`+discriminator+context) + `ExceptionMatcher`(blacklist)
- [x] `Navigation/GridNavigator`(2D 이동) + `SelectionState`(단수+`Set` 다중)
- [x] `Settings/SettingsSchema`(마이그레이션 내성 Codable) + `SettingsCodec` + `PreferenceStore`(load/save/import/export/reset)
- [x] `Hotkey/`: `ModifierFlags`·`KeyCode`·`ShortcutProfile`·`ShortcutMatcher`
- [x] `Tests/IndouKitTests`: **44개 통과** (Fuzzy·Hangul·WindowSearch·Filter·Exception·Grid·Selection·SettingsMigration·ShortcutMatcher)

### M1.3 PrivateWindowServer (격리·graceful degradation)
- [x] `SkyLightSymbols.swift` (`dlopen`/`dlsym` 방어적 로드 — connection/spaces/windowLevel/AX windowID)
- [ ] `PreciseFocus.swift` (SLPS 4단계 + 공개 폴백)
- [ ] `SpaceQuery.swift` (Space 열거/멤버십/z-order + 현재 Space 폴백)
- [ ] `NativeHotkeyResolver.swift` (⌘⇥ disable/restore, 옵션)

### M1.4 윈도우 열거 (요구 2) ✅
- [x] `Windows/WindowEnumerator`: `SCShareableContent`(SCWindow) + per-app AX 합집합(`AXUIElement+Helpers`), CGWindowID dedupe, AX 메시징 타임아웃 0.5s, 최소화 창 AX-only 포함, 자기앱/layer≠0 제외
- [x] 앱 활성화 추적: `SwitcherController` 가 `NSWorkspace.didActivateApplicationNotification` 관찰 → MRU 순서

### M1.5 핫키/이벤트 (요구 1·4 일부) ✅
- [x] `Hotkey/EventTapController` (전역 `CGEventTap` .cghidEventTap: 트리거 감지 + 활성 중 키 흡수 + .flagsChanged 떼기 확정 + 자가복구). `ModifierFlags`↔`CGEventFlags` 비트 동일 활용
- [x] 비활성 패널 + 전역 탭 조합으로 포커스 비탈취 (LocalKeyMonitor 불필요해짐)

### M1.6 오버레이 + 그리드 렌더 (요구 13) ✅(SwiftUI M1, CALayer 핫패스는 M3/M5)
- [x] `Overlay/SwitcherPanel` (.nonactivatingPanel, canBecomeKey=false, level=.popUpMenu, collectionBehavior, alpha 프리스테이징)
- [x] `Overlay/SwitcherView`(SwiftUI LazyVGrid) + `SwitcherCell`(썸네일/아이콘/타이틀/상태아이콘/선택링)
- [x] `Capture/ThumbnailStore` (SCScreenshotManager 비동기 캡처, @Observable 점진 갱신, 표시 픽셀 다운샘플)
- [x] `Overlay/Layout`(셀 크기/열/패널 크기), `SwitcherController.resolveScreen`(커서/활성/메뉴바 화면)
- [x] 셀: 앱 아이콘 + 타이틀 + 썸네일 (요구 7 기본)

### M1.7 네비게이션 + 포커스 전환 (요구 4·8 일부) ✅
- [x] hold 중 Tab/Shift+Tab cycle + 화살표/vim 2D 이동 → `GridNavigator` 연결, pendingSteps 로딩 중 큐잉
- [x] 모디파이어 떼면 선택 윈도우 정밀 포커스(`PreciseFocus`) → **코어 루프 완성**

### M1.8 메뉴바 + 권한 + 빌드 (요구 11) ✅
- [x] 메뉴바 `NSStatusItem` (상단, 클릭 메뉴 → Settings/Quit)
- [x] `Permissions`(AX·Screen Recording 체크/프롬프트/딥링크) + AppDelegate MainActor Task 폴링 → 부여 시 탭 시작
- [x] `Core/LaunchAtLogin`(SMAppService)
- [x] `build-app.sh release` → .app 번들·**Developer ID 서명**·실행(크래시 없음) 검증. ⚠ 실제 윈도우 전환은 Accessibility 권한 부여 후 실기 확인 필요

## M2 — 표시 커스터마이징 · 윈도우 액션 · 다중선택 (P0) — 대부분 완료
- [x] 필터 로직(요구 3): `WindowFilterResolver` + 프로필 filter + `ExceptionMatcher` 연동(controller). UI: FiltersPane(blacklist 추가/삭제). ⚠ spaces/screens 필터의 per-window 메타(displayID/spaceIDs) 채우기는 M5
- [x] '실행 중인 것 표시/숨김'(요구 7): showTitles/truncation/상태아이콘/마스킹 셀 반영 + AppearancePane 토글
- [x] 인-스위처 액션(요구 8): focus(Return)/close(W)/minDemin(M)/fullscreen(F)/quit(Q)/cancel(Esc) — `WindowActions`+controller. ⚠ 재바인딩 UI 는 M5
- [x] 드래그 다중선택 + 우클릭 일괄 종료(요구 9): 마퀴(`SwitcherView`)+Cmd/Shift 클릭, contextMenu, 앱당 quit 1회 직렬 큐. ⚠ 확인/undo 토스트는 M5

## M3 — 전환 애니메이션 (완벽·토글, 요구 5) (P0) — 부분
- [x] 단일 토글 `animation.enabled`(셀 spring/scale on/off) + Reduce Motion 연동(`reduceMotionActive`)
- [ ] `DisplayLink` 120Hz 구동 + 그리드 등장/리플로우 트랜지션, fade in/out, 등장지연(summonDelay) 실제 적용

## M4 — Settings 창 (tiny-razer 스타일, 요구 12) + 다국어 (요구 6) (P0) — 대부분 완료
- [x] `SettingsWindowController`+`SettingsRootView`(사이드바 + Card 디테일, `DS` 토큰)
- [x] Panes: General/Shortcuts(표시+enable)/Appearance/Animations/Input/Filters/Advanced(권한·사설API·성능·import/export/reset)/About
- [x] import/export/reset(`PreferenceStore`+NSSave/OpenPanel)
- [x] 다국어 인프라: `Resources/Localizable.xcstrings`(ko/en/ja) + `build-app.sh` 가 `xcstringstool compile` → `Contents/Resources/<lang>.lproj` 로 컴파일(Bundle.main 해석). ⚠ 번역 커버리지는 핵심 ~22개만 — 나머지 문자열 번역 채우기 + 런타임 언어 전환(.environment(\.locale)/AppKit 재구축)은 M5
- [ ] Liquid Glass(`.glassEffect`) 콜드패스 적용 (현재 `.ultraThinMaterial`)

## M5 — 고도화·기타 (P1/P2, 요구 10)
- [ ] 검색 무료 제공 + 한글 초성/로마자 (IndouKit 완성분 UI 연결)
- [ ] 멀티 단축키 프로필(이름·필터·외형 묶음), 제스처 트리거, 트랙패드 햅틱
- [ ] 선택 윈도우 라이브 프리뷰(P1, 토글)
- [ ] 외형 스타일 thumbnails/appIcons/titles + size auto/small/med/large + theme
- [ ] 업데이트 정책(Sparkle 검토)·크래시 정책, 앱 아이콘/리소스
- [ ] 실기 성능 프로파일링(ProMotion, 50/100/300창, 첫 표시<50ms·전환 120Hz)

## M6 — 전체 코드 감사 + 코어 루프 버그 수정 (2026-06-26)
멀티에이전트 워크플로우 + 독립 리뷰. 확정 12 / 런타임검증 1 / 오탐 1. 전문 `docs/bug/0004-audit-2026-06-26.md`.
- [x] 코어 루프 5건 수정(A~D): 단일 ⌥Tab 미전환·reverse 미사용(`openSession`), 릴리즈 경쟁(`pendingCommit`), 썸네일 캐시 미정리(`clear()` 연결), AX off-main(`WindowEnumerator`)
- [x] 추가 6건 수정(E~J): 세션 generation, `whenNoOpenWindow` 의미부여, `wordStarts` 대문자경계, ShortcutRecorder 고착, 메뉴바 토글 반영, MRU 형제 역전. 회귀 테스트 3건 추가
- [x] `swift build`(Swift 6 strict) + `swift test`(49) 통과 → **확정 12건 전부 수정**

## M7 — 기능: Show background apps 토글 (2026-06-26)
Force Quit 처럼 창 없는 regular 앱도 표시하는 토글. 상세 `docs/history/0005-background-apps-toggle.md`.
- [x] `WindowState.isAppEntry` + `WindowEnumerator.enumerate(includeBackgroundApps:)` 앱 엔트리 생성
- [x] `WindowActions.focus` 앱 활성화, `GeneralSettings.showBackgroundApps`(기본 OFF) + General 페인 토글, 앱 엔트리 창 컨트롤 숨김, 앱 엔트리는 앱 아이콘 표시
- [x] `swift build` + `swift test`(49) 통과

## 검증 메모
- 매 마일스톤 `swift build`(+해당 시 `swift test`).
- 단위 테스트 실 작성 전 사용자에게 범위 재확인(컨벤션).
- 권한·사설 API 동작은 실기에서 수동 확인(체크리스트는 추후 `docs/history`).
