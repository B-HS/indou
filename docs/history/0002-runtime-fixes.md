# 0002 — 실기 테스트 기반 수정 (Runtime Fixes)

2026-06-13 · 사용자 실기 테스트 라운드

## 고친/추가한 것
1. **윈도우 없는 백그라운드 앱 노출** → AX 표준 윈도우 우선 열거로 수정 (`docs/bug/0001`).
2. **포커스(맨 앞으로 안 옴)** — 근본 원인 2개를 헤드리스로 특정해 해결 (`docs/bug/0002`):
   - `GetProcessForPID` 가 macOS 26 에서 제거 → PSN 을 `SLSGetWindowOwner`→`SLSGetConnectionPSN` 체인으로 획득.
   - `_AXUIElementGetWindow` 는 dlsym 불가(링크 타임 전용) → `@_silgen_name` 으로 바인딩. 이게 axElement 가 전부 nil 이던 진짜 원인(AXRaise 불가).
   - `makeKeyWindow` 바이트(0x20 의 0xff, 레코드 순서) 보정. → SLPS(앱 front) + AXRaise(그 창 위로) 동작.
3. **스위처 바깥 클릭 시 닫기** — `NSEvent.addGlobalMonitorForEvents`(마우스 다운) 로 패널 밖 클릭 감지 → 취소.
4. **초기 선택 = 현재 활성 창**(index 0), 셀 정확 높이 + Layout 간격(n-1) 보정으로 **패딩 대칭**, 방향키 이동 시 **자동 스크롤**(ScrollViewReader), **셀 빨간 × 닫기 버튼**.
5. **단축키 변경 UI** — 자체 레코더(`ShortcutRecorder`/`KeyCaptureNSView`). 레코딩 중 전역 탭 트리거 무시(`isRecordingShortcut`). 변경 즉시 반영(컨트롤러가 profiles 를 매번 읽음).
6. **manual 크기** — `AppearanceSize.manual` + `manualCellHeight`(height 만 지정, width=height×1.45). AppearancePane 슬라이더.
7. **네이티브 ⌘Tab 비활성화 플래그** — `CGSSetSymbolicHotKeyEnabled`(id 1=⌘Tab, 2=⌘⇧Tab). 시작 시 적용, 토글 즉시 반영, **종료 시 복원**.
8. **수면/깨어남 복구** — `didWake`/`screensDidWake`/`sessionDidBecomeActive` 시 이벤트 탭 재생성 + ⌘Tab 설정 재적용 (CGEventTap 이 sleep 후 무효화되는 문제 대응).

## 검증
- `swift test` 46/46 통과. `.app` Developer ID 서명·실행 OK. 포커스/열거는 사용자 실기 확인(포커스 정상 동작 확인됨).

## 핵심 지식
- macOS 26 에서 다른 앱 창을 active 전환: 공개 API(activate/AXFrontmost) 전부 무력, **SLPS 만 유효**. PSN 은 윈도우→connection→PSN 체인. (메모리 `macos26-window-focus`)
