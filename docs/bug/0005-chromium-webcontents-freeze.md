# 0005 — Chromium WebContents 프리즈 (Chrome·Codex 전환 후 마지막 프레임 고정)

2026-09-21 · macOS 26.5.2 실기 관찰 + Chromium 153 소스·Apple AX 계약 대조

## 문서 목적과 적용 범위

- 목적: Indou 전환 후 Chromium 계열 앱의 WebContents가 마지막 프레임으로 멈추는 증상의 관찰 근거, 원인 판정, 수정 동작, 검증 상태를 재사용 가능하게 남긴다.
- 적용 범위: macOS 26 계열 + Chromium 153 계열 앱(Chrome·Codex 등). 포커스/오버레이/썸네일 캡처 경로.
- 주의: 실기 A/B 재현 확인 전이므로 "완전 해결"이 아니라 **완화**로만 표기한다.

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

이 문서에 적힌 Chromium 내부 이슈 번호는 별도로 확인하지 않았으므로 인용하지 않는다. Indou 쪽 이슈 번호도 부여하지 않는다.

## 증상

- 스위처로 전환한 뒤, Chrome/Codex의 주소창·새로고침 같은 native/top chrome은 반응하는데 **WebContents 영역만 마지막 프레임으로 정지**한다.
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

판정(코드·계약 근거 기반, 실기 재현 확인 전):

1. **오버레이가 focus보다 늦게 내려가면 Chromium 창이 occluded로 판정될 창이 있다.** Indou 오버레이는 `.popUpMenu` 레벨로 모든 Space에 뜨는 패널이라, focus 시점에 남아 있으면 OS가 대상 창을 visible로 보지 않을 수 있다. 1초 지연 반영 규칙 때문에 순간적인 피복도 occluded로 굳을 수 있다.
2. **occluded가 굳으면 렌더러가 hidden 처리되고, 마지막 프레임이 그대로 남는다.** native UI(브라우저 프로세스)는 살아 있으므로 "top chrome은 반응, WebContents만 정지"라는 관찰과 일치한다(정합성 근거이며 증명은 아님).
3. **AX 호출이 길게/중복으로 얽히면 포커스 완료가 지연된다.** 앱/창 AX timeout이 지정되지 않았고, main 창 지정·raise·activate가 겹치면 그만큼 창 순서 변경이 늘어난다. WindowServer의 `OrderWindowGroup`/`orderOut` churn이 이 경로와 맞물린다.
4. **캡처 경로가 세션 경계를 넘어 살아 있으면 전환 중 부하가 겹친다.** 동시성 상한과 세션 취소가 없으면 프레임 전환 직후에도 캡처가 계속 돌아 occlusion/포커스 타이밍과 경합한다.

## 수정 파일과 동작 (현재 코드 확인)

변경 귀속은 전달받은 변경 목록 기준이며, 아래는 해당 파일을 직접 읽어 확인한 현재 동작이다.

### `Sources/Indou/Switcher/SwitcherController.swift`

- `closeSession(commit:)`: `sessionGeneration` 증가 → `thumbnails.cancelPendingCaptures()` → `panel.dismiss()` → `backdrop.dismiss()` 순서로 세션을 닫는다. 캡처 중단이 오버레이 dismiss보다 먼저 온다.
- `commit()`: `closeSession(commit: true)`를 **먼저** 호출한 뒤 `WindowActions.focus(...)`를 호출한다. 즉 overlay/backdrop orderOut 이후에 포커스를 요청한다.
- `loadWindows`: `store.settings.appearance.showThumbnails`가 false면 `thumbnails.refreshContent()`(SCShareableContent 조회)를 아예 호출하지 않는다.
- `layoutAndPresent`: `guard store.settings.appearance.showThumbnails else { return }`로 캡처 요청을 건너뛴다. true일 때만
  - 최소화 필터: `captureMinimized || !$0.isMinimized` (설정 `advanced.captureMinimizedWindows`가 false면 최소화 창 제외)
  - 해상도: `min(1.0, max(0.25, settings.advanced.thumbnailResolutionScale))`를 `screen.backingScaleFactor`에 곱해 전달
  - 동시성: `settings.advanced.maxConcurrentCaptures` 전달

### `Sources/Indou/Overlay/BackdropWindow.swift`

- `present()`: 프레임 설정 → `alphaValue = 0` → `orderFrontRegardless()` → `alphaValue = 1` (깜빡임 없는 프리스테이징).
- `dismiss()`: `alphaValue = 0` → `orderOut(nil)`. orderOut 전에 먼저 투명화한다.
- 관련 파일 `Sources/Indou/Overlay/SwitcherPanel.swift`의 `dismiss()`도 동일하게 `alphaValue = 0` → `orderOut(nil)` 형태임을 확인했다.

### `Sources/PrivateWindowServer/PreciseFocus.swift`

- `axMessagingTimeoutSeconds = 0.5`. 앱 요소와 창 요소 각각에 `AXUIElementSetMessagingTimeout`을 적용한다.
- `raise(_:)`는 창 요소에 timeout 0.5s를 설정하고 `kAXRaise`를 **1회** 수행한 뒤 `== .success` 반환값을 그대로 돌려준다. 현재 코드에서 `kAXMain` 호출은 사용되지 않는다(저장소 전체에서 `kAXMain`/`AXMain`은 `docs/memory/research-raw.json`의 조사 기록에만 등장).
- `focus(...)`: private 경로면 `setFrontProcessWithOptions` 성공 + `postMakeKey`의 **두 번 post 반환을 모두 검사**해 성공 여부를 판단한다. 실패하면 공개 경로(`kAXFrontmost` 설정 → `raise` → `NSRunningApplication.activate()`)로 폴백한다.
- private 성공 판정은 심볼 부재 시 실패로 처리되어 공개 폴백으로 내려간다(graceful degradation 유지).
- 현재 코드에서 `kAXFrontmost` 설정 반환값은 검사하지 않는다(로그에도 반영하지 않음).

### `Sources/Indou/Windows/WindowActions.swift`

- `axMessagingTimeoutSeconds = 0.5`. 최소화 창 복원 시 창 AX 요소에 timeout을 설정한 뒤 `kAXMinimized = false`를 설정한다.

### `Sources/Indou/Capture/ThumbnailStore.swift`

- `concurrencyLimit = min(8, max(1, maxConcurrent))` — 요청 동시성 1...8 상한.
- `cancelPendingCaptures()`: `generation` 증가, `pending`/`scheduled` 비우고 실행 중 task에 `cancel()`만 건다. **active task는 실제로 `finishCapture`가 불릴 때까지 슬롯을 계속 차지**하므로 다음 세션이 상한을 넘길 수 없다.
- `finishCapture`: `taskGeneration == generation`일 때만 `scheduled` 해제와 이미지 저장을 한다(이전 세대의 늦은 쓰기 차단).
- `refreshContent()` 실패 시 `scWindows`를 비운다. 이 경우 `requestThumbnails`가 `scWindows[id]` 조회에서 걸러져 stale SCWindow로 캡처하지 않는다.

### 참고(이번 판정에서 함께 읽은 파일)

- `Sources/PrivateWindowServer/SkyLightSymbols.swift`: `getWindowOwner`/`getConnectionPSN` 폴백 로더, `frontProcessPID()`.
- `Sources/Indou/Windows/AXUIElement+Helpers.swift`: `setMessagingTimeout`, `perform`.
- `Sources/IndouKit/Settings/SettingsSchema.swift`: `showThumbnails`(기본 true), `captureMinimizedWindows`(기본 false), `thumbnailResolutionScale`(기본 1.0), `maxConcurrentCaptures`(기본 8).

## 검증

- `swift build` 성공: **exit 0, `Build complete! (1.34s)`** — 최종 캡처 통합 상태에서 확인된 결과를 재사용한다(이번 문서 작업에서 재실행하지 않음).
- `swift test` 성공: **exit 0, 10 suites의 50 tests 통과**.
- 실기 A/B(프리즈 재현·완화 비교)는 아직 실행하지 않았다.
- 코드 수준 근거: 위 "수정 파일과 동작"은 파일을 직접 읽어 확인했고, "Chromium 153의 macOS occlusion 경로"는 명시한 4개 소스에서 확인했다.

## 남은 실기 위험

1. **실기 재현 미확인**: 포커스·오버레이 순서 변경이 실제 프리즈를 없애는지/줄이는지 확인되지 않았다. 현재 상태는 완화 후보다.
2. **occlusion 판정이 OS로 위임된 구조**: orderOut 이후 대상 창의 `NSWindow.occlusionState`가 실제로 visible로 갱신되는지, 1초 지연 예약이 제때 취소되는지는 실기 WindowServer/Chromium 로그로만 확인 가능하다. 갱신이 지연되면 1초 뒤 occluded 반영이 그대로 굳을 수 있다.
3. **AX `kAXErrorCannotComplete`는 실패 확정이 아님**: Apple 문서상 이 오류는 "동작 실패"가 아니라 응답 지연일 수 있다. 현재 `kAXRaise`는 1회만 호출하고 실패 시 재시도하지 않으므로, 반환값이 로그의 실패로만 남고 실제 raise는 성공했을 여지가 있다. 반대 경우도 있어 로그(`focus wid=... raised=false`)만으로 raise 실패를 단정하지 않는다.
4. **`kAXMain` 제거의 부작용 미확인**: main 창 지정을 생략한 대가로 일부 앱에서 key/main 상태가 기대와 다를 수 있다(추론, 실기 확인 필요).
5. **취소된 캡처와 새 세션 캡처의 중복 가능성(추론)**: `cancelPendingCaptures`가 `scheduled`를 즉시 비우므로 같은 창이 다음 세션에서 다시 큐잉될 수 있다. 상한은 active task 수로 계속 지켜지지만, 같은 창에 대한 캡처가 겹칠 수 있는지는 실측하지 않았다.
6. **사설 포커스 경로 의존**: `usePreciseFocus`가 꺼져 있거나 SkyLight 심볼이 없으면 공개 `activate()` 폴백만 남는다. 공개 경로는 macOS 14+ 협력적 activation이라 특정 창 승격 보장이 약하다(참조: `docs/acknowledge/private-api.md`).
7. **프리즈 순간의 프로세스 상태 미확보**: idle sample은 사후 관찰이라 프리즈 시점의 main/renderer/GPU 상태 근거로 쓸 수 없다.

## 확인 불가 항목

- `UpdateWebContentsVisibility(OCCLUDED)` 이후 렌더러가 어떤 조건에서 프레임 갱신을 재개하는지: `content/browser/web_contents/web_contents_impl.cc` 전체를 확인하지 못해 미검증.
- Chromium 쪽 알려진 이슈 번호, macOS 26 특정 빌드(26.5.2)에서의 회귀 여부: 확인하지 않았다.
- Indou 변경 전/후의 실기 전환 성공률, WebContents 정지 여부, WindowServer 로그의 churn 감소 여부: 실기 로그 없음.
