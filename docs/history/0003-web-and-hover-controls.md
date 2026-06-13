# 0003 — 랜딩 페이지(Next.js) + 셀 hover 컨트롤

2026-06-13

## 웹 랜딩 페이지 (`web/`)
- 기존 plain HTML(인디고 글래스) 폐기 → **Next.js 16 정적 export**(`output:'export'`, `basePath:'/indou'`) + **BBlog 모노크롬 디자인 시스템** 재구성. 로컬 스택(Tailwind v4, shadcn new-york, React Compiler, Bun) 사용.
- BBlog `app/globals.css`(토큰·prose·custom scroll), `VirtualScroll`, `GoToTop` 그대로 이식. next-themes 테마 토글.
- **6개 기능 그리드 제거** → 정숙한 기능 목록(`border-b` 행). 키캡 단축키 섹션, 다운로드 CTA, 푸터.
- **Motion**(`motion@12`): 섹션/히어로 스크롤 리빌(`Reveal`), 스위처 프리뷰 셀렉션 순환(Finder→Music)을 `layoutId` 공유요소로 부드럽게 이동.
- 함정: `next/image`가 `output:export`에서 정적 public 에셋에 basePath를 안 붙임 → `lib/constants.asset()`로 `/indou` 프리픽스 + plain `<img>`. 기록 가치.
- 배포: `.github/workflows/pages.yml` (Bun install → `next build` → `web/out` 업로드 → deploy-pages). Pages 소스 = GitHub Actions(API로 활성화). **라이브: https://b-hs.github.io/indou/**.
- README 심플화(중앙 정렬 favicon `Resources/icon.png` + 간단 기능 목록).

## 앱: 셀 hover 트래픽라이트 컨트롤 (요구 8 개선)
- 기존 항상 보이던 최소화/풀스크린 상태 뱃지 제거.
- hover 시 좌상단에 상태별 선택 노출: **최소화된 창 → ×(닫기)만**, **일반 창 → ×(닫기)+−(최소화)+⤢(풀스크린 토글) 3개**.
- `SwitcherViewModel.onMinimizeWindow`/`onFullscreenWindow` + 컨트롤러 `windowAction` 배선(`WindowActions.setMinimized`/`toggleFullscreen` + 갱신).

## 검증
- `swift build` OK, `.app` 서명/실행 OK(pid 확인). 웹 `bun run build` 정적 export OK, Pages 라이브 200 확인.
