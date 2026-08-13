#!/bin/bash
set -e

VERSION=$(cat ./VERSION 2>/dev/null || echo "1.0.0")

echo "=== Building Tactus v$VERSION (Universal Binary: arm64 + x86_64) ==="
swift build -c release --triple arm64-apple-macosx
swift build -c release --triple x86_64-apple-macosx

APP_NAME="Tactus.app"
BUNDLE_PATH="./build/$APP_NAME"

rm -rf "$BUNDLE_PATH"
mkdir -p "$BUNDLE_PATH/Contents/MacOS"
mkdir -p "$BUNDLE_PATH/Contents/Resources"

lipo -create .build/arm64-apple-macosx/release/Tactus .build/x86_64-apple-macosx/release/Tactus -output "$BUNDLE_PATH/Contents/MacOS/Tactus"

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
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

chmod +x "$BUNDLE_PATH/Contents/MacOS/Tactus"

echo "=== Packaging Tactus.dmg ==="
DMG_DIR="./build/dmg_tmp"
rm -rf "$DMG_DIR" "./build/Tactus.dmg"
mkdir -p "$DMG_DIR"
cp -R "$BUNDLE_PATH" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"
hdiutil create -volname "Tactus" -srcfolder "$DMG_DIR" -ov -format UDZO "./build/Tactus.dmg"
rm -rf "$DMG_DIR"

echo "=== Build Complete! → ./build/Tactus.dmg ==="
