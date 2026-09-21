# 0005 — Chromium WebContents 프리즈 (Chrome·Codex 전환 후 마지막 프레임 고정)

2026-09-21 · macOS 26.5.2 실기 A/B + Chromium 153 소스·Apple AX 계약 대조

## 문서 목적과 적용 범위

- 목적: Indou 전환 후 Chromium 계열 앱의 WebContents가 마지막 프레임으로 멈추는 증상의 관찰 근거, 원인 판정, 수정 동작, 검증 상태를 재사용 가능하게 남긴다.
- 적용 범위: macOS 26 계열 + Chromium 153 계열 앱(Chrome·Codex 등). 포커스/오버레이/썸네일 캡처 경로.
- 해결 범위: ScreenCaptureKit 썸네일 캡처가 끝나기 전에 Chromium 창을 전면화하던 경합을 제거한다.

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

실기 A/B로 확인된 직접 트리거는 **진행 중인 ScreenCaptureKit 캡처와 Chromium 창 전면화의 중첩**이다.

1. v0.1.6에서 썸네일을 끄고 같은 private focus·AX raise 경로로 일반 Chrome 창을 선택하면 동적 콘텐츠가 계속 갱신되고 `Page Unresponsive`가 생기지 않았다.
2. 썸네일을 켠 뒤 스위처를 열고 약 0.4초 안에 같은 창을 선택하자 target `wid=41340` 포커스 직후 `Page Unresponsive`가 재현됐다. 취소된 `Task`가 ScreenCaptureKit 작업의 종료까지 보장하지 않으므로 `cancelPendingCaptures()`만으로는 캡처와 포커스의 중첩을 막지 못했다.
3. 수정본은 커밋 시 신규 캡처를 폐기하되 실행 중 캡처를 취소하지 않고 완료까지 기다린 다음 포커스한다. 같은 조건을 5회 연속 반복해 모두 target `wid=41340`, `didPrivate=true`, `raised=true`였고 `Page Unresponsive`는 0회였다.
4. private focus와 AX raise는 썸네일 on/off A/B에서 동일했으므로 단독 직접 트리거에서는 제외했다. Chromium의 macOS 26 occlusion 경로는 프레임 정지가 지속되는 메커니즘과 정합하지만, 이번 실기로 내부 occlusion 상태 전이 자체를 계측한 것은 아니다.

## 수정 파일과 동작 (현재 코드 확인)

변경 귀속은 전달받은 변경 목록 기준이며, 아래는 해당 파일을 직접 읽어 확인한 현재 동작이다.

### `Sources/Indou/Switcher/SwitcherController.swift`

- `closeSession(commit:)`: 세션 세대를 무효화하고, commit이면 실행 중 캡처 task의 스냅샷을 받으며 commit이 아니면 기존처럼 task를 취소한다. 이어 panel/backdrop을 dismiss한다.
- `focusAfterClosing(_:)`: panel/backdrop을 먼저 내린 뒤 스냅샷의 캡처가 자연 종료될 때까지 기다린다. 대기 중 새 세션이 시작되지 않은 경우에만 `WindowActions.focus(...)`를 호출한다.
- 키보드 commit과 컨텍스트 메뉴 focus가 모두 `focusAfterClosing(_:)`를 사용한다.
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
- `invalidatePendingCaptures()`: `generation` 증가, `pending`/`scheduled` 제거, 현재 active task 스냅샷 반환을 한 경로로 통합한다.
- `cancelPendingCaptures()`: 취소/닫기 경로에서 active task를 취소한다.
- `capturesToFinishBeforeFocus()`: 포커스 commit 경로에서 active task를 취소하지 않고 반환한다. 호출자는 해당 task가 자연 종료된 뒤 포커스한다.
- `finishCapture`: `taskGeneration == generation`일 때만 `scheduled` 해제와 이미지 저장을 한다(이전 세대의 늦은 쓰기 차단).
- `refreshContent()` 실패 시 `scWindows`를 비운다. 이 경우 `requestThumbnails`가 `scWindows[id]` 조회에서 걸러져 stale SCWindow로 캡처하지 않는다.

### 참고(이번 판정에서 함께 읽은 파일)

- `Sources/PrivateWindowServer/SkyLightSymbols.swift`: `getWindowOwner`/`getConnectionPSN` 폴백 로더, `frontProcessPID()`.
- `Sources/Indou/Windows/AXUIElement+Helpers.swift`: `setMessagingTimeout`, `perform`.
- `Sources/IndouKit/Settings/SettingsSchema.swift`: `showThumbnails`(기본 true), `captureMinimizedWindows`(기본 false), `thumbnailResolutionScale`(기본 1.0), `maxConcurrentCaptures`(기본 8).

## 검증

- 재현본(v0.1.6): 썸네일 on + 캡처 시작 약 0.4초 뒤 일반 Chrome 창 focus에서 `Page Unresponsive` 재현. 같은 target은 `wid=41340`, private focus와 AX raise는 성공 로그가 남았다.
- 음성 대조(v0.1.6): 썸네일 off에서 같은 창의 프레임 해시가 연속 변경됐고 `Page Unresponsive`가 없었다.
- 수정본: 서명된 `.build/Indou.app`에서 썸네일 on 상태로 같은 일반/시크릿 창 전환을 5회 연속 실행했다. 5회 모두 target `wid=41340` 포커스 성공, `Page Unresponsive` 0회, 최종 프레임 해시 연속 변경을 확인했다.
- 배포본: notarized `v0.1.7` 자산의 SHA-256과 서명을 검증해 설치한 뒤 같은 일반/시크릿 창 전환에서 target `wid=41340` 포커스 성공, `Page Unresponsive` 0회, 3개 연속 프레임 해시 변경을 확인했다.
- `git diff --check && swift build` 성공: exit 0, `Build complete! (2.25s)`.
- `swift test` 성공: exit 0, 10 suites의 50 tests 통과.

## 남은 실기 위험

1. **캡처 완료만큼 포커스가 지연됨**: 실기 5회에서 commit→focus 간격은 2~24ms였지만, ScreenCaptureKit 응답이 비정상적으로 늦으면 포커스도 함께 늦어진다. 프리즈를 재도입하는 timeout 폴백은 두지 않았다.
2. **occlusion 판정이 OS로 위임된 구조**: orderOut 이후 대상 창의 `NSWindow.occlusionState` 전이는 직접 계측하지 않았다. 별도 occlusion 회귀가 있으면 캡처 경합 제거와 무관하게 재발할 수 있다.
3. **AX `kAXErrorCannotComplete`는 실패 확정이 아님**: Apple 문서상 이 오류는 "동작 실패"가 아니라 응답 지연일 수 있다. 로그의 `raised=false`만으로 실제 raise 실패를 단정하지 않는다.
4. **사설 포커스 경로 의존**: `usePreciseFocus`가 꺼져 있거나 SkyLight 심볼이 없으면 공개 `activate()` 폴백만 남는다. 공개 경로는 macOS 14+ 협력적 activation이라 특정 창 승격 보장이 약하다.

## 확인 불가 항목

- `UpdateWebContentsVisibility(OCCLUDED)` 이후 렌더러가 어떤 조건에서 프레임 갱신을 재개하는지: `content/browser/web_contents/web_contents_impl.cc` 전체를 확인하지 못해 미검증.
- Chromium 쪽 알려진 이슈 번호, macOS 26 특정 빌드(26.5.2)에서의 회귀 여부: 확인하지 않았다.
- Chromium 내부에서 ScreenCaptureKit 경합이 `Page Unresponsive`와 지속 occlusion으로 이어지는 정확한 호출 스택: Chromium trace를 수집하지 않아 미확인.
