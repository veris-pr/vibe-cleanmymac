<div align="center">
  <h1>🍃 OpenCMM</h1>
  <p><strong>Open-source Mac cleaner, protector, and optimizer.</strong></p>
  <p>
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square" alt="License"></a>
    <img src="https://img.shields.io/badge/platform-macOS%2013+-brightgreen?style=flat-square" alt="Platform">
    <img src="https://img.shields.io/badge/Swift-5.9+-orange?style=flat-square" alt="Swift">
    <img src="https://img.shields.io/badge/dependencies-0-green?style=flat-square" alt="Zero Dependencies">
  </p>
</div>

## What is OpenCMM?

OpenCMM is a free, open-source alternative to CleanMyMac. It's a native macOS app built entirely in SwiftUI — no Electron, no web views — that helps you keep your Mac clean, safe, and organized.

**Eight modules. One Overview scan. Zero Swift package dependencies. Powered by the best open-source CLI tools.**

## Features

### 🧹 Sweep — Deep cleaning across 12 categories
Scans and removes system caches, user caches, browser data, app-specific caches (23 apps), developer tool caches (23 tools), system & user logs, crash reports, Xcode artifacts (simulators, derived data, device logs, build products, doc cache), mail downloads, old macOS installers, and trash. Per-item selection with size display and confirmation dialogs. Safety guards prevent removing active macOS installers or recent mail downloads.

### 🛡️ Security — Detect threats and audit your system
Deep malware scanning powered by **ClamAV** (millions of signatures). System auditing via **osquery** — launch items, listening ports, browser extensions, firewall and SIP status. Falls back to pattern-based detection when tools aren't installed.

### ⚡ Boost — Monitor, optimize, and tune your Mac
Live Apple Silicon performance monitoring via **macmon** (CPU/GPU usage, power, thermals). System health scoring via **Mole**. 19 native optimization tasks including: rebuild launch services, vacuum app databases, clean broken launch agents, fix preferences, clear quarantine history, flush DNS, repair disk permissions, periodic maintenance, Spotlight optimization, notification/CoreDuet database cleanup, font cache rebuild, and more. Falls back to native optimizations when Mole isn't installed. Startup item management (Launch Agents/Daemons).

### 🔄 Updates — Keep your apps current
Homebrew formula and cask updates plus **Mac App Store** updates via **mas**. Update individual apps or all at once.

### 📦 Uninstaller — Completely remove apps and packages
Discovers all installed applications and Homebrew packages. Apps: scans 9 leftover locations (App Support, Caches, Preferences, Logs, Containers, Crash Reports, Saved State, Launch Items) and removes everything cleanly. Brew packages: full detail view with navigable dependency tree — see what each package depends on and what depends on it, with clickable navigation into any dependency.

### 🔍 Duplicates — Find and remove clutter
Fast duplicate detection via **fclones**. Similar images, videos, and music via **czkawka**. Large file finder. Temp file cleanup. Interactive "keep" selection.

### 🗺️ Disk Map — See what's taking up space
Visual disk usage tree with native FileManager analysis. Expandable directories showing size, percentage, and bar visualization. Optional **gdu** integration for faster scanning.

### ✨ Overview — One scan, four modules
Run Sweep, Security, Updates, and Duplicates in parallel with one click. Get a health score and tappable summary cards.

### 🖥️ Menu Bar
Quick access from the menu bar — see last scan results, run a quick scan, or open the app.

## Tool Integrations

All CLI tools are **optional**. Modules work without them (with graceful fallbacks) and offer one-click Homebrew installation from within the app. Each module shows dependency status with version info.

| Tool | Module | Purpose |
|------|--------|---------|
| [ClamAV](https://github.com/Cisco-Talos/clamav) | Security | Industry-standard antivirus engine |
| [osquery](https://github.com/osquery/osquery) | Security | SQL-powered system auditing |
| [mas](https://github.com/mas-cli/mas) | Updates | Mac App Store CLI |
| [fclones](https://github.com/pkolaczk/fclones) | Duplicates | High-performance duplicate finder |
| [czkawka](https://github.com/qarmin/czkawka) | Duplicates | Similar images/videos/music finder |
| [gdu](https://github.com/dundee/gdu) | Disk Map | Fast disk usage analyzer (binary: `gdu-go`) |
| [macmon](https://github.com/vladkens/macmon) | Boost | Sudoless Apple Silicon performance monitor |
| [Mole](https://github.com/tw93/mole) | Boost | System optimizer — clean, optimize, and analyze |

## Installation

### Download

Go to the [**Releases**](https://github.com/veris-pr/vibe-cleanmymac/releases) page, download `OpenCMM.dmg`, open it, and drag OpenCMM to your Applications folder.

> **First launch:** Right-click the app → Open (required once for unsigned apps).

### Install Script

```bash
curl -fsSL https://raw.githubusercontent.com/veris-pr/vibe-cleanmymac/main/scripts/install.sh | bash
```

### Build from Source

```bash
git clone https://github.com/veris-pr/vibe-cleanmymac.git
cd vibe-cleanmymac
make app                  # builds release + creates signed .app bundle
open build/OpenCMM.app
```

### Create DMG

```bash
make dmg    # → build/OpenCMM.dmg
```

### Uninstall

```bash
# From the app: Settings → Uninstall All removes managed tools + app data
# Full removal:
curl -fsSL https://raw.githubusercontent.com/veris-pr/vibe-cleanmymac/main/scripts/uninstall.sh | bash
```

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  OpenCMMApp (@main)                                 │
│    └─ AppState (@MainActor ObservableObject)        │
│         ├─ ScanStore ← shared state (all modules)   │
│         ├─ 8 ViewModels (all @MainActor)            │
│         └─ selectedModule → NavigationSplitView     │
└─────────────────────────────────────────────────────┘

View → ViewModel (@MainActor) → Service (actor) → ShellExecutor
                 ↕
           ScanStore (central read/write)
```

**Key design decisions:**
- **MVVM** with a shared `ScanStore` as central state
- **All ViewModels are `@MainActor`** — `@Published` updates always on main thread
- **All Services are Swift `actor` types** — concurrency-safe, heavy work off main thread
- **ShellExecutor** is the single point for all shell commands — injects Homebrew PATH, prevents pipe deadlocks
- **Zero Swift package dependencies** — only system frameworks (SwiftUI, Foundation, AppKit)
- **Ad-hoc code signed** — prevents macOS TCC permission prompts without needing an Apple Developer account
- **No sudo, no osascript** — the app never escalates privileges or sends Apple Events

## Project Structure

```
OpenCMM/
├── App/           # OpenCMMApp, AppState, AppDelegate
├── Views/         # SwiftUI views (one per module)
├── ViewModels/    # @MainActor business logic (one per module)
├── Models/        # Data structs (ScanResult, ThreatItem, InstalledApp, etc.)
├── Services/      # actor services (CleaningService, DependencyManager, etc.)
├── Components/    # Reusable UI (Theme, ProgressRing, ModuleCard, DependencyBanner)
├── Utilities/     # ShellExecutor, FileUtils, Formatters, AppConstants
└── Resources/     # AppIcon, entitlements, asset catalog
scripts/
├── build.sh       # Creates .app bundle + ad-hoc codesigns
├── create-dmg.sh  # Creates distributable DMG
├── release.sh     # Tags + GitHub Release via `gh`
├── install.sh     # curl-pipe installer from GitHub Releases
└── uninstall.sh   # Full removal (app + tools + data)
```

## Requirements

- macOS 13 (Ventura) or later
- Swift 5.9+ / Xcode 15+ (for building from source)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

For AI agents working on this codebase, see [agents.md](agents.md) for architecture details, principles, and common mistakes to avoid.

## Acknowledgments

Inspired by [CleanMyMac](https://cleanmymac.com) by MacPaw and [Mole](https://github.com/tw93/mole) by Tw93.

## License

[MIT License](LICENSE) — free to use, modify, and distribute.
