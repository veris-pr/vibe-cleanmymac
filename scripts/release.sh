#!/bin/bash
set -e

# Create a GitHub Release with the DMG attached
# Requires: gh CLI authenticated

VERSION="${1:?Usage: ./scripts/release.sh <version>  (e.g. 0.1.0)}"
TAG="v$VERSION"
REPO="veris-pr/vibe-cleanmymac"
DMG_PATH="build/OpenCMM.dmg"

echo ""
echo "  🍃 OpenCMM Release: $TAG"
echo "  ───────────────────────"
echo ""

# Build release binary and app bundle
echo "  [1/4] Building release..."
./scripts/build.sh

# Create DMG
echo "  [2/4] Creating DMG..."
./scripts/create-dmg.sh

if [ ! -f "$DMG_PATH" ]; then
    echo "  ❌ DMG not found at $DMG_PATH"
    exit 1
fi

DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1 | xargs)
echo "  DMG size: $DMG_SIZE"

# Create git tag
echo "  [3/4] Creating tag $TAG..."
git tag -a "$TAG" -m "Release $TAG"
git push origin "$TAG"

# Create GitHub release with DMG attached
echo "  [4/4] Creating GitHub release..."
gh release create "$TAG" \
    "$DMG_PATH#OpenCMM.dmg" \
    --repo "$REPO" \
    --title "OpenCMM $TAG" \
    --notes "## OpenCMM $TAG

### Installation

**Option A — Download DMG**
1. Download \`OpenCMM.dmg\` below
2. Open the DMG and drag OpenCMM to Applications
3. Right-click the app → Open (first launch only, to bypass Gatekeeper)

**Option B — Install script**
\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/$REPO/main/scripts/install.sh | bash
\`\`\`

**Option C — Build from source**
\`\`\`bash
git clone https://github.com/$REPO.git
cd vibe-cleanmymac
./scripts/build.sh
open build/OpenCMM.app
\`\`\`

### What's included
- **Smart Care** — One-click scan across all 5 modules
- **Clean** — System caches, browser data, logs, Xcode artifacts, trash
- **Protect** — Malware detection, suspicious launch agents, privacy risks
- **Speed** — CPU/memory/disk monitoring, startup item management, RAM purge
- **Update** — Homebrew formula and cask updates
- **Declutter** — Duplicate file finder, large file detection
- **Menu bar** — Quick access from the status bar

Requires macOS 13 (Ventura) or later.
"

echo ""
echo "  ✅ Release $TAG created!"
echo "  https://github.com/$REPO/releases/tag/$TAG"
echo ""
