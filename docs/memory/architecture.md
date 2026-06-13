# Indou 아키텍처

> 연구 종합 결과의 핵심. 전체 원본은 `research-raw.json`.

## 3축 설계

1. **셸/로직 분리** — 순수 로직은 `IndouKit` 라이브러리(OS 의존 최소·테스트 가능), 셸은 `Indou` 실행 타겟(AppKit·NSPanel·Settings·메뉴바). tiny-razer 의 `RazerKit`+`TinyRazer` 2-타겟 패턴 계승.
2. **핫패스/콜드패스 렌더링 분리** — 핫패스(썸네일 그리드·전환)는 **AppKit + CoreAnimation**(CALayer 직접, `NSView.displayLink` 페이싱, ProMotion 120Hz). 콜드패스(Settings·온보딩)는 **SwiftUI**(+ macOS 26 Liquid Glass).
3. **사설 API 격리** — CGS/SkyLight/SLPS 는 `PrivateWindowServer` 단일 모듈에 가두고 `@_silgen_name`/`dlsym` + graceful degradation.

## 핵심 기술 결정

| 항목 | 결정 |
|------|------|
| 윈도우 메타데이터 | ScreenCaptureKit `SCShareableContent`(`SCWindow`) + per-app Accessibility(`AXUIElement`) **합집합** + CGS per-space (사설) 보강, `CGWindowID` dedupe |
| 썸네일 | `SCScreenshotManager.captureSampleBuffer` → `CVPixelBuffer`→`IOSurface`→`CALayer.contents` 무복사. off-main `OperationQueue`(maxConcurrent≈8) + throttle. 셀 표시 픽셀 크기로 다운샘플 |
| 소환 핫키 | Carbon `RegisterEventHotKey`(권한 불요, ⌥Tab 기본) |
| 확정(모디파이어 떼기) | `CGEventTap(.cghidEventTap)` 의 `.flagsChanged`, 전용 백그라운드 runLoop 스레드, `tapDisabled*` 자가복구 |
| 스위처 활성 중 키 | `NSEvent.addLocalMonitorForEvents`([.keyDown,.keyUp,.flagsChanged]) 흡수(nil 반환) |
| 정밀 포커스 | 사설 SLPS 4단계(`GetProcessForPID`→`_SLPSSetFrontProcessWithOptions(.userGenerated)`→`SLPSPostEventRecordTo` 0xf8×2→`AXRaise`), 실패 시 공개 `activate` 폴백 |
| 윈도우 닫기/최소화/풀스크린 | AX (`kAXCloseButtonAttribute`+`kAXPressAction`, `kAXMinimizedAttribute`, `kAXFullscreenAttribute`) |
| 앱 종료 | `NSRunningApplication.terminate()`→재요청 시 `forceTerminate()`, 앱당 1회 |
| 오버레이 | `NSPanel`(.nonactivatingPanel, `canBecomeKey` override), `level=.popUpMenu`(.screenSaver 금지), `collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.ignoresCycle]`, alpha 프리스테이징 무깜빡임 |
| 애니메이션 | `NSView.displayLink`(CVDisplayLink deprecated), `CAFrameRateRange(30,120,preferred:120)`, 단일 토글 `transitionsEnabled`(OFF→`CATransaction.setDisableActions(true)`), Reduce Motion 연동 |
| 다국어 | String Catalog(`.xcstrings`) + `defaultLocalization:"en"` + `bundle:.module`. 런타임 전환: SwiftUI `.environment(\.locale)` + AppKit 메뉴 재구축 하이브리드 + 'System' 옵션 |
| 검색 | 6-tier fuzzy(Exact/prefix/word-prefix/substring/acronym/Damerau-Levenshtein) + **한글 초성/로마자** 고도화. 순수 Swift, 무료 |
| 다중선택 일괄종료 | 마퀴 드래그 + Cmd/Shift 클릭 → `Set<WindowID>`, 우클릭 컨텍스트 메뉴, 앱당 quit 1회 직렬 AX 큐 (AltTab 엔 없는 차별 기능) |

## 모듈 구조 (확정 — `IndouKit`/`Indou` 네이밍 채택)

```
Sources/
  IndouKit/            순수 로직 (테스트 가능)
    Model/ Enumeration/ Filter/ Search/ Capture/ Actions/ Hotkey/ Navigation/ Settings/
  PrivateWindowServer/ 사설 API 격리 (SkyLight 링크)
    SkyLightSymbols / SpaceQuery / PreciseFocus / NativeHotkeyResolver / MinimizedCapture
  Indou/               실행 타겟 (AppKit 셸)
    App/ Permissions/ Hotkey/ Overlay/ Overlay/Glass/ Screens/ Menubar/ Settings/Panes/ Resources/
Tests/ IndouKitTests/  (swift Testing)
scripts/ setup-dev-identity.sh / build-app.sh / reset-permissions.sh
```

(연구 종합의 `WindowSwitcherKit`/`WindowSwitcherApp` 을 프로젝트명에 맞춰 `IndouKit`/`Indou` 로 명명.)
