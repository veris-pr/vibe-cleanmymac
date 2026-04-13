#!/bin/bash
set -e

echo "🔨 Building OpenCMM..."
swift build -c release

BUILD_DIR=".build/release"
APP_NAME="OpenCMM"

echo "📦 Creating app bundle..."
APP_BUNDLE="build/${APP_NAME}.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Copy app icon
if [ -f "OpenCMM/Resources/AppIcon.icns" ]; then
    cp "OpenCMM/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
    echo "🎨 App icon copied"
fi

# Copy entitlements
if [ -f "OpenCMM/Resources/OpenCMM.entitlements" ]; then
    cp "OpenCMM/Resources/OpenCMM.entitlements" "$APP_BUNDLE/Contents/Resources/"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>OpenCMM</string>
    <key>CFBundleDisplayName</key>
    <string>OpenCMM</string>
    <key>CFBundleIdentifier</key>
    <string>com.opencmm.app</string>
    <key>CFBundleVersion</key>
    <string>0.2.0</string>
    <key>CFBundleShortVersionString</key>
    <string>0.2.0</string>
    <key>CFBundleExecutable</key>
    <string>OpenCMM</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
</dict>
</plist>
PLIST

echo "✅ App bundle created at: $APP_BUNDLE"

# Ad-hoc code sign — prevents macOS TCC prompts (Screen Recording, etc.)
# No Apple Developer account needed. Uses local signature so macOS can
# consistently track permission decisions.
echo "🔏 Code signing (ad-hoc)..."
codesign --force --deep --sign - \
    --entitlements "OpenCMM/Resources/OpenCMM.entitlements" \
    "$APP_BUNDLE"
echo "✅ Signed: $APP_BUNDLE"
echo "   Run: open $APP_BUNDLE"
