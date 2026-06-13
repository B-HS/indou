#!/usr/bin/env bash
set -euo pipefail

# Reset Indou's TCC grants (Accessibility + Screen Recording) and relaunch.
# Useful after unexpected permission loss following an ad-hoc rebuild.

BUNDLE_ID="com.hyunseokbyun.indou"

echo "==> Stopping Indou"
pkill -x Indou 2>/dev/null || true
sleep 1

echo "==> Resetting Accessibility + Screen Recording permissions"
tccutil reset Accessibility "$BUNDLE_ID" || true
tccutil reset ScreenCapture "$BUNDLE_ID" || true

echo "==> Relaunching"
APP_PATH="$(cd "$(dirname "$0")/.." && pwd)/.build/Indou.app"
if [ -d "$APP_PATH" ]; then
    open "$APP_PATH"
    echo "✓ Relaunched. Indou will prompt for permissions again."
else
    echo "App not built yet. Run ./scripts/build-app.sh release first."
fi
