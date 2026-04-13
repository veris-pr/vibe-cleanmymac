#!/bin/bash
set -e

APP_NAME="OpenCMM"
REPO="veris-pr/vibe-cleanmymac"
INSTALL_DIR="/Applications"
TMP_DIR=$(mktemp -d)

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

echo ""
echo "  🍃 $APP_NAME Installer"
echo "  ─────────────────────"
echo ""

# Determine version
VERSION="${1:-latest}"
if [ "$VERSION" = "latest" ]; then
    echo "  Fetching latest release..."
    DOWNLOAD_URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
        | grep "browser_download_url.*\.dmg" \
        | head -1 \
        | cut -d '"' -f 4)
    if [ -z "$DOWNLOAD_URL" ]; then
        echo "  ❌ No release found. Build from source instead:"
        echo "     git clone https://github.com/$REPO.git && cd vibe-cleanmymac && ./scripts/build.sh"
        exit 1
    fi
else
    DOWNLOAD_URL="https://github.com/$REPO/releases/download/v${VERSION}/${APP_NAME}.dmg"
fi

echo "  Downloading $APP_NAME..."
curl -fSL --progress-bar "$DOWNLOAD_URL" -o "$TMP_DIR/$APP_NAME.dmg"

echo "  Mounting disk image..."
MOUNT_POINT=$(hdiutil attach "$TMP_DIR/$APP_NAME.dmg" -nobrowse -quiet | tail -1 | awk '{print $NF}')

# Remove old version if present
if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
    echo "  Removing previous version..."
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi

echo "  Installing to $INSTALL_DIR..."
cp -R "$MOUNT_POINT/$APP_NAME.app" "$INSTALL_DIR/"

echo "  Cleaning up..."
hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true

# Clear quarantine attribute so Gatekeeper doesn't block unsigned app
xattr -cr "$INSTALL_DIR/$APP_NAME.app" 2>/dev/null || true

echo ""
echo "  ✅ $APP_NAME installed to $INSTALL_DIR/$APP_NAME.app"
echo ""
echo "  Run:  open -a $APP_NAME"
echo ""
