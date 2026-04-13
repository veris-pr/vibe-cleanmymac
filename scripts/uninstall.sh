#!/bin/bash
set -e

APP_NAME="OpenCMM"
INSTALL_DIR="/Applications"

echo ""
echo "  🍃 Uninstalling $APP_NAME..."
echo ""

if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
    echo "  ✅ Removed $INSTALL_DIR/$APP_NAME.app"
else
    echo "  ℹ️  $APP_NAME.app not found in $INSTALL_DIR"
fi

# Remove preferences
PLIST="$HOME/Library/Preferences/com.opencmm.app.plist"
if [ -f "$PLIST" ]; then
    rm -f "$PLIST"
    echo "  ✅ Removed preferences"
fi

# Remove caches
CACHE_DIR="$HOME/Library/Caches/com.opencmm.app"
if [ -d "$CACHE_DIR" ]; then
    rm -rf "$CACHE_DIR"
    echo "  ✅ Removed caches"
fi

echo ""
echo "  $APP_NAME has been uninstalled."
echo ""
