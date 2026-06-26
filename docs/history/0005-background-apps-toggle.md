# 0005 — "Show background apps" 토글 (2026-06-26)

## 배경
Indou 는 **창**을 열거(AX 표준 창 + SC 폴백)하므로 창이 하나도 없는 실행 중 앱(백그라운드/창 닫힘)은
표시되지 않는다. macOS Force Quit Applications 는 실행 중 **regular 앱 전체**를 보여준다(예: 스크린샷에서
Indou 4개 vs Force Quit 9개). 사용자가 둘을 선택할 수 있도록 토글을 추가한다.

- **OFF(기본)**: 현재 그대로(창 있는 앱만).
- **ON**: 창 목록 + **창이 없는 regular 앱**을 "앱 엔트리"로 추가 → 합집합이 Force Quit 목록과 일치.

## 구현
- **`WindowState.isAppEntry: Bool`**(IndouKit): 창 없는 앱 스탠드인 표식. 기본 false.
- **`WindowEnumerator.enumerate(includeBackgroundApps:)`**: 창 병합 후, ON 이면 `runningRegularApps()` 중
  병합에 포함된 pid 가 없는 앱마다 합성 `WindowState(isAppEntry: true, axElement nil)` 추가.
  - 합성 CGWindowID = `0x8000_0000 | pid`(고비트 → 실제 윈도우 id 와 충돌 불가).
  - 같은 `apps` 스냅샷을 AX 패스와 공유(불필요한 재조회 없음).
- **`WindowActions.focus`**: `isAppEntry` 면 `NSRunningApplication(pid).activate()` 로 앱만 전면화(창 raise 없음).
- **`SwitcherController.loadWindows`**: `enumerate(includeBackgroundApps: store.settings.general.showBackgroundApps)`.
- **설정**: `GeneralSettings.showBackgroundApps: Bool = false`(+ `decodeIfPresent` 마이그레이션). General 페인에
  "Window list" 카드 + "Show background apps" 토글(Force Quit 비유 설명).
- **UI**: `SwitcherCell` 은 앱 엔트리에 창 컨트롤(닫기/최소화/풀스크린) 숨김. 썸네일 없음 → 앱 아이콘 표시.

## 동작 세부
- 앱 엔트리는 기존 필터를 그대로 통과: `appsToShow=.active` 면 활성 앱 외 앱 엔트리 자동 제외(현재 앱
  프로필 ⌥` 은 영향 없음), blacklist(exceptions)는 bundleID 로 적용, size/space/screen 필터 무해 통과.
- 정렬은 MRU(`appActivationOrder[pid]`): 최근 쓴 앱은 위, 오래된 백그라운드 앱은 뒤.
- 액션: 컨텍스트 메뉴 Quit/Focus 는 pid 기반으로 동작, 닫기/최소화는 창이 없어 no-op.

## 검증
- `swift build`(Swift 6 strict) + `swift test`(49) 통과.
- 앱 엔트리는 썸네일이 없으므로 셀에서 앱 아이콘(`IconProvider.icon(for: pid)`)을 표시(56×56 + 타이틀행 16×16).
