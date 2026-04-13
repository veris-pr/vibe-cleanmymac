#!/bin/bash
set -e

APP_NAME="OpenCMM"
APP_BUNDLE="build/${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
DMG_DIR="build/dmg"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "❌ App bundle not found. Run scripts/build.sh first."
    exit 1
fi

echo "📀 Creating DMG..."

rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"
cp -R "$APP_BUNDLE" "$DMG_DIR/"

# Create a symlink to /Applications for drag-and-drop install
ln -s /Applications "$DMG_DIR/Applications"

# Create DMG
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDZO \
    "build/$DMG_NAME"

rm -rf "$DMG_DIR"

echo "✅ DMG created at: build/$DMG_NAME"
