# 사설(Private) API 의존 — 리스크 명시

> Indou 는 AltTab 과 동일하게 일부 macOS 비공개(CGS/SkyLight/SLPS) API 에 의존한다. 이 결정의 영향과 완화책을 명시한다.

## 사용하는 사설 심볼 (모두 `PrivateWindowServer` 모듈에 격리)

| 심볼 | 용도 | 공개 대안 |
|------|------|-----------|
| `_SLPSSetFrontProcessWithOptions` + `SLPSPostEventRecordTo` | **정확한 윈도우 포커스** (같은 앱의 특정 창 raise) | 없음. `NSRunningApplication.activate` 는 macOS 14+ 협력적 모델이라 특정 창 강제 포커스 불가, `NSApplicationActivateIgnoringOtherApps` deprecated |
| `CGSCopyManagedDisplaySpaces`, `CGSCopyWindowsWithOptionsAndTags`, `CGSCopySpacesForWindows`, `CGSGetWindowLevel` | **Space 열거/멤버십/z-order** (다른 Space 윈도우 정확 수집) | 없음. Spaces 공개 API 부재 |
| `CGSSymbolicHotKey` (`CGSGetSymbolicHotKeyValue` 등) | 시스템 ⌘⇥/⌘⇧⇥/⌘\` **비활성화/복원** (옵션) | 없음 |
| `_AXUIElementGetWindow` | AX 요소 ↔ CGWindowID 매핑 (방어적 폴백) | SCWindow.windowID + frame/PID 매칭 우선 |
| `CGSHWCaptureWindowList` | 최소화 창 썸네일 (옵션·기본 off) | 캐시 프레임 + 아이콘 폴백 |

## 리스크

1. **Mac App Store 배포 불가** — 사설 프레임워크 링크는 심사 리젝. → 직배포(Developer ID/notarization) 전용 (0002 #1).
2. **OS 업데이트 취약** — 비공개 심볼은 deprecated 표기조차 없고, 마이너/베타 업데이트에서 시그니처·동작이 바뀌거나 사라질 수 있다. 특히 `SLPS` 의 매직 바이트 오프셋(0xf8 등)은 OS 버전 의존 리버스 산물.
3. **런타임 크래시 위험** — 심볼 부재 시 호출하면 크래시.

## 완화책 (구현 규칙)

- 모든 사설 호출은 `PrivateWindowServer` 단일 모듈에만 둔다. 나머지 코드는 공개 인터페이스로만 접근.
- `@_silgen_name` 또는 `dlsym` 으로 심볼을 **방어적으로 로드**하고, 부재 시 `nil`/실패 반환 → **graceful degradation** (예: Space 열거 실패 시 현재 Space 만, 정밀 포커스 실패 시 공개 `activate` 폴백).
- 사설 기능은 가능한 한 **설정에서 토글** 가능하게 해, 회귀 시 사용자가 끌 수 있게 한다.
- 매 macOS 업데이트마다 회귀 테스트 (수동 체크리스트는 PROCESS.md).
