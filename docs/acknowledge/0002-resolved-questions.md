# 0002 — 미결 질문 해소 (Resolved Open Questions)

> 연구 종합(`docs/memory/research-raw.json`)이 제기한 미결 질문을 사용자 기존 답변(0001)에 비추어 해소한다. 사용자가 이의가 없으면 이 결정대로 진행한다.

| # | 질문 | 결정 | 근거 |
|---|------|------|------|
| 1 | 배포 채널 (직배포 vs App Store) | **직배포 전용** (Developer ID/dev identity, notarization 선택) | 사용자 "어차피 나만 쓸 듯" + 사설 API 사용 결정. App Store 는 사설 프레임워크 링크로 리젝되므로 목표에서 제외. → 사설 API 자유롭게 사용 |
| 2 | 최소화/숨김 윈도우 라이브 썸네일 | **(a) 캐시 프레임 + 앱 아이콘 폴백** (공개 API). 사설 `CGSHWCaptureWindowList` 는 토글로 후순위(P2) | ScreenCaptureKit 으로 최소화 창 라이브 캡처 불가. 공개 API 우선 원칙 |
| 3 | 기본 소환 단축키 | **⌥(Option)+Tab 기본, 완전 커스터마이즈 가능.** ⌘⇥ 대체(네이티브 비활성화)는 옵션(P2) | "custom shortcut" 요구. ⌥Tab 은 충돌 없음. 시스템 ⌘⇥ 대체는 사설 API라 옵션화 |
| 4 | CI/빌드 도구 | **순수 `swift build`/`swift test` + `build-app.sh`** (tiny-razer 패턴). `.xcstrings` 심볼은 빌드 플러그인/생성으로 해결 | tiny-razer 와 일관. Bun 은 TS 전용이라 여기선 swift 툴체인 |
| 5 | 키 녹화 UI | **자체 구현 (외부 의존성 없음)** | hold-to-release(모디파이어 누른 채 Tab 순환→떼면 확정) 시맨틱을 완전 제어해야 함. 외부 라이브러리(KeyboardShortcuts)는 press 기반이라 충돌. `ShortcutModel` 과 직접 통합 |
| 6 | 초기 언어 | **ko / en / ja** (확정). defaultLocalization=en | 0001 확정 |
| 7 | 단위 테스트 범위 | **순수 로직 우선** (FuzzyMatcher·HangulMatcher·WindowFilterResolver·ShortcutMatcher·GridNavigator·SettingsSchema migration). 실기 성능 프로파일링은 수동 | 컨벤션상 검증 필수. OS 비의존 로직부터. *실 테스트 작성 전 사용자에게 범위 재확인* |
| 8 | 선택 윈도우 라이브 프리뷰 | **P1 (토글, 1~2개 한정)** | SCStream 다중은 부하 큼. 1차 출시 후 |
| 9 | Liquid Glass 적용 범위 | **배경/콜드패스(Settings·오버레이 배경) 한정 + NSVisualEffectView 폴백.** 핫패스 썸네일엔 미적용 | 신규 API 성능/외형 실기 검증 필요. 핫패스 성능 보호 |

## 단계적 구현 방침

이 프로젝트는 범위가 매우 크다(AltTab 전 기능 + 고도화). **컴파일·실행되는 코어 루프를 먼저 완성**한 뒤(메뉴바 → 핫키 → 윈도우 열거 → 오버레이 그리드 → 포커스 전환 → 기본 설정), 롱테일 기능을 우선순위(P0→P1→P2)대로 얹는다. 매 단계 `swift build` 로 검증하고 `docs/PROCESS.md` 체크리스트를 갱신한다.
