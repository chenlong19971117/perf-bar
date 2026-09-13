#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"

BIN_NAME="PerfBar"
APP_NAME="Perf Bar"
APP_DIR="build/${APP_NAME}.app"

swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp ".build/release/${BIN_NAME}" "$APP_DIR/Contents/MacOS/${BIN_NAME}"
cp Info.plist "$APP_DIR/Contents/Info.plist"

codesign --force --sign - "$APP_DIR" >/dev/null 2>&1 || true

echo "Built: $(pwd)/${APP_DIR}"

if [[ "${1:-}" == "--run" ]]; then
    open "$APP_DIR"
fi
