#!/bin/bash
# Compila "Screenshot Uploader.app" (versione nativa). Serve solo Xcode Command Line Tools.
#   ./build.sh               per questo Mac
#   ./build.sh --universal   Apple Silicon + Intel, e crea ScreenshotUploader.zip
set -e
cd "$(dirname "$0")"
APP="Screenshot Uploader.app"
VERSION=$(cat ../VERSION)
rm -rf "$APP" build; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build
BIN="$APP/Contents/MacOS/ScreenshotUploader"
compile() { xcrun swiftc -O -swift-version 5 -module-name ScreenshotUploader -target $1-apple-macos14.0 Sources/*.swift -o build/bin-$1; }
if [ "$1" = "--universal" ]; then
  compile arm64; compile x86_64
  lipo -create build/bin-arm64 build/bin-x86_64 -output "$BIN"
else
  compile "$(uname -m)"; cp "build/bin-$(uname -m)" "$BIN"
fi
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.mdrzn.screenshot-uploader</string>
  <key>CFBundleName</key><string>Screenshot Uploader</string>
  <key>CFBundleExecutable</key><string>ScreenshotUploader</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHumanReadableCopyright</key><string>Made by mdrzn</string>
</dict></plist>
PLIST
codesign --force -s - "$APP"
rm -rf build
if [ "$1" = "--universal" ]; then
  rm -f ScreenshotUploader.zip; ditto -c -k --keepParent "$APP" ScreenshotUploader.zip
  echo "ok: $PWD/ScreenshotUploader.zip ($(lipo -archs "$BIN"))"
else
  echo "ok: $PWD/$APP"
fi
