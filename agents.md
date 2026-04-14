# agents.md — OpenCMM Developer & AI Agent Guide

This document captures the architecture, data flow, development principles, and hard-won lessons from building OpenCMM. It exists for human contributors and AI agents alike — read it before making changes.

## Architecture

### Pattern: MVVM + Shared State Store

```
OpenCMMApp (@main)
  └─ AppState (@MainActor ObservableObject)
       ├─ ScanStore       ← central shared state, injected as @EnvironmentObject
       ├─ 8 ViewModels    ← all @MainActor, all persist across navigation
       └─ selectedModule  ← drives NavigationSplitView content
```

### Layer Responsibilities

| Layer | Type | Thread Safety | Role |
|-------|------|---------------|------|
| **Views** | `struct: View` | Main thread (SwiftUI) | Pure UI. Receive VM as init param. No business logic. |
| **ViewModels** | `@MainActor class: ObservableObject` | Main actor | Business logic, `@Published` state, calls services, reads/writes ScanStore. |
| **Services** | `actor` | Actor-isolated | Heavy work — shell commands, file scanning, parsing. Thread-safe by design. |
| **Models** | `struct: Identifiable` | Value type (Sendable) | Plain data. No persistence, no Codable (yet). |
| **Utilities** | `enum` (no instances) | Static methods | `ShellExecutor`, `FileUtils`, `Formatters`, `AppConstants`. Stateless. |
| **Components** | `struct: View` | Main thread | Reusable UI pieces — `Theme`, `ProgressRing`, `ModuleCard`, `DependencyBanner`. |

### Data Flow

```
User taps "Scan"
  → View calls viewModel.scan()
    → VM sets @Published isScanning = true
    → VM calls await service.scan()
      → Service runs ShellExecutor.shell(...) or FileManager APIs
      → Service returns results across actor boundary
    → VM writes results to ScanStore
    → VM sets @Published isScanning = false
  → View re-renders from @Published changes
```

### ScanStore — Central State

`ScanStore` (`@MainActor class: ObservableObject`) is the **single source of truth** for scan results.

**What it holds:**
- `moduleSummaries: [Module: ModuleScanSummary]` — summary cards for Overview
- `cleanResults`, `threats`, `auditResult`, `updates`, `duplicateGroups`, `largeFiles`, `similarImages`, `tempFiles` — detailed results per module
- `healthScore`, `lastScanDate`, `lastScanMode`

**Write paths:**
- `updateSummary(_:)` — individual module VM writes after its scan
- `updateAll(_:healthScore:scanMode:)` — SmartCareVM writes after concurrent full scan
- `invalidate(_:)` — VM calls after cleanup to clear stale results
- Direct property writes (e.g., `store.cleanResults = results`)

**Read paths:**
- Each VM's `loadFromStore()` — loads pre-existing results when user navigates to a module
- Overview reads `orderedSummaries`, `totalIssues`, `healthScore`
- MenuBarView reads summary info

**Wiring:** `AppState.init()` assigns `scanStore` to every VM that needs it.

### SmartCare Orchestration

`SmartCareViewModel.scan()` runs 4 modules concurrently via `withTaskGroup`:
1. Clean (CleaningService)
2. Protect (MalwareScanService)
3. Update (UpdateService)
4. Declutter (DuplicateFinderService)

Each returns a `ScanOutput` enum. Progress updates as each completes. Results are batched into ScanStore via `updateAll(...)`. Supports cancellation.

## Module Map

| Module | Sidebar Name | VM | Service(s) | External Tool(s) |
|--------|-------------|-----|-----------|-------------------|
| `.smartCare` | Overview | SmartCareViewModel | (all 4 below) | — |
| `.clean` | Sweep | CleanViewModel | CleaningService | None |
| `.protect` | Security | ProtectViewModel | MalwareScanService, OsqueryService | clamav, osquery |
| `.speed` | Boost | SpeedViewModel | PerformanceService, OptimizationService, MoleService, MacMonService | mole, macmon |
| `.update` | Updates | UpdateViewModel | UpdateService, MasService | mas |
| `.uninstall` | Uninstaller | UninstallViewModel | UninstallService | None |
| `.declutter` | Duplicates | DeclutterViewModel | DuplicateFinderService, CzkawkaService | fclones, czkawka |
| `.spaceLens` | Disk Map | SpaceLensViewModel | SpaceLensService | gdu (binary: `gdu-go`) |
| `.settings` | Settings | SettingsViewModel | DependencyManager | — |

### CleaningService — 12 Scan Categories

The `scan()` method runs 12 sub-scanners:

| Method | Category | Notes |
|--------|----------|-------|
| `scanSystemCaches()` | systemCache | `/Library/Caches/` |
| `scanUserCaches()` | userCache | `~/Library/Caches/` |
| `scanBrowserCaches()` | browserCache | Safari, Chrome, Firefox, Edge, Brave, Arc, Opera, Vivaldi |
| `scanAppCaches()` | appCache | 23 app-specific paths (Spotify, Slack, Discord, Teams, etc.) |
| `scanDevCaches()` | devCache | 23 dev tool paths (npm, pip, cargo, go, gradle, cocoapods, etc.) |
| `scanSystemLogs()` | systemLogs | `/Library/Logs/`, `/var/log/` |
| `scanUserLogs()` | userLogs | `~/Library/Logs/` |
| `scanCrashReports()` | crashReports | `~/Library/Logs/DiagnosticReports/`, system crash reports |
| `scanXcodeData()` | xcodeData | DerivedData, archives, simulators (temp/logs), device logs, build products, doc cache |
| `scanMailDownloads()` | mailDownloads | Only files >30 days old |
| `scanMacOSInstallers()` | macOSInstaller | Skip if running, current version, or <14 days old |
| `scanTrash()` | trash | `~/.Trash/` |

### OptimizationService — 19 Tasks

Boost runs all 19 tasks sequentially via `optimizeNative()` (or delegates to Mole when installed):

**Non-privileged (16):**
`rebuildLaunchServices`, `refreshQuickLookCaches`, `clearQuarantineHistory`, `cleanBrokenLaunchAgents`, `fixBrokenPreferences`, `refreshDock`, `cleanOldSavedStates`, `preventNetworkDSStore`, `vacuumAppDatabases`, `rebuildFontCache`, `repairSharedFileLists`, `cleanNotificationDatabase`, `cleanCoreDuetDatabase`, `optimizeSpotlightIndex`

**Privileged (via macOS auth dialog, 5):**
`flushDNSCache`, `runPeriodicMaintenance`, `repairDiskPermissions`, `purgeMemory`, `flushNetworkStack`

### Uninstaller — Brew Package Detail View

Brew packages navigate into a full detail view (like software does) showing:
- Package header with version badge and size
- Info badges (installed on request / as dependency, leaf status, dep/dependent counts)
- Cellar install path
- Clickable dependency rows — navigate into any dependency's detail view
- Clickable dependent rows
- Uninstall action bar with dependent warning

## Dependency Management

**`DependencyManager`** is a Swift `actor` singleton that manages all 8 external CLI tools.

**Managed tools:**

| Tool ID | Name | Brew Package | Binary Name | Cask? |
|---------|------|-------------|-------------|-------|
| `clamav` | ClamAV | `clamav` | `clamscan` | No |
| `fclones` | fclones | `fclones` | `fclones` | No |
| `osquery` | osquery | `osquery` | `osqueryi` | Yes |
| `mas` | mas | `mas` | `mas` | No |
| `czkawka` | czkawka | `czkawka` | `czkawka_cli` | No |
| `macmon` | macmon | `macmon` | `macmon` | No |
| `mole` | Mole | `mole` | `mo` | No |
| `gdu` | gdu | `gdu` | `gdu-go` | No |

**Key detail:** The `execName(for:)` method maps tool IDs to actual binary names. Five tools have different binary names than their IDs — always use this mapping, never hardcode binary names.

- **Detection:** Checks known paths (`/opt/homebrew/bin/`, `/usr/local/bin/`, `/usr/bin/`), falls back to `which`.
- **Install source tracking:** `notInstalled | managedByUs | homebrew | direct` — distinguishes what OpenCMM installed vs. what the user had.
- **Manifest:** `~/.opencmm/manifest.json` — records tool ID, install date, version.
- **Homebrew install:** Writes official brew.sh installer to a `.command` file, opens it in Terminal. User has full visibility. App polls for detection.
- **Tool install:** `brew install [--cask] <package>`, then `brew pin` to prevent auto-upgrade.
- **Uninstall:** Only removes tools marked `managedByUs`. Unpins, then `brew uninstall`.
- **Graceful degradation:** Every tool is optional. Services have native Swift fallbacks (SHA256 dedup without fclones, FileManager-based disk analysis without gdu, native optimization without Mole).

## Principles

### 1. Privilege Escalation Is Allowed — TCC Prompts Are Not

**`sudo` via standard macOS auth dialog is OK. TCC permission prompts (Accessibility, Screen Recording, etc.) are never OK.**

For tasks requiring root (DNS flush, periodic maintenance, disk permissions), use:
```swift
osascript -e 'do shell script "..." with administrator privileges'
```
This shows the standard macOS password dialog — users expect and understand it.

**What is forbidden:**
- `osascript -e 'tell application "System Events" ...'` — triggers Accessibility TCC
- Any API that triggers Screen Recording, Camera, Microphone, or Contacts TCC prompts
- Running `sudo` directly (no TTY in GUI apps; use `do shell script` instead)

Homebrew runs as the current user (never root). Cask installs handle their own elevation internally. File removal uses macOS `trashItem` API.

### 2. Never Trigger TCC Permission Prompts

macOS TCC (Transparency, Consent, and Control) will prompt users for Screen Recording, Accessibility, etc. when:
- An app sends Apple Events to other apps (`tell application "System Events"`)
- An app uses certain system APIs (screen capture, input monitoring)

We prevent this by:
- **Ad-hoc code signing** the app bundle (no developer account needed)
- Never using `osascript` with `tell application` (Apple Events)
- Using only `do shell script ... with administrator privileges` for auth (standard password dialog, not TCC)
- Using only safe system APIs

### 3. All Shell Commands Go Through ShellExecutor

Never use `Process()` directly. `ShellExecutor` handles:
- Homebrew PATH injection (GUI apps don't inherit shell PATH)
- Pipe-before-wait deadlock prevention (read stdout before `waitUntilExit()`)
- Path quoting via `quote()` to prevent injection
- Consistent error handling

### 4. All ViewModels Are @MainActor

Every ViewModel must be `@MainActor class: ObservableObject`. This guarantees `@Published` property updates happen on the main thread. Never update `@Published` from a background thread.

### 5. All Services Are Actors

Every service must be a Swift `actor`. This provides concurrency safety without manual locking. ViewModels call services with `await`.

### 6. ScanStore Is the Single Source of Truth

When a module scans, it writes results to ScanStore. When a user navigates to a module, the VM reads from ScanStore first (`loadFromStore()`). This means:
- Overview scan results are immediately available in individual modules
- No duplicate scanning
- State survives navigation

### 7. Graceful Degradation

Every external tool is optional. If clamav isn't installed, the Security module still works (pattern-based detection). If fclones isn't installed, duplicates are found via native SHA256. If gdu isn't installed, SpaceLens uses FileManager. If mole isn't installed, Boost runs native optimization tasks.

### 8. One Module = One View + One ViewModel + One Service

Keep the separation clean. Views don't call services directly. ViewModels don't render UI. Services don't know about SwiftUI.

### 9. Ad-Hoc Code Signing Is Mandatory

The build script (`scripts/build.sh`) must always ad-hoc codesign the app bundle:
```bash
codesign --force --deep --sign - --entitlements "..." "$APP_BUNDLE"
```
Without this, macOS shows spurious permission dialogs for basic operations.

## Mistakes Not to Make

These are real mistakes that were made during development. Don't repeat them.

### ❌ Using `osascript` with Apple Events

`osascript -e 'tell application "System Events" ...'` triggers TCC (Accessibility, Screen Recording) prompts. Even from a code-signed app. Cached TCC denials persist across app versions.

**OK:** `osascript -e 'do shell script "cmd" with administrator privileges'` — this is the standard macOS auth dialog, not a TCC prompt.

**Not OK:** `osascript -e 'tell application "System Events" to ...'` — this triggers Accessibility TCC.

### ❌ Using `sudo` with Homebrew

Homebrew explicitly refuses to run as root: *"Running Homebrew as root is extremely dangerous and no longer supported."* All `brew install` commands must run as the current user. Cask installs that need admin handle their own elevation internally.

### ❌ Custom Homebrew Installation

Don't manually download tarballs, create `/opt/homebrew`, or `chown` directories. Use the official installer from brew.sh. It handles all edge cases, platform differences, and permissions. Open it in Terminal so the user has full control.

### ❌ Asking for Admin Password in the App

Don't build custom password prompts or pipe passwords to `sudo -S`. This:
- Stores user passwords in memory (security risk)
- Requires building and maintaining auth UI
- Creates trust issues ("why does this app want my password?")

If something needs admin, either the official installer handles it (Homebrew), or the tool handles it internally (cask installs), or the feature shouldn't exist.

### ❌ Empty Action Closures

When wiring buttons (like `DependencyBanner`'s `installAction`), never leave closures empty (`{}`). Wire them to actual ViewModel methods. Empty closures make buttons silently do nothing — a confusing UX bug.

### ❌ Updating @Published from Background Threads

All `@Published` properties must be updated on the main thread. Since all VMs are `@MainActor`, this is enforced by the compiler. But if you try to update `@Published` from inside an `actor` method or a detached `Task`, you'll get a runtime crash or data race. Always update from the VM layer.

### ❌ Running Shell Commands Without PATH

GUI apps launched from Finder/Dock don't inherit the user's shell PATH. Without injecting `/opt/homebrew/bin` into the process environment, `brew`, `clamscan`, etc. won't be found. `ShellExecutor` handles this — don't bypass it.

### ❌ Reading Pipe After `waitUntilExit()`

If a process writes more than ~64KB to stdout, the pipe buffer fills and the process blocks. Calling `waitUntilExit()` first creates a deadlock — the process waits for the pipe to drain, and we wait for the process to exit. Always read `readDataToEndOfFile()` before `waitUntilExit()`.

### ❌ Forgetting to Write Results to ScanStore

If a module scans but doesn't write to ScanStore, the Overview won't show results and navigating between modules loses data. Every scan must end with `scanStore?.updateSummary(...)` and writing detailed results to the store's published properties.

### ❌ Auto-Running Expensive Operations on Tab Load

Don't auto-trigger scans, installs, or network requests when a user navigates to a tab. Show an empty state with a manual "Scan" / "Load" button. Auto-running causes surprise permission prompts, unexpected network usage, and UI hangs.

### ❌ Features That Require Root Access

CPU performance counters, hardware sensors — these require sudo and are not appropriate for this app. For tasks like DNS flush, periodic maintenance, and disk permissions, use `do shell script "..." with administrator privileges` which shows the standard macOS auth dialog. Never use raw `sudo` (no TTY in GUI apps).

## Build & Distribution

```bash
make build          # Debug build
make app            # Release build + .app bundle + codesign
make dmg            # Creates OpenCMM.dmg
make release VERSION=0.3.0   # Git tag + GitHub Release with DMG
make test           # Run tests
make clean          # Clean build artifacts
```

**App bundle structure** (created by `scripts/build.sh`):
```
OpenCMM.app/Contents/
├── MacOS/OpenCMM              # Release binary
├── Resources/
│   ├── AppIcon.icns
│   └── OpenCMM.entitlements
└── Info.plist                 # Generated inline (bundle ID, version, category)
```

**Entitlements:**
- `com.apple.security.app-sandbox` → `false` (required for shell access)
- `com.apple.security.files.user-selected.read-write` → `true`

## UX Principles

### No Auto-Scan on Tab Load

No module auto-triggers scans, installs, or network requests when the user navigates to it. Each tab shows dependency status and an empty state with a manual "Scan" button. This prevents surprise permission prompts, unexpected network usage, and UI hangs.

### Consistent Button Labels

All scan buttons use "Scan" (not "Start Scan"). After scanning, the button changes to "Rescan" where applicable. Action buttons use their specific verb (e.g., "Optimize", "Uninstall", "Clean").

## File Reference

| File | Purpose |
|------|---------|
| `App/AppState.swift` | Central state — owns ScanStore + all VMs, wires everything |
| `App/OpenCMMApp.swift` | @main entry — WindowGroup + MenuBarExtra |
| `Services/ScanStore.swift` | Central @Published state for all scan results |
| `Services/DependencyManager.swift` | Tool detection, Homebrew install, manifest tracking (8 tools) |
| `Services/CleaningService.swift` | 12 scan categories — system/user/browser/app/dev caches, logs, crash reports, Xcode, mail, macOS installers, trash |
| `Services/OptimizationService.swift` | 19 native optimization tasks (16 non-privileged + 5 privileged) |
| `Services/MoleService.swift` | Wraps Mole CLI — `mo status --json`, `mo optimize`, `mo analyze --json` |
| `Services/MacMonService.swift` | Apple Silicon metrics via `macmon pipe` — CPU/GPU usage, power, thermals |
| `Services/UninstallService.swift` | App discovery, leftover scanning, brew package listing, uninstall |
| `Utilities/ShellExecutor.swift` | All shell execution — PATH injection, pipe safety, quoting |
| `Utilities/AppConstants.swift` | Health thresholds, file size limits, timing, version |
| `Utilities/FileUtils.swift` | Directory size, file ops, move to trash |
| `Components/Theme.swift` | Design tokens — fonts, colors, spacing, card/badge styles |
| `Components/ViewHelpers.swift` | moduleHeader, EmptyStateView, DependencyBanner, ErrorBanner, footerBar, ScanButton |
