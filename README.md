# Indou

A fast, modern macOS window switcher — a more capable, free alternative to AltTab.
Menu-bar only, native Swift, macOS 26 (Tahoe).

## Features

- **Custom global shortcuts** — record any modifier + key (e.g. ⌥Tab, ⌘Tab); multiple trigger profiles (all windows / current app / …).
- **All real windows, accurately** — ScreenCaptureKit + Accessibility union, across Spaces and displays (incl. minimized / fullscreen). Background-only apps are excluded.
- **Grid navigation** — Tab / Shift-Tab to cycle, arrow or vim keys to move the 2D grid, release the modifier to focus. Auto-scrolls to the selection.
- **In-switcher actions** — close (W or the red ×), minimize (M), fullscreen (F), quit app (Q), Esc to cancel.
- **Multi-select** — drag-marquee or ⌘/⇧-click, then right-click to close / minimize / quit in bulk.
- **Customizable display** — thumbnails / icons / titles, sizes (incl. manual height), title masking, status icons, per-app blacklist.
- **Search** — 6-tier fuzzy matching plus Korean initial-consonant (초성) search.
- **Smooth, toggleable animations** — 120 Hz transitions, respects Reduce Motion.
- **Click-outside to dismiss**, sleep/wake recovery, optional suppression of the native ⌘Tab.
- **Localized** — English / 한국어 / 日本語 (String Catalog).
- **Settings** — a clean sidebar + cards menu-bar app.

## Build

Requires macOS 26 and Xcode 26 (Swift 6.2+).

```bash
swift build            # build the SPM package
swift test             # IndouKit unit tests
./scripts/build-app.sh release   # produce a signed .app bundle in .build/
open ".build/Indou.app"
```

For stable TCC permissions across rebuilds, run `./scripts/setup-dev-identity.sh` once.

## Permissions

- **Accessibility** — required (global key tap + window control).
- **Screen Recording** — optional, for live thumbnails (falls back to app icons).

## Notes

Indou uses a few private CGS/SkyLight APIs (precise window focus, Spaces, native ⌘Tab toggle),
isolated in the `PrivateWindowServer` module with graceful degradation. This means it is
distributed directly (Developer ID / notarization), not via the Mac App Store. See
`docs/acknowledge/private-api.md`.

## Branches

- `dev` — development
- `prod` — release / distribution
