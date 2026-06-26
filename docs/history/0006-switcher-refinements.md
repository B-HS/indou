# 0006 — 스위처 다듬기 4건 (2026-06-27)

## 1. 백그라운드 앱 항상 맨 뒤
`WindowFilterResolver.resolve` 가 `isAppEntry` 창을 별도 버킷으로 분리해 실제 창(head+tail) **뒤에** 항상
붙인다. 앱 엔트리끼리는 알파벳 정렬(Force Quit 과 동일). `lastFocusOrder` 가 높아도 앞으로 오지 않음.
회귀 테스트 추가(FilterTests `appEntriesAlwaysLast`).

## 2. 백그라운드 앱 닫기(앱 종료) 버튼
`SwitcherCell` 이 앱 엔트리에도 빨간 × 를 표시(툴팁 "Quit app"), 최소화/풀스크린 버튼만 숨김.
`SwitcherController.closeWindow` 가 앱 엔트리면 `WindowActions.close`(창 없음) 대신
`WindowActions.quitApp(pid:)` 로 앱을 종료한다.

## 3. 선택창 밖 클릭 / Esc 로 그냥 닫힘 (선택 무시)
- Esc·밖 클릭은 이미 `closeSession(commit: false)` 로 커밋 없이 닫혔다(선택 변경 무시).
- 다만 Indou 는 accessory 앱이라 비활성 윈도우의 **첫 클릭**이 backdrop 에 전달되지 않을 수 있었다 →
  `BackdropView.acceptsFirstMouse` 를 `true` 로 오버라이드해 밖 클릭이 항상 즉시 닫히도록 보강.

## 4. 단일/다중 선택 모드 토글
`InputSettings.multiSelectEnabled`(기본 **false = 단일**) 추가. Input 페인에 "Multi-select mode" 토글.
- **단일(기본)**: 셀 클릭 즉시 포커스 + 닫힘. ⌘/⇧-클릭도 즉시 동작, 마퀴 드래그 비활성.
- **다중**: 기존대로 마퀴 + ⌘/⇧-클릭으로 선택 집합 구성 후 우클릭 메뉴 일괄 동작.
- 구현: `SwitcherViewModel.multiSelectEnabled`(컨트롤러가 `loadWindows` 에서 설정값 주입),
  `onClick` 이 `additive && multiSelectEnabled` 일 때만 다중선택, 그 외 commit. 마퀴 제스처는
  `multiSelectEnabled` 가드.

> 기본값을 단일로 둔 이유: 스위처의 표준 동작(클릭=즉시 전환). 다중은 토글로 옵트인.

## 검증
- `swift build`(Swift 6 strict) + `swift test`(50, 회귀 1건 추가) 통과.
