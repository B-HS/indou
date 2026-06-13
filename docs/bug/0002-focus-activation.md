# 0002 — 선택한 창이 앞으로 오지만 앱이 active 되지 않음

2026-06-13 · 사용자 실기 테스트

## 증상
스위처에서 창을 선택하면 **시각적으로는 앞으로 오는데**(AXRaise), OS의 frontmost/active 앱(메뉴바·키 입력)은 이전 앱 그대로.

## 근본 원인 (헤드리스 검증으로 특정)
1. **`GetProcessForPID` 가 macOS 26 에서 완전히 제거됨** — `dlsym(RTLD_DEFAULT, "GetProcessForPID")` 가 `nil`. 그래서 SLPS 에 필요한 `ProcessSerialNumber` 를 못 얻어 정밀 포커스(`_SLPSSetFrontProcessWithOptions`)가 **아예 실행되지 않았고**, AXRaise(창만 올림)만 동작.
2. **공개 `NSRunningApplication.activate()` 는 무력** — macOS 14+ 협력적 activation. 헤드리스 검증: activate() 후에도 frontmost 안 바뀜.
3. **AX `kAXFrontmostAttribute = true` 도 무력** — err 0 반환하지만 frontmost 안 바뀜(macOS 26).

→ 즉 macOS 26 에서 다른 앱을 active 로 만드는 유일하게 확실한 길은 **SLPS** 이고, 그게 PSN 부재로 막혀 있었다.

## 해결 (대상: `PrivateWindowServer/PreciseFocus.swift`, `SkyLightSymbols.swift`)
`GetProcessForPID` 대신 **윈도우 → 소유 connection → PSN** 체인으로 PSN 획득:
```
cid = SLSMainConnectionID()
SLSGetWindowOwner(cid, windowID, &ownerCID)   // 창의 소유 connection
SLSGetConnectionPSN(ownerCID, &psn)           // 그 connection 의 PSN
_SLPSSetFrontProcessWithOptions(&psn, windowID, kCPSUserGenerated=0x200)
makeKeyWindow(psn, windowID)                  // 0xf8 레코드 2회
```
**헤드리스 검증**: `_SLPSGetFrontProcess` 로 읽은 window-server front pid 가 setFront 후 타겟으로 바뀜(before 63500 → after 74650). (`NSWorkspace.frontmostApplication` 은 지연 반영되어 테스트에서 안 보였을 뿐.)

`makeKeyWindow` 의 빠졌던 부분도 수정: 오프셋 `0x20` 에 16바이트 `0xFF`, 레코드 순서(0x02 → 0x01).

## 비고
- `getProcessForPID` 심볼 로더는 남겨둠(다른 OS 폴백). macOS 26 에선 `nil`.
- 사설 API 비활성/실패 시 폴백은 activate()+AX(약함) — 이 경우 active 전환이 안 될 수 있음을 사용자에게 안내.
