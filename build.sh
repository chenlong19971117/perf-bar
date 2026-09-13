#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"

BIN_NAME="PerfBar"
APP_NAME="Perf Bar"
APP_DIR="/Applications/${APP_NAME}.app"
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp ".build/release/${BIN_NAME}" "$APP_DIR/Contents/MacOS/${BIN_NAME}"
cp Info.plist "$APP_DIR/Contents/Info.plist"
cp AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"

xattr -cr "$APP_DIR" 2>/dev/null || true
codesign --force --sign - "$APP_DIR" >/dev/null 2>&1 || true

"$LSREG" -f "$APP_DIR" >/dev/null 2>&1 || true

echo "Installed: ${APP_DIR}"

if [[ "${1:-}" == "--run" ]]; then
    open "$APP_DIR"
fi
