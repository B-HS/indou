# 0005 — Chromium WebContents 프리즈 (Chrome·Codex 전환 후 마지막 프레임 고정)

2026-09-21 · macOS 26.5.2 실기 A/B + Chromium 153 소스·Apple AX 계약 대조

## 문서 목적과 적용 범위

- 목적: Indou 전환 후 Chromium 계열 앱의 WebContents가 마지막 프레임으로 멈추는 증상의 관찰 근거, 원인 판정, 수정 동작, 검증 상태를 재사용 가능하게 남긴다.
- 적용 범위: macOS 26 계열 + Chromium 153 계열 앱(Chrome·Codex 등). 포커스/오버레이/썸네일 캡처 경로.
- 해결 범위: Chromium public AX focus를 유지하고, 직렬 단일 프레임 스트림의 종료가 확인된 뒤 창을 전면화한다.

## 출처와 대상 버전

| 항목 | 값 |
|------|-----|
| 확인 날짜 | 2026-09-21 |
| 관찰 OS | macOS 26.5.2 |
| 대상 앱 | Chrome, Codex (둘 다 Chromium 153.0.8010.48) |
| 대상 프로젝트 | Indou (`swift-tools-version:6.2`, `platforms: [.macOS(.v26)]`, Swift 6 language mode) |

Chromium 153.0.8010.48 소스(모두 확인함):

- `https://raw.githubusercontent.com/chromium/chromium/153.0.8010.48/content/app_shim_remote_cocoa/web_contents_occlusion_checker_mac.mm`
- `https://raw.githubusercontent.com/chromium/chromium/153.0.8010.48/content/app_shim_remote_cocoa/web_contents_view_cocoa.mm`
- `https://raw.githubusercontent.com/chromium/chromium/153.0.8010.48/content/browser/renderer_host/render_widget_host_view_mac.mm`
- `https://raw.githubusercontent.com/chromium/chromium/153.0.8010.48/content/browser/web_contents/web_contents_view_mac.mm`

Apple AX 계약:

- `AXUIElementSetMessagingTimeout(_:_:)` — https://developer.apple.com/documentation/applicationservices/1459345-axuielementsetmessagingtimeout
- `AXUIElementPerformAction(_:_:)` — https://developer.apple.com/documentation/applicationservices/1462091-axuielementperformaction

Apple ScreenCaptureKit 계약:

- `SCStreamOutput` — https://developer.apple.com/documentation/screencapturekit/scstreamoutput
- `SCStream.stopCapture()` — https://developer.apple.com/documentation/screencapturekit/scstream/stopcapture(completionhandler:)

이 문서에 적힌 Chromium 내부 이슈 번호는 별도로 확인하지 않았으므로 인용하지 않는다. Indou 쪽 이슈 번호도 부여하지 않는다.

## 증상

- 스위처로 전환한 뒤, Chrome/Codex의 주소창·새로고침 같은 native/top chrome은 반응하는데 **WebContents 영역만 마지막 프레임으로 정지**한다.
- 확정 재현: Chrome 일반 창에서 동적 콘텐츠를 재생하고 시크릿 창을 연 뒤 다른 앱으로 이동한다. 썸네일 캡처가 진행 중인 시점에 Indou로 일반 창을 선택하면 Chrome의 `Page Unresponsive` 창이 나타난다.
- WindowServer 로그에서 포커스 직후 `OrderWindowGroup`/`orderOut` churn이 관찰됐다.
- 프리즈 이후 시점의 main/renderer/GPU 프로세스 sample은 idle 상태였다(정지 순간의 상태가 아님).
- 물리 메모리 128GB 환경이라 단순 메모리 부족은 주원인 후보에서 제외했다.

## Chromium 153의 macOS occlusion 경로 (소스 확인 사실)

1. `web_contents_occlusion_checker_mac.mm`의 `manualOcclusionDetectionSupportedForPackedVersion:`는 `(version >= 13'00'00 && version < 13'03'00) || version >= 26'00'00`이면 **NO**를 반환한다. 즉 macOS 26에서는 수동 occlusion 계산이 꺼진다.
2. 같은 파일의 `isWindowOccluded:windowList:`는 macOS가 `NSWindowOcclusionStateVisible`이 아니라고 답하면 그대로 YES를 반환하고, 수동 계산이 비활성인 경우 그 외에는 NO를 반환한다. macOS 26에서 occlusion 판정은 OS에 위임된다.
3. `performOcclusionStateUpdates`는 `[NSApp orderedWindows]`를 front→back 순회하며 `[window setOccluded:]`를 호출하고, 이는 `NSWindowDidChangeOcclusionStateNotification`을 발생시킨다(수동 감지 활성 시에만 order 변경 알림을 관찰).
4. `web_contents_view_cocoa.mm`의 `updateWebContentsVisibility:`는 **비-occluded는 즉시** 반영하고, **occluded는 1.0초 지연 후** 반영한다(`kOcclusionUpdateDelayInSeconds = 1.0`, 중복은 coalesce). 지연 중 비-occluded/hidden이 오면 예약이 취소된다.
5. `web_contents_view_mac.mm`의 `OnWindowVisibilityChanged`는 `kOccluded`를 `Visibility::OCCLUDED`로 매핑해 `web_contents_->UpdateWebContentsVisibility(visibility)`를 호출한다. 이것이 app shim → browser로 넘어가는 지점이다.
6. `render_widget_host_view_mac.mm`의 `WasOccluded()`는 `host()->WasHidden()`과 `browser_compositor_->SetRenderWidgetHostIsHidden(true)`를 호출한다.

`UpdateWebContentsVisibility(OCCLUDED)` 이후 렌더러가 실제로 프레임 갱신을 멈추는 구간은 `web_contents_impl.cc` 전체를 확인하지 못했으므로 **추론**으로 둔다(아래 "확인 불가 항목" 참조).

## 원인 판정

v0.1.7 재검증으로 확인된 직접 오류는 **같은 Chrome 프로세스의 일반 창과 시크릿 창 사이에서 private make-key가 성공을 반환하고도 다른 창을 전면에 남기는 것**이다.

1. Chrome에서 실제 `⌘⇧N`으로 시크릿 창을 열고 다른 앱으로 이동한 뒤 일반 동영상 창 `wid=41896`을 선택했다.
2. private focus를 유지한 대조군은 10회 모두 로그상 `wid=41896`, `didPrivate=true`였지만 화면은 일반 창과 시크릿 창이 번갈아 남았다. 5회는 시크릿 창의 정적 WebContents가 그대로 보여 프리즈로 관찰됐다.
3. 같은 target에서 Chromium만 private focus를 끄고 `kAXFrontmost` + `kAXRaise` + public activate를 사용하자 10회 모두 `wid=41896`, `didPrivate=false`, `raised=true`였고 일반 창의 WebContents 영역이 계속 갱신됐다.
4. v0.1.7의 캡처 대기 수정은 이 잘못된 key window 선택을 해결하지 못했다. 이전 썸네일 on/off 비교는 목표 창 확인이 일관되지 않아 직접 원인 판정 근거로 사용할 수 없다.
5. v0.1.8은 원인 분리용 안전 조치로 Chrome·Codex 캡처를 제외했다. 이후 썸네일 복구에서는 동시 일회성 캡처를 재사용하지 않고, 한 번에 스트림 하나만 열어 첫 완성 프레임을 받은 즉시 닫는 방식으로 경합 범위를 제거한다.

## 수정 파일과 동작 (현재 코드 확인)

변경 귀속은 전달받은 변경 목록 기준이며, 아래는 해당 파일을 직접 읽어 확인한 현재 동작이다.

### `Sources/Indou/Switcher/SwitcherController.swift`

- `closeSession(commit:)`: 세션 세대를 무효화하고 대기 큐를 폐기한다. 실행 중 스트림 task도 취소하며, commit이면 해당 task를 호출자에게 반환한다.
- `focusAfterClosing(_:)`: panel/backdrop을 먼저 내린 뒤 실행 중 스트림의 `stopCapture()` 완료까지 기다린다. 대기 중 새 세션이 시작되지 않은 경우에만 `WindowActions.focus(...)`를 호출한다.
- 키보드 commit과 컨텍스트 메뉴 focus가 모두 `focusAfterClosing(_:)`를 사용한다.
- `loadWindows`: `WindowEnumerator`가 창 열거에 사용한 `SCWindow` 사전을 `ThumbnailStore`에 전달한다. 썸네일용 `SCShareableContent` 중복 조회는 없다.
- `layoutAndPresent`: `guard store.settings.appearance.showThumbnails else { return }`로 캡처 요청을 건너뛴다. true일 때만
  - 최소화 필터: `captureMinimized || !$0.isMinimized` (설정 `advanced.captureMinimizedWindows`가 false면 최소화 창 제외)
  - 선택 창 우선: 현재 선택 창을 캡처 큐의 첫 항목으로 배치
  - 해상도: `min(1.0, max(0.25, settings.advanced.thumbnailResolutionScale))`를 `screen.backingScaleFactor`에 곱해 전달

### `Sources/Indou/Overlay/BackdropWindow.swift`

- `present()`: 프레임 설정 → `alphaValue = 0` → `orderFrontRegardless()` → `alphaValue = 1` (깜빡임 없는 프리스테이징).
- `dismiss()`: `alphaValue = 0` → `orderOut(nil)`. orderOut 전에 먼저 투명화한다.
- 관련 파일 `Sources/Indou/Overlay/SwitcherPanel.swift`의 `dismiss()`도 동일하게 `alphaValue = 0` → `orderOut(nil)` 형태임을 확인했다.

### `Sources/PrivateWindowServer/PreciseFocus.swift`

- `axMessagingTimeoutSeconds = 0.5`. 앱 요소와 창 요소 각각에 `AXUIElementSetMessagingTimeout`을 적용한다.
- `raise(_:)`는 창 요소에 timeout 0.5s를 설정하고 `kAXRaise`를 **1회** 수행한 뒤 `== .success` 반환값을 그대로 돌려준다. 현재 코드에서 `kAXMain` 호출은 사용되지 않는다(저장소 전체에서 `kAXMain`/`AXMain`은 `docs/memory/research-raw.json`의 조사 기록에만 등장).
- `focus(...)`: private 경로면 `setFrontProcessWithOptions` 성공 + `postMakeKey`의 **두 번 post 반환을 모두 검사**해 성공 여부를 판단한다. 실패하면 공개 경로(`kAXFrontmost` 설정 → `raise` → `NSRunningApplication.activate()`)로 폴백한다.
- Chrome·Codex는 `WindowActions.focus`에서 `usePrivate=false`로 전달하므로 이 private 경로에 진입하지 않는다.
- private 성공 판정은 심볼 부재 시 실패로 처리되어 공개 폴백으로 내려간다(graceful degradation 유지).
- 현재 코드에서 `kAXFrontmost` 설정 반환값은 검사하지 않는다(로그에도 반영하지 않음).

### `Sources/Indou/Windows/WindowActions.swift`

- `axMessagingTimeoutSeconds = 0.5`. 최소화 창 복원 시 창 AX 요소에 timeout을 설정한 뒤 `kAXMinimized = false`를 설정한다.
- Chrome·Codex는 사용자 설정의 precise focus가 켜져 있어도 private focus를 우회한다. 그 외 앱은 기존 설정과 동작을 유지한다.

### `Sources/Indou/Capture/ThumbnailStore.swift`

- 패널 표시 150ms 뒤 캡처를 시작해 첫 호출의 열거·렌더 경로와 캡처 부하를 분리한다.
- `SCStream` 하나만 실행하고 `queueDepth = 1`로 첫 `.complete` 프레임을 받은 뒤 즉시 `stopCapture()` 완료를 기다린다. 프레임이 없으면 1초 후 종료한다.
- 취소·commit 모두 active task를 취소한다. 프레임 대기를 깨운 뒤 `stopCapture()`가 끝나야 task가 완료되므로 포커스와 캡처가 겹치지 않는다.
- 이미지 캐시는 세션 사이에 유지한다. 같은 window id라도 PID·제목·프레임이 바뀌면 폐기해 재사용된 id나 크기 변경의 stale 이미지를 차단한다.
- 세션 generation이 다르면 늦게 끝난 task의 이미지를 저장하지 않는다.

### `Sources/Indou/Windows/WindowEnumerator.swift`

- ScreenCaptureKit 창 조회와 앱별 AX 조회를 병렬 실행한다.
- 열거에 사용한 `SCWindow` 사전을 보관해 썸네일 캡처가 같은 콘텐츠를 다시 조회하지 않게 한다.

### 참고(이번 판정에서 함께 읽은 파일)

- `Sources/PrivateWindowServer/SkyLightSymbols.swift`: `getWindowOwner`/`getConnectionPSN` 폴백 로더, `frontProcessPID()`.
- `Sources/Indou/Windows/AXUIElement+Helpers.swift`: `setMessagingTimeout`, `perform`.
- `Sources/IndouKit/Settings/SettingsSchema.swift`: `showThumbnails`(기본 true), `captureMinimizedWindows`(기본 false), `thumbnailResolutionScale`(기본 1.0). 병렬 캡처를 제거해 기존 `maxConcurrentCaptures` 값은 더 이상 저장하지 않으며 구 설정 파일의 키는 호환 디코더가 무시한다.

## 검증

- v0.1.7은 사용자 실기에서 재발했으며 해결 완료 판정을 폐기했다.
- 실패 대조군: 실제 `⌘⇧N` 시크릿 창 + 일반 동영상 창 target `wid=41896` + private focus에서 10회 중 5회 다른 시크릿 창이 전면에 남았다.
- 수정본: 같은 두 창과 target `wid=41896`에서 Chromium public AX focus를 10회 반복했다. 10회 모두 일반 창이 전면에 왔고 WebContents crop의 연속 프레임 해시가 달랐다.
- notarized v0.1.8 설치본: 같은 target과 전환을 5회 반복해 모두 `didPrivate=false`, `raised=true`, 연속 프레임 갱신을 확인했다.
- 스위처 화면에서 Chrome 일반·시크릿 창은 썸네일 대신 앱 아이콘을 표시하고, iTerm·Finder 등 비-Chromium 창은 기존 썸네일을 유지함을 확인했다.
- SCStream 수정본 첫 호출: 200ms 시점에 패널과 아이콘 placeholder가 표시됐고, 500ms 시점부터 Chrome 일반·시크릿을 포함한 실썸네일이 채워졌다. 두 번째 호출은 200ms 시점부터 캐시된 실썸네일을 표시했다.
- Chrome 일반 동적 페이지 `wid=42165` 선택 후 `didPrivate=false`, `raised=true`를 확인했고 5개 연속 WebContents 프레임 해시가 모두 달랐다.
- active stream 취소 경로의 commit→focus 간격은 19ms였으며 이후 동적 Chrome 창의 3개 연속 프레임 해시가 모두 달랐다.
- `swift test` 성공: 11 suites의 53 tests 통과. 서명 debug 앱 빌드·codesign 검증 성공.
- notarized v0.1.9 설치본: Chrome 일반·시크릿 실썸네일 표시와 재호출 200ms 캐시 표시를 확인했다. 일반 동적 페이지 `wid=42165` 포커스 후 5개 연속 프레임 해시가 모두 달랐다.

## 남은 실기 위험

1. **정적 캐시**: 같은 PID·제목·프레임의 창은 다음 세션에서 이전 프레임을 즉시 표시한다. 제목이나 크기가 바뀌면 자동 재캡처하지만 내용만 바뀐 경우에는 앱 재시작 전까지 이전 프레임을 유지한다.
2. **공개 AX 경로 의존**: macOS가 `kAXRaise`를 거부하면 특정 Chromium 창 승격이 실패할 수 있다. 로그의 `raised=false`로 식별한다.
3. **occlusion 판정이 OS로 위임된 구조**: 별도 macOS occlusion 회귀가 있으면 이번 캡처·key window 수정과 무관하게 재발할 수 있다.

## 확인 불가 항목

- `UpdateWebContentsVisibility(OCCLUDED)` 이후 렌더러가 어떤 조건에서 프레임 갱신을 재개하는지: `content/browser/web_contents/web_contents_impl.cc` 전체를 확인하지 못해 미검증.
- Chromium 쪽 알려진 이슈 번호, macOS 26 특정 빌드(26.5.2)에서의 회귀 여부: 확인하지 않았다.
- private make-key가 성공을 반환하고도 Chrome의 다른 privacy-mode 창을 남기는 내부 SkyLight/Chromium 호출 스택은 미확인이다.
