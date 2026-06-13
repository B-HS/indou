# 0003 — 배포본만 launch 즉시 크래시 (Bundle.module)

2026-06-13 · v0.1.0 배포 후 발견

## 증상
로컬 `.build/Indou.app` 은 실행되는데, **GitHub Release 로 받은 배포본은 실행해도 프로세스가 안 뜸**(launch 즉시 종료).

## 원인 (배포본 직접 실행으로 특정)
```
Indou/resource_bundle_accessor.swift:12: Fatal error: could not load resource bundle:
from .../Indou.app/Indou_Indou.bundle or /Users/runner/.../.build/.../release/Indou_Indou.bundle
```
SwiftPM **executable 타겟**이 생성하는 `Bundle.module` accessor는 후보 경로가 단 두 개다:
1. `Bundle.main.bundleURL/Indou_Indou.bundle` — `.app` **루트**(Contents/Resources 아님)
2. 하드코딩된 **빌드 경로**(`/Users/<builder>/.../.build/.../Indou_Indou.bundle`)

`build-app.sh` 는 번들을 `Contents/Resources/` 에 넣는데 accessor 는 거길 안 본다. 로컬에선 빌드 경로(`.build/...`)가 존재해 **우연히** 통과했지만, 배포본/타 머신엔 그 경로가 없어 `fatalError`. `AppDelegate.menuBarImage()` 가 `Bundle.module` 을 처음 건드리는 순간(상태바 설치) 크래시.

## 해결 (대상: `Package.swift`, `AppDelegate.swift`, `scripts/build-app.sh`)
취약한 `Bundle.module` 을 **완전히 제거**하고 리소스를 `Bundle.main` 으로 로드:
- `Package.swift`: Indou 타겟에서 `resources: [.process("Resources")]` → `exclude: ["Resources"]` (accessor 미생성).
- `build-app.sh`: `xcstringstool` 로 `.xcstrings`→`Contents/Resources/<lang>.lproj`(이미 함), `MenuBarIcon.png` 를 `Contents/Resources/` 에 직접 복사. 모듈 번들 복사 제거.
- `AppDelegate.menuBarImage()`: `Bundle.main.url(forResource:"MenuBarIcon",withExtension:"png")`.

## 검증
`.app` 를 `/tmp`(빌드 경로 없는 곳)로 복사해 실행 → 정상 launch(프로세스 유지). 빌드 경로 폴백이 차단된 배포본과 동일 조건.

## 교훈
SwiftPM executable 의 `Bundle.module` 은 `.app` 번들로 감쌀 때 신뢰할 수 없다. 리소스는 패키징 스크립트가 `Contents/Resources` 에 넣고 `Bundle.main` 으로 읽는다. 로컬 `swift run`/`.build` 실행은 빌드 경로 폴백 때문에 이 버그를 **가린다** — 반드시 빌드 트리 밖에서 테스트할 것.
