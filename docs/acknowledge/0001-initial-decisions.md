# 0001 — 초기 확정 사항 (Initial Decisions)

> 사용자와 합의한 프로젝트 전제. 이후 모든 작업의 기준이 된다.

## 프로젝트

- **이름**: Indou (윈도우 → "인도우"의 음차)
- **목표**: AltTab(유료화됨)을 대체하고 더 고도화한 macOS 윈도우 스위처
- **형태**: 메뉴바 전용 앱 (`LSUIElement`, `NSApplication.setActivationPolicy(.accessory)`)
- **언어/런타임**: Swift 6, SwiftPM, SwiftUI + AppKit 혼용
- **참고 UI**: `/Users/hyunseokbyun/tiny-razer` 의 Settings 디자인 언어(사이드바 + Card 디테일 + 디자인 토큰)를 따른다.

## 확정 결정

| 항목 | 결정 | 비고 |
|------|------|------|
| 번들 ID | `com.hyunseokbyun.indou` | tiny-razer 와 동일 네임스페이스 |
| 윈도우 열거 | **사설(private) CGS/Spaces API 사용** | 다른 Space·풀스크린 앱 윈도우까지 정확히 수집. AltTab 방식. 사설 API 는 추상화 계층(`WindowSource`)으로 격리해 리스크 최소화 |
| 최소 macOS | **macOS 26 (Tahoe) 전용** | 사용자 본인 사용이 주목적. 최신 API(ScreenCaptureKit, SCScreenshotManager 등) 제약 없이 사용 |
| 썸네일 캡처 | ScreenCaptureKit | `CGWindowListCreateImage` 는 deprecated |
| 탑재 언어 | **한국어 / English / 日本語** | String Catalog(`.xcstrings`). 런타임 언어 선택 UI 제공. 나중에 언어 추가 가능 |
| 코드사인 | 개발용 안정 identity (tiny-razer `setup-dev-identity` 패턴) | 재빌드 시 TCC 권한 유지 |

## 사용자 핵심 요구 (원문 갈무리)

1. 커스텀 단축키
2. 표시 가능한 모든 윈도우를 정확히 표시
3. 표시할 윈도우 커스터마이징(필터/blacklist)
4. Alt+Tab 후 Tab 반복 또는 방향키로 그리드 자유 이동
5. 완벽히 부드러운 전환 애니메이션 (on/off 토글)
6. 완벽한 다국어
7. 각 윈도우가 무엇을 실행 중인지 정확히 표시하거나 숨김
8. 스위처에서 바로 윈도우 종료
9. 드래그로 다중 선택 후 우클릭 → 종료
10. 그 외 필요한 모든 기능 (AltTab 전 기능 + 고도화)
11. 메뉴바(상단 시계 옆) 우클릭 → settings / quit
12. Settings 창은 tiny-razer 스타일
13. 스위처 창은 모던·심플·고성능 (하이퍼포먼스)
