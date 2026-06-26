# 0004 — 전체 코드 감사 + 코어 루프 버그 5건 수정 (2026-06-26)

## 개요
전체 코드베이스(3 타겟 ~4,400 LOC)를 멀티에이전트 워크플로우(서브시스템 8 매핑 → 6 렌즈 헌팅 →
적대적 검증)와 독립 코드 리뷰로 감사. **확정 12건 / 런타임검증 1건 / 오탐 1건**. 감사 전문은
[`docs/bug/0004-audit-2026-06-26.md`](../bug/0004-audit-2026-06-26.md).

이 중 코어 루프에 영향이 큰 **5건(A~D, 사용자 지시 1~5)** 을 수정. 나머지 6건(E~J)은 감사 문서에
미수정 확정 버그로 기록(특히 H=High 후속 권장).

## 수정 내용

### 1·2 — 단일 ⌥Tab 미전환 + reverse 미사용 (`SwitcherController.openSession`)
- `pendingSteps = reverse ? -1 : 1` 로 변경(기존 하드코딩 `0`).
- 여는 입력이 1칸 advance → forward 단일 탭은 직전 창(index 1), reverse 단일 탭은 마지막 창(index count-1).
- 클래식 alt-tab 빠른 전환 복구, ⌥⇧Tab 역방향 소환 동작.

### 3 — 열거 전 릴리즈 시 전환 유실 (`SwitcherController`)
- `pendingCommit` 플래그 추가.
- `commit()` 에 `guard windowsLoaded else { pendingCommit = true; return }` — 로드 전 릴리즈면 세션을 닫지 않고 보류.
- `loadWindows` 가 selectedIndex 확정 후 `pendingCommit` 이면 즉시 `commit()`(패널 표시 생략).
- `openSession` 에서 직전 세션 스냅샷 초기화(`model.windows=[]`, `selectedIndex=0`, `liveByID=[:]`) → pre-load commit 이 stale 창/죽은 AX 요소를 건드리지 않음.
- `closeSession` 에서 `pendingCommit=false` 리셋.

### 4 — ThumbnailStore 캐시 미정리 (`SwitcherController.openSession`)
- `thumbnails.clear()` 를 세션 시작에 연결(dead code 였던 `clear()` 활성화).
- 세션 단위 캐시 경계 → 무한 증가 차단 + CGWindowID 재활용 시 stale 썸네일 방지(세션마다 신선 캡처).

### 5 — AX 열거 메인 스레드 동기 블로킹 (`WindowEnumerator`)
- `collectAccessibilityWindows` 를 `nonisolated static async` 로 전환 → 글로벌 실행기에서 off-main 실행.
- `enumerate()`(MainActor)는 `runningRegularApps()` 로 앱 목록만 스냅샷(`AppSnapshot: Sendable`) 후 await.
- `AXWindowInfo: Sendable`(이미 `nonisolated(unsafe) let element` 보유) → 경계 통과.
- 메인 런루프가 열거 중에도 응답 유지 → 이벤트 탭 `tapDisabledByTimeout` 위험 제거. (이벤트 탭은 동기
  swallow 요건상 메인 런루프 유지 — 블로킹 원인 제거가 근본 해결.)

## 검증
- `swift build` 성공(Swift 6 strict concurrency 통과 — off-main AX 의 Sendable 경계 포함).
- `swift test` — 전부 통과(IndouKit 회귀 없음).

## 추가 수정 (E~J, 사용자 승인 후)
- **E** 세션 클로버링: `sessionGeneration` 토큰으로 stale reload Task 폐기(`loadWindows` await 후 generation 재확인).
- **F** `whenNoOpenWindow` 도달불가: 리졸버가 열린(비최소화·비숨김) 창만 카운트해 전달. 회귀 테스트 2건.
- **G** `wordStarts` 대문자 연속 경계: "HTTPServer"의 S 같은 경계 분기 추가. 회귀 테스트 1건.
- **H** 레코더 고착(High): `ShortcutRecorder.onDisappear` 리셋 + `SettingsWindowController` 가 진입/창닫힘 시 `isRecordingShortcut` 클리어.
- **I** 메뉴바 토글 no-op: `withObservationTracking` 으로 설정 반응 설치/제거 + `applicationShouldHandleReopen` 으로 아이콘 숨김 시 Settings 진입 경로.
- **J** MRU 형제 역전: `lastFocusedWindow` 추적 후 앱 활성화 알림에서 포커스 창 order 재스탬프.

→ 확정 12건 전부 수정. `swift build` + `swift test`(49, 회귀 3건 추가) 통과.
