<div align="center">
  <h1>🍃 OpenCMM</h1>
  <p><strong>Open-source Mac cleaner, protector, and optimizer.</strong></p>
  <p>
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square" alt="License"></a>
    <img src="https://img.shields.io/badge/platform-macOS%2013+-brightgreen?style=flat-square" alt="Platform">
    <img src="https://img.shields.io/badge/Swift-5.9+-orange?style=flat-square" alt="Swift">
  </p>
</div>

## What is OpenCMM?

OpenCMM is a free, open-source alternative to CleanMyMac. It's a native macOS app that helps you keep your Mac clean, safe, and fast — with a beautiful SwiftUI interface and a menu bar icon for quick access.

**Six modules. One Smart Care. Powered by the best open-source tools.**

<p align="center">
  <em>Smart Care scans your Mac across all modules in one click.</em>
</p>

## Features

### 🧹 Clean — Free up space for things you truly need
Clear out hidden system junk to make room for your apps, photos, and other important stuff. Scans system caches, user caches, browser data, logs, Xcode artifacts, and trash. Per-item selection with confirmation dialogs.

### 🛡️ Protect — Neutralize threats before they do any harm
Deep malware scanning powered by **ClamAV** (millions of signatures). System auditing via **osquery** — launch items, listening ports, browser extensions, firewall and SIP status. Falls back to pattern-based detection when tools aren't installed.

### ⚡ Speed — Make your slow Mac fast again
Real-time CPU, memory, and disk gauges with color-coded thresholds. Apple Silicon metrics via **mactop** (GPU, temperatures, power consumption, per-core stats). Auto-refresh mode, login item management.

### 🔄 Update — Keep your apps up to date
Homebrew formula and cask updates plus **Mac App Store** updates via **mas**. Update individual apps or all at once.

### 📦 Declutter — Take control of the clutter
Fast duplicate detection via **fclones**. Similar images, videos, and music via **czkawka**. Large file finder with sort options. Temp file cleanup. Interactive "keep" selection.

### 🔍 Space Lens — See what's taking up space
Visual disk usage map powered by **gdu**. Expandable directory tree showing size, percentage, and bar visualization. Drill into any folder to find space hogs.

### ✨ Smart Care — One scan. Six modules.
Run all modules in parallel with one click. Get a health score and tappable summary cards to jump into any module.

### 🖥️ Menu Bar
Quick access from the menu bar — jump to any module or see your Mac's status at a glance.

## Tool Integrations

OpenCMM integrates the best open-source CLI tools for each job. All tools are **optional** — modules gracefully degrade without them, and offer one-click Homebrew installation from within the app.

| Tool | Stars | Module | Purpose |
|------|-------|--------|---------|
| [ClamAV](https://github.com/Cisco-Talos/clamav) | 4K+ | Protect | Industry-standard antivirus engine |
| [osquery](https://github.com/osquery/osquery) | 23K+ | Protect | SQL-powered system auditing |
| [mactop](https://github.com/metaspartan/mactop) | 1K+ | Speed | Apple Silicon performance monitor |
| [mas](https://github.com/mas-cli/mas) | 12K+ | Update | Mac App Store CLI |
| [fclones](https://github.com/pkolaczk/fclones) | 2.7K+ | Declutter | High-performance duplicate finder |
| [czkawka](https://github.com/qarmin/czkawka) | 30K+ | Declutter | Similar images/videos/music finder |
| [gdu](https://github.com/dundee/gdu) | 5.5K+ | Space Lens | Fast disk usage analyzer |

## Installation

### Download (Easiest)

Go to the [**Releases**](https://github.com/veris-pr/vibe-cleanmymac/releases) page, download `OpenCMM.dmg`, open it, and drag OpenCMM to your Applications folder.

> **First launch:** Right-click the app → Open (required once to bypass macOS Gatekeeper for unsigned apps).

### Install Script

```bash
curl -fsSL https://raw.githubusercontent.com/veris-pr/vibe-cleanmymac/main/scripts/install.sh | bash
```

### Build from Source

```bash
git clone https://github.com/veris-pr/vibe-cleanmymac.git
cd vibe-cleanmymac
./scripts/build.sh
open build/OpenCMM.app
```

### Create DMG Installer

```bash
./scripts/build.sh
./scripts/create-dmg.sh
# → build/OpenCMM.dmg
```

### Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/veris-pr/vibe-cleanmymac/main/scripts/uninstall.sh | bash
```

### Open in Xcode

```bash
open Package.swift
```

## Requirements

- macOS 13 (Ventura) or later
- Swift 5.9+ / Xcode 15+

## Tech Stack

- **UI**: SwiftUI (native macOS)
- **Language**: Swift
- **Architecture**: MVVM (Model-View-ViewModel)
- **Package Manager**: Swift Package Manager
- **Distribution**: App bundle + DMG

## Project Structure

```
OpenCMM/
├── App/           # App entry point, delegate, state management
├── Views/         # SwiftUI views for each module
├── ViewModels/    # Business logic and state for views
├── Models/        # Data models (ScanResult, ThreatItem, etc.)
├── Services/      # Core services (cleaning, scanning, performance, etc.)
├── Components/    # Reusable UI components (ProgressRing, ModuleCard, etc.)
├── Utilities/     # Helpers (ShellExecutor, FileUtils, Formatters)
└── Resources/     # Assets and entitlements
```

## Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Acknowledgments

Inspired by:
- [CleanMyMac](https://cleanmymac.com) by MacPaw
- [Mole](https://github.com/tw93/mole) by Tw93

Powered by:
- [ClamAV](https://github.com/Cisco-Talos/clamav) — Antivirus engine
- [osquery](https://github.com/osquery/osquery) — System auditing
- [mactop](https://github.com/metaspartan/mactop) — Apple Silicon monitor
- [mas](https://github.com/mas-cli/mas) — Mac App Store CLI
- [fclones](https://github.com/pkolaczk/fclones) — Duplicate finder
- [czkawka](https://github.com/qarmin/czkawka) — Similar file finder
- [gdu](https://github.com/dundee/gdu) — Disk usage analyzer

## License

[MIT License](LICENSE) — free to use, modify, and distribute.
