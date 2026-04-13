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

**Five routines. One Smart Care.**

<p align="center">
  <em>Smart Care scans your Mac across all five modules in one click.</em>
</p>

## Features

### 🧹 Clean — Free up space for things you truly need
Clear out hidden system junk to make room for your apps, photos, and other important stuff. Scans system caches, user caches, browser data, logs, Xcode artifacts, and trash.

### 🛡️ Protect — Neutralize threats before they do any harm
Spot and remove malware that may hide within seemingly innocent software. Scans for known macOS malware, suspicious launch agents, and privacy risks like browser history and cookies.

### ⚡ Speed — Make your slow Mac fast again
Control memory and CPU load to keep your Mac productive. View real-time system stats, manage login items and launch agents, and free up RAM.

### 🔄 Update — Keep your apps up to date
Check for Homebrew formula and cask updates. Update individual apps or all at once to improve security and stability.

### 📦 Declutter — Take control of the clutter
Find duplicate files using hash comparison, discover large and forgotten files, and reclaim wasted storage space.

### ✨ Smart Care — One scan. Five routines.
Run all five modules in one click. Get a health score and a summary of everything that needs attention.

### 🖥️ Menu Bar
Quick access from the menu bar — jump to any module or see your Mac's status at a glance.

## Installation

### Build from Source

```bash
# Clone the repository
git clone https://github.com/your-username/open-cmm.git
cd open-cmm

# Build and create app bundle
chmod +x scripts/build.sh scripts/create-dmg.sh
./scripts/build.sh

# Run the app
open build/OpenCMM.app
```

### Create DMG Installer

```bash
./scripts/build.sh
./scripts/create-dmg.sh
# Installer at build/OpenCMM.dmg
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
- [Czkawka](https://github.com/qarmin/czkawka) for duplicate detection
- [Objective-See](https://objective-see.org) for macOS security tools

## License

[MIT License](LICENSE) — free to use, modify, and distribute.
