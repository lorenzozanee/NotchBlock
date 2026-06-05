#!/bin/bash
set -euo pipefail

# NotchBlock DMG Build Script
# Creates a distributable .dmg with custom background and one-click
# quarantine fix helper. Designed for non-notarized distribution.

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_PATH="$BUILD_DIR/NotchBlock.app"
VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "0.1.0")
DMG_PATH="$BUILD_DIR/NotchBlock-${VERSION}.dmg"
DMG_TEMP="$BUILD_DIR/NotchBlock-tmp.dmg"
STAGING="$BUILD_DIR/staging"

echo "🔨 Building NotchBlock Release..."
cd "$PROJECT_DIR"

# ── 1. Build Release ────────────────────────────────────────
xcodebuild -project NotchBlock.xcodeproj \
  -scheme NotchBlock \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5

# ── 2. Find built app ───────────────────────────────────────
APP_PATH=$(find "$BUILD_DIR/Build/Products/Release" -name "NotchBlock.app" -type d | head -1)
if [ -z "$APP_PATH" ]; then
  echo "❌ Could not find built .app in $BUILD_DIR/Build/Products/Release"
  exit 1
fi
echo "✅ App bundle: $APP_PATH"

# ── 3. Deep sign ────────────────────────────────────────────
echo "🔐 Signing app..."
codesign --force --deep --sign - \
  --options runtime \
  --entitlements "$PROJECT_DIR/entitlements.plist" \
  --timestamp=none \
  "$APP_PATH" 2>&1

echo "   Verifying signature..."
codesign -dvvv "$APP_PATH" 2>&1 | grep -E "Signature|Info.plist|Sealed|TeamIdentifier" || true

# ── 4. Generate DMG background ──────────────────────────────
echo "🎨 Generating DMG background..."
mkdir -p "$BUILD_DIR"
python3 "$PROJECT_DIR/scripts/generate_dmg_background.py"
BACKGROUND_SRC="$BUILD_DIR/dmg_background.png"
if [ ! -f "$BACKGROUND_SRC" ]; then
  echo "❌ Background image generation failed"
  exit 1
fi

# ── 5. Prepare staging ──────────────────────────────────────
echo "📦 Preparing DMG staging..."
rm -f "$DMG_PATH" "$DMG_TEMP"
rm -rf "$STAGING"
mkdir -p "$STAGING"

cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# Copy and set executable permission on the quarantine fix helper
cp "$PROJECT_DIR/scripts/FixQuarantine.command" "$STAGING/FixQuarantine.command"
chmod +x "$STAGING/FixQuarantine.command"

# Copy background into staging (hidden via dot-prefix)
cp "$BACKGROUND_SRC" "$STAGING/.background.png"

echo "   Staging contents:"
ls -la "$STAGING"

# ── 6. Create writable DMG ──────────────────────────────────
echo "📀 Creating DMG..."
hdiutil create -srcfolder "$STAGING" \
  -volname "NotchBlock" \
  -fs HFS+ \
  -fsargs "-c c=64,a=16,e=16" \
  -format UDRW \
  -size 120M \
  "$DMG_TEMP" 2>&1 | tail -1

DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_TEMP" 2>&1 | grep 'Apple_HFS' | awk '{print $1}')
if [ -z "$DEVICE" ]; then
  echo "❌ Failed to mount DMG"
  exit 1
fi

# ── 7. Apply window layout ──────────────────────────────────
echo "🎯 Applying DMG window layout..."
osascript -e "
tell application \"Finder\"
  tell disk \"NotchBlock\"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {400, 200, 1000, 620}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 96
    set background picture of theViewOptions to file \".background:.background.png\"

    -- App icon (left) → Applications alias (right)
    set position of item \"NotchBlock.app\" of container window to {140, 180}
    set position of item \"Applications\" of container window to {460, 180}

    -- Quarantine fix helper below the app
    set position of item \"FixQuarantine.command\" of container window to {140, 330}

    update without registering applications
    delay 1
    close
  end tell
end tell
" 2>/dev/null || true

echo "   Layout applied."

# ── 8. Finalize ─────────────────────────────────────────────
hdiutil detach "$DEVICE" 2>&1 | tail -1
hdiutil convert "$DMG_TEMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" 2>&1 | tail -1
rm -f "$DMG_TEMP"

echo ""
echo "✅ DMG created: $DMG_PATH"
echo "   Size: $(du -h "$DMG_PATH" | awk '{print $1}')"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 DMG 内容"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "   NotchBlock.app            — 拖入 Applications"
echo "   FixQuarantine.command     — 双击移除隔离 + 启动"
echo "   .background.png           — DMG 背景 (隐藏)"
echo ""
echo "   用户三步安装流程:"
echo "   1. 拖入 NotchBlock.app → Applications"
echo "   2. 双击 FixQuarantine.command (移除隔离标记)"
echo "   3. 从 Applications 打开 NotchBlock"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
