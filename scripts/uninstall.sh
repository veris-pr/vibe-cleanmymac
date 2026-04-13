#!/bin/bash
set -e

APP_NAME="OpenCMM"
INSTALL_DIR="/Applications"
DATA_DIR="$HOME/.opencmm"
MANIFEST="$DATA_DIR/manifest.json"

echo ""
echo "  🍃 Uninstalling $APP_NAME..."
echo ""

# Uninstall managed tools via Homebrew
if [ -f "$MANIFEST" ] && command -v brew &>/dev/null; then
    echo "  🔧 Removing managed tools..."
    # Extract tool IDs from manifest
    TOOL_IDS=$(python3 -c "
import json, sys
try:
    data = json.load(open('$MANIFEST'))
    for tid in data.get('tools', {}):
        print(tid)
except: pass
" 2>/dev/null)

    # Map tool IDs to brew packages
    declare -A BREW_MAP=(
        [clamav]="clamav"
        [fclones]="fclones"
        [osquery]="--cask osquery"
        [mactop]="mactop"
        [mas]="mas"
        [czkawka]="czkawka"
        [gdu]="gdu"
    )

    for tid in $TOOL_IDS; do
        pkg="${BREW_MAP[$tid]}"
        if [ -n "$pkg" ]; then
            echo "    Uninstalling $tid ($pkg)..."
            brew unpin $pkg 2>/dev/null || true
            brew uninstall $pkg 2>/dev/null || true
        fi
    done
    echo "  ✅ Managed tools removed"
fi

# Remove app bundle
if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
    echo "  ✅ Removed $INSTALL_DIR/$APP_NAME.app"
else
    echo "  ℹ️  $APP_NAME.app not found in $INSTALL_DIR"
fi

# Remove data directory (manifest, etc.)
if [ -d "$DATA_DIR" ]; then
    rm -rf "$DATA_DIR"
    echo "  ✅ Removed $DATA_DIR"
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
echo "  $APP_NAME has been completely uninstalled."
echo ""
