# 0001 — 기반 구축 (Foundation)

2026-06-13

## 한 일
- 기획·조사(M0): AltTab 전 기능 + macOS API 9개 차원 워크플로우 조사 → `docs/memory/architecture.md`, `research-raw.json`, `acknowledge/*`.
- M1.1 스캐폴딩: SwiftPM 3-타겟(`IndouKit`/`PrivateWindowServer`/`Indou`), `Package.swift`(tools 6.2, macOS .v26), Info.plist/entitlements, 빌드 스크립트 3종. `build-app.sh release` → `.build/Indou.app` Developer ID 서명·실행 검증.
- M1.2 IndouKit 코어: 모델(WindowState 등), 검색(6-tier Fuzzy + 한글 초성 + WindowSearch), 필터(WindowFilterResolver + ExceptionMatcher), 네비게이션(GridNavigator + SelectionState), 설정(마이그레이션 내성 SettingsSchema + PreferenceStore), 핫키 모델(ModifierFlags/ShortcutProfile/ShortcutMatcher). **단위 테스트 44개 통과**.
- M1.3 일부: `SkyLightSymbols`(dlsym 방어적 로더).

## 검증
- `swift build` OK, `swift test` 44/44 통과, `.app` 서명/실행 OK.

## 다음
- M1.3 마무리(PreciseFocus/SpaceQuery), M1.4 윈도우 열거(SCShareableContent+AX), M1.5 핫키(Carbon+CGEventTap+local monitor), M1.6 오버레이+캡처, M1.7 포커스 전환, M1.8 메뉴바+권한 → M1 코어 루프 데모.
