#!/usr/bin/env bash
set -euo pipefail

# Renders Resources/AppIcon.svg into Resources/AppIcon.icns via rsvg-convert +
# iconutil. Run after editing the SVG: ./scripts/gen-icon.sh
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SVG="$ROOT_DIR/Resources/AppIcon.svg"
ICONSET="$(mktemp -d)/AppIcon.iconset"
OUT="$ROOT_DIR/Resources/AppIcon.icns"

if ! command -v rsvg-convert >/dev/null 2>&1; then
    echo "rsvg-convert not found (brew install librsvg)"; exit 1
fi

mkdir -p "$ICONSET"
render() { rsvg-convert -w "$1" -h "$1" "$SVG" -o "$ICONSET/$2"; }

render 16   icon_16x16.png
render 32   icon_16x16@2x.png
render 32   icon_32x32.png
render 64   icon_32x32@2x.png
render 128  icon_128x128.png
render 256  icon_128x128@2x.png
render 256  icon_256x256.png
render 512  icon_256x256@2x.png
render 512  icon_512x512.png
render 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET" -o "$OUT"
echo "==> Wrote $OUT ($(du -h "$OUT" | cut -f1))"

# Menu bar template image (monochrome) → SwiftPM resource dir (Bundle.module).
# 36px so it stays crisp when drawn at 18pt on Retina.
MENUBAR_SVG="$ROOT_DIR/Resources/MenuBarIcon.svg"
if [ -f "$MENUBAR_SVG" ]; then
    rsvg-convert -w 36 -h 36 "$MENUBAR_SVG" -o "$ROOT_DIR/Sources/Indou/Resources/MenuBarIcon.png"
    echo "==> Wrote Sources/Indou/Resources/MenuBarIcon.png"
fi
