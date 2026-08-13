#!/bin/bash
set -e

echo "=== Building Tactus ==="
swift build -c release

APP_NAME="Tactus.app"
BUNDLE_PATH="./build/$APP_NAME"
EXECUTABLE_PATH=".build/release/TapticScroll"

rm -rf "$BUNDLE_PATH"
mkdir -p "$BUNDLE_PATH/Contents/MacOS"
mkdir -p "$BUNDLE_PATH/Contents/Resources"

cp "$EXECUTABLE_PATH" "$BUNDLE_PATH/Contents/MacOS/Tactus"
if [ -f "./AppIcon.icns" ]; then
    cp "./AppIcon.icns" "$BUNDLE_PATH/Contents/Resources/AppIcon.icns"
fi
if [ -f "./AppIcon.iconset/icon-iOS-Dark-1024@1x.png" ]; then
    cp "./AppIcon.iconset/icon-iOS-Dark-1024@1x.png" "$BUNDLE_PATH/Contents/Resources/AppIconOriginal.png"
fi

cat <<EOF > "$BUNDLE_PATH/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Tactus</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.tactus.mac</string>
    <key>CFBundleName</key>
    <string>Tactus</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

chmod +x "$BUNDLE_PATH/Contents/MacOS/Tactus"

echo "=== Build Complete! → $BUNDLE_PATH ==="
