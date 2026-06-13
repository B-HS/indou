# 0001 — 윈도우 없는 백그라운드 앱이 스위처에 표시됨

2026-06-13 · 사용자 실기 테스트에서 발견

## 증상
스위처에 실제 윈도우가 없는 **백그라운드 전용 앱·시스템 표면**까지 모두 표시됨.

## 원인
`WindowEnumerator.enumerate()` 가 `SCShareableContent` 의 `windowLayer == 0` 윈도우를 **무차별 포함**했다. ScreenCaptureKit 목록에는 배경화면·시스템 UI·에이전트의 layer-0 표면이 다수 들어있어, 이들이 그대로 노출됐다. 핵심 누락: "실제 윈도우" 판정(AX 표준 윈도우 subrole / 앱 activation policy)을 적용하지 않음.

## 해결 (대상: `Sources/Indou/Windows/WindowEnumerator.swift`)
열거를 **AX 표준 윈도우 우선**으로 재설계했다.
1. **권위 소스**: `.regular` 앱의 AX 윈도우 중 `subrole ∈ {AXStandardWindow, AXDialog}` 인 것만 포함(최소화/풀스크린/오프스크린 포함). SC 는 frame/onScreen/썸네일 보강에만 사용.
2. **폴백**: AX 가 표준 윈도우를 하나도 못 준 `.regular` 앱에 한해, SC 윈도우 중 `layer==0 && isOnScreen && 타이틀 있음 && 80×80 이상` 만 포함.

→ activation policy 가 `.regular` 가 아닌 백그라운드 에이전트/메뉴바 전용 유틸리티/시스템 표면은 전부 제외된다.

## 비고
- `.accessory`(LSUIElement) 앱이 실제 창을 띄운 경우는 현재 제외된다(드문 케이스). 필요 시 옵션으로 추가 검토 — `docs/PROCESS.md` M5.
- per-window `displayID`/`spaceIDs` 채우기(screens/spaces 필터 정밀화)는 여전히 M5 과제.
