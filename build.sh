#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="DownloadShelf"
APP_DIR="$APP_NAME.app"
CONFIG="release"
INSTALL_DIR="/Applications"

case "${1:-}" in
    --install|--run) ;;
    "") ;;
    *) echo "Usage: ./build.sh [--install|--run]"; exit 1 ;;
esac

echo "Сборка ($CONFIG)..."
swift build -c "$CONFIG"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp ".build/$CONFIG/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>DownloadShelf</string>
    <key>CFBundleIdentifier</key>
    <string>tech.gaifullin.downloadshelf</string>
    <key>CFBundleName</key>
    <string>DownloadShelf</string>
    <key>CFBundleDisplayName</key>
    <string>Download Shelf</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true
echo "Готово: $(pwd)/$APP_DIR"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x "$APP_NAME" 2>/dev/null || true
    sleep 0.3
    rm -rf "$INSTALL_DIR/$APP_DIR"
    cp -R "$APP_DIR" "$INSTALL_DIR/$APP_DIR"
    open "$INSTALL_DIR/$APP_DIR"
    echo "Установлено: $INSTALL_DIR/$APP_DIR (запущено)."
    echo "Автозапуск: шестерёнка в виджете -> «Запускать при входе»."
elif [[ "${1:-}" == "--run" ]]; then
    pkill -x "$APP_NAME" 2>/dev/null || true
    sleep 0.3
    open "$APP_DIR"
    echo "Запущено. Иконка лотка в верхней панели."
fi
