#!/bin/bash
set -euo pipefail

# NotchBlock DMG Build Script
# Creates a distributable .dmg from the Release build

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/NotchBlock.xcarchive"
APP_PATH="$BUILD_DIR/NotchBlock.app"
DMG_PATH="$BUILD_DIR/NotchBlock-0.1.0.dmg"
DMG_TEMP="$BUILD_DIR/NotchBlock-tmp.dmg"
STAGING="$BUILD_DIR/staging"

echo "🔨 Building NotchBlock Release..."
cd "$PROJECT_DIR"

# 1. Build Release
xcodebuild -project NotchBlock.xcodeproj \
  -scheme NotchBlock \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5

# 2. Find built app
APP_PATH=$(find "$BUILD_DIR/Build/Products/Release" -name "NotchBlock.app" -type d | head -1)
if [ -z "$APP_PATH" ]; then
  echo "❌ Could not find built .app in $BUILD_DIR/Build/Products/Release"
  exit 1
fi
echo "✅ App bundle: $APP_PATH"

# 3. Deep sign the app (fixes "no resources but signature indicates they must be present")
echo "🔐 Signing app..."
codesign --force --deep --sign - \
  --options runtime \
  --entitlements "$PROJECT_DIR/entitlements.plist" \
  --timestamp=none \
  "$APP_PATH" 2>&1

echo "   Verifying signature..."
codesign -dvvv "$APP_PATH" 2>&1 | grep -E "Signature|Info.plist|Sealed|TeamIdentifier" || true

# 5. Create DMG
echo "📦 Creating DMG..."
rm -f "$DMG_PATH" "$DMG_TEMP"
rm -rf "$STAGING"
mkdir -p "$STAGING"

cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -srcfolder "$STAGING" \
  -volname "NotchBlock" \
  -fs HFS+ \
  -fsargs "-c c=64,a=16,e=16" \
  -format UDRW \
  -size 100M \
  "$DMG_TEMP" 2>&1 | tail -1

DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_TEMP" 2>&1 | grep 'Apple_HFS' | awk '{print $1}')
if [ -z "$DEVICE" ]; then
  echo "❌ Failed to mount DMG"
  exit 1
fi

# Position icons
osascript -e "
tell application \"Finder\"
  tell disk \"NotchBlock\"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {400, 200, 860, 520}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 96
    set position of item \"NotchBlock.app\" of container window to {140, 140}
    set position of item \"Applications\" of container window to {360, 140}
    update without registering applications
    delay 1
    close
  end tell
end tell
" 2>/dev/null || true

hdiutil detach "$DEVICE" 2>&1 | tail -1
hdiutil convert "$DMG_TEMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" 2>&1 | tail -1
rm -f "$DMG_TEMP"

echo ""
echo "✅ DMG created: $DMG_PATH"
echo "   Size: $(du -h "$DMG_PATH" | awk '{print $1}')"
