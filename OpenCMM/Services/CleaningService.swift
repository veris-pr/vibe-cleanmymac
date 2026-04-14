import Foundation
import AppKit
import os

private let logger = Logger(subsystem: "com.opencmm.app", category: "CleaningService")

/// Maps browser cache names to their bundle identifiers for running-app detection.
private let browserBundleIds: [String: String] = [
    "Safari Cache": "com.apple.Safari",
    "Chrome Cache": "com.google.Chrome",
    "Firefox Cache": "org.mozilla.firefox",
    "Edge Cache": "com.microsoft.edgemac",
    "Brave Cache": "com.brave.Browser",
    "Arc Cache": "company.thebrowser.Browser",
]

actor CleaningService {
    private let home = FileUtils.homeDirectory()

    func scan() async -> [ScanResult] {
        var results: [ScanResult] = []

        results.append(scanSystemCaches())
        results.append(scanUserCaches())
        results.append(scanBrowserCaches())
        results.append(scanAppCaches())
        results.append(scanDevCaches())
        results.append(scanSystemLogs())
        results.append(scanUserLogs())
        results.append(scanCrashReports())
        results.append(scanXcodeData())
        results.append(scanMailDownloads())
        results.append(scanMacOSInstallers())
        results.append(scanTrash())

        return results.filter { !$0.items.isEmpty }
    }

    func clean(items: [CleanableItem]) async -> (cleaned: Int, freedBytes: Int64, skippedBrowsers: [String]) {
        var cleaned = 0
        var freed: Int64 = 0
        var skippedBrowsers: [String] = []

        for item in items where item.isSelected {
            // Check if this is a browser cache with the browser still running
            if item.category == .browserCache,
               let bundleId = browserBundleIds[item.name],
               isBrowserRunning(bundleId: bundleId) {
                let browserName = item.name.replacingOccurrences(of: " Cache", with: "")
                skippedBrowsers.append(browserName)
                logger.info("Skipped \(item.name) — \(browserName) is running")
                continue
            }

            do {
                try FileUtils.moveToTrash(item.path)
                cleaned += 1
                freed += item.size
            } catch {
                logger.error("Failed to clean \(item.path): \(error.localizedDescription)")
            }
        }
        return (cleaned, freed, skippedBrowsers)
    }

    /// Check if a browser is currently running by its bundle identifier.
    nonisolated private func isBrowserRunning(bundleId: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
    }

    // MARK: - Scan Helpers

    private func scanSystemCaches() -> ScanResult {
        let paths = [
            "/Library/Caches",
        ]
        let items = scanPaths(paths, category: .systemCache)
        return ScanResult(category: "System Cache", items: items)
    }

    private func scanUserCaches() -> ScanResult {
        let paths = [
            "\(home)/Library/Caches",
        ]
        var items: [CleanableItem] = []
        for basePath in paths {
            for entry in FileUtils.contentsOfDirectory(basePath) {
                let fullPath = "\(basePath)/\(entry)"
                guard FileUtils.isDirectory(fullPath) else { continue }
                let size = FileUtils.directorySize(at: fullPath)
                if size > AppConstants.FileSize.minCacheSize { // Only show items > 1MB
                    items.append(CleanableItem(
                        name: entry,
                        path: fullPath,
                        size: size,
                        category: .userCache
                    ))
                }
            }
        }
        return ScanResult(category: "User Cache", items: items.sorted { $0.size > $1.size })
    }

    private func scanBrowserCaches() -> ScanResult {
        let browserPaths: [(String, String)] = [
            ("Safari", "\(home)/Library/Caches/com.apple.Safari"),
            ("Chrome", "\(home)/Library/Caches/Google/Chrome"),
            ("Firefox", "\(home)/Library/Caches/Firefox/Profiles"),
            ("Edge", "\(home)/Library/Caches/Microsoft Edge"),
            ("Brave", "\(home)/Library/Caches/BraveSoftware"),
            ("Arc", "\(home)/Library/Caches/company.thebrowser.Browser"),
        ]
        var items: [CleanableItem] = []
        for (name, path) in browserPaths {
            guard FileUtils.exists(path) else { continue }
            let size = FileUtils.directorySize(at: path)
            if size > 0 {
                items.append(CleanableItem(name: "\(name) Cache", path: path, size: size, category: .browserCache))
            }
        }
        return ScanResult(category: "Browser Cache", items: items)
    }

    private func scanSystemLogs() -> ScanResult {
        let paths = [
            "/Library/Logs",
            "/var/log",
        ]
        let items = scanPaths(paths, category: .systemLogs)
        return ScanResult(category: "System Logs", items: items)
    }

    private func scanUserLogs() -> ScanResult {
        let path = "\(home)/Library/Logs"
        var items: [CleanableItem] = []
        for entry in FileUtils.contentsOfDirectory(path) {
            let fullPath = "\(path)/\(entry)"
            let size = FileUtils.isDirectory(fullPath)
                ? FileUtils.directorySize(at: fullPath)
                : FileUtils.fileSize(at: fullPath)
            if size > AppConstants.FileSize.minLogSize {
                items.append(CleanableItem(name: entry, path: fullPath, size: size, category: .userLogs))
            }
        }
        return ScanResult(category: "User Logs", items: items.sorted { $0.size > $1.size })
    }

    private func scanXcodeData() -> ScanResult {
        let xcodePaths: [(String, String)] = [
            ("Derived Data", "\(home)/Library/Developer/Xcode/DerivedData"),
            ("iOS Device Support", "\(home)/Library/Developer/Xcode/iOS DeviceSupport"),
            ("watchOS Device Support", "\(home)/Library/Developer/Xcode/watchOS DeviceSupport"),
            ("Archives", "\(home)/Library/Developer/Xcode/Archives"),
            ("CoreSimulator Caches", "\(home)/Library/Developer/CoreSimulator/Caches"),
            ("CoreSimulator Devices Temp", "\(home)/Library/Developer/CoreSimulator/Devices"),
            ("CoreSimulator Logs", "\(home)/Library/Logs/CoreSimulator"),
            ("Xcode Cache", "\(home)/Library/Caches/com.apple.dt.Xcode"),
            ("iOS Device Logs", "\(home)/Library/Developer/Xcode/iOS Device Logs"),
            ("watchOS Device Logs", "\(home)/Library/Developer/Xcode/watchOS Device Logs"),
            ("Xcode Build Products", "\(home)/Library/Developer/Xcode/Products"),
            ("Documentation Cache", "\(home)/Library/Developer/Xcode/DocumentationCache"),
        ]
        var items: [CleanableItem] = []
        for (name, path) in xcodePaths {
            guard FileUtils.exists(path) else { continue }
            let size = FileUtils.directorySize(at: path)
            if size > 0 {
                items.append(CleanableItem(name: name, path: path, size: size, category: .xcodeData))
            }
        }
        return ScanResult(category: "Xcode Data", items: items)
    }

    private func scanCrashReports() -> ScanResult {
        let paths: [(String, String)] = [
            ("User Crash Reports", "\(home)/Library/Logs/DiagnosticReports"),
            ("System Crash Reports", "/Library/Logs/DiagnosticReports"),
        ]
        var items: [CleanableItem] = []
        for (name, path) in paths {
            guard FileUtils.exists(path) else { continue }
            let size = FileUtils.directorySize(at: path)
            if size > AppConstants.FileSize.minLogSize {
                items.append(CleanableItem(name: name, path: path, size: size, category: .crashReports))
            }
        }
        return ScanResult(category: "Crash Reports", items: items)
    }

    private func scanAppCaches() -> ScanResult {
        // Well-known app caches (from Mole's app_caches.sh)
        let appPaths: [(String, String)] = [
            // Communication
            ("Discord Cache", "\(home)/Library/Application Support/discord/Cache"),
            ("Slack Cache", "\(home)/Library/Application Support/Slack/Cache"),
            ("Zoom Cache", "\(home)/Library/Caches/us.zoom.xos"),
            ("Microsoft Teams Cache", "\(home)/Library/Caches/com.microsoft.teams2"),
            ("WhatsApp Cache", "\(home)/Library/Caches/net.whatsapp.WhatsApp"),
            // Code Editors
            ("VS Code Logs", "\(home)/Library/Application Support/Code/logs"),
            ("VS Code Cache", "\(home)/Library/Application Support/Code/Cache"),
            ("VS Code Cached Data", "\(home)/Library/Application Support/Code/CachedData"),
            // AI
            ("ChatGPT Cache", "\(home)/Library/Caches/com.openai.chat"),
            ("Claude Cache", "\(home)/Library/Caches/com.anthropic.claudefordesktop"),
            // Design
            ("Adobe Cache", "\(home)/Library/Caches/Adobe"),
            ("Figma Cache", "\(home)/Library/Caches/com.figma.Desktop"),
            ("Sketch Cache", "\(home)/Library/Caches/com.bohemiancoding.sketch3"),
            // Media
            ("Spotify Cache", "\(home)/Library/Caches/com.spotify.client"),
            ("IINA Cache", "\(home)/Library/Caches/com.colliderli.iina"),
            ("VLC Cache", "\(home)/Library/Caches/org.videolan.vlc"),
            // Gaming
            ("Steam Cache", "\(home)/Library/Application Support/Steam/appcache"),
            ("Steam Shader Cache", "\(home)/Library/Application Support/Steam/steamapps/shadercache"),
            // Notes
            ("Notion Cache", "\(home)/Library/Caches/notion.id"),
            ("Obsidian Cache", "\(home)/Library/Caches/md.obsidian"),
            // Launchers
            ("Alfred Cache", "\(home)/Library/Caches/com.runningwithcrayons.Alfred"),
            // Terminals
            ("Warp Cache", "\(home)/Library/Caches/dev.warp.Warp-Stable"),
            ("Ghostty Cache", "\(home)/Library/Caches/com.mitchellh.ghostty"),
        ]
        var items: [CleanableItem] = []
        for (name, path) in appPaths {
            guard FileUtils.exists(path) else { continue }
            let size = FileUtils.directorySize(at: path)
            if size > AppConstants.FileSize.minCacheSize {
                items.append(CleanableItem(name: name, path: path, size: size, category: .appCache))
            }
        }
        return ScanResult(category: "App Cache", items: items.sorted { $0.size > $1.size })
    }

    private func scanDevCaches() -> ScanResult {
        let devPaths: [(String, String)] = [
            // JavaScript
            ("npm Cache", "\(home)/.npm"),
            ("Yarn Cache", "\(home)/.yarn/cache"),
            ("pnpm Store", "\(home)/Library/pnpm/store"),
            ("Bun Cache", "\(home)/.bun/install/cache"),
            // Python
            ("pip Cache", "\(home)/Library/Caches/pip"),
            ("pyenv Cache", "\(home)/.pyenv/cache"),
            ("Poetry Cache", "\(home)/.cache/poetry"),
            ("uv Cache", "\(home)/.cache/uv"),
            ("Conda Packages", "\(home)/.conda/pkgs"),
            ("Hugging Face Cache", "\(home)/.cache/huggingface"),
            // Rust
            ("Cargo Registry Cache", "\(home)/.cargo/registry/cache"),
            ("Cargo Git Cache", "\(home)/.cargo/git"),
            ("Rustup Downloads", "\(home)/.rustup/downloads"),
            // Go
            ("Go Build Cache", "\(home)/Library/Caches/go-build"),
            // Docker
            ("Docker BuildX Cache", "\(home)/.docker/buildx/cache"),
            // Cloud
            ("Kubernetes Cache", "\(home)/.kube/cache"),
            ("AWS CLI Cache", "\(home)/.aws/cli/cache"),
            ("Google Cloud Logs", "\(home)/.config/gcloud/logs"),
            ("Azure CLI Logs", "\(home)/.azure/logs"),
            // Frontend
            ("Electron Cache", "\(home)/.cache/electron"),
            ("node-gyp Cache", "\(home)/.cache/node-gyp"),
            ("Turbo Cache", "\(home)/.turbo/cache"),
            // Homebrew
            ("Homebrew Cache", "\(home)/Library/Caches/Homebrew"),
        ]
        var items: [CleanableItem] = []
        for (name, path) in devPaths {
            guard FileUtils.exists(path) else { continue }
            let size = FileUtils.directorySize(at: path)
            if size > AppConstants.FileSize.minCacheSize {
                items.append(CleanableItem(name: name, path: path, size: size, category: .devCache))
            }
        }
        return ScanResult(category: "Developer Cache", items: items.sorted { $0.size > $1.size })
    }

    private func scanMailDownloads() -> ScanResult {
        let paths: [(String, String)] = [
            ("Mail Downloads", "\(home)/Library/Mail Downloads"),
            ("Mail Container Downloads", "\(home)/Library/Containers/com.apple.mail/Data/Library/Mail Downloads"),
        ]
        var items: [CleanableItem] = []
        let threshold = Date().addingTimeInterval(-30 * 24 * 3600) // 30 days
        let fm = FileManager.default
        for (name, basePath) in paths {
            guard FileUtils.exists(basePath) else { continue }
            var totalSize: Int64 = 0
            let files = (try? fm.contentsOfDirectory(atPath: basePath)) ?? []
            for file in files {
                let filePath = (basePath as NSString).appendingPathComponent(file)
                if let attrs = try? fm.attributesOfItem(atPath: filePath),
                   let modDate = attrs[.modificationDate] as? Date,
                   modDate < threshold {
                    totalSize += (attrs[.size] as? Int64) ?? 0
                }
            }
            if totalSize > AppConstants.FileSize.minCacheSize {
                items.append(CleanableItem(name: name, path: basePath, size: totalSize, category: .mailDownloads))
            }
        }
        return ScanResult(category: "Mail Downloads", items: items)
    }

    private func scanMacOSInstallers() -> ScanResult {
        var items: [CleanableItem] = []
        let fm = FileManager.default
        let threshold = Date().addingTimeInterval(-14 * 24 * 3600) // 14 days

        // Get current macOS major version to skip matching installers
        let currentMajor = ProcessInfo.processInfo.operatingSystemVersion.majorVersion

        let appsDir = "/Applications"
        let contents = (try? fm.contentsOfDirectory(atPath: appsDir)) ?? []
        for entry in contents where entry.hasPrefix("Install macOS") && entry.hasSuffix(".app") {
            let appPath = (appsDir as NSString).appendingPathComponent(entry)
            guard FileUtils.isDirectory(appPath) else { continue }

            // Skip if installer matches current macOS version
            let plistPath = "\(appPath)/Contents/Info.plist"
            if fm.fileExists(atPath: plistPath),
               let plist = NSDictionary(contentsOfFile: plistPath),
               let version = plist["DTPlatformVersion"] as? String,
               version.contains(String(currentMajor)) {
                continue
            }

            // Skip if < 14 days old
            if let attrs = try? fm.attributesOfItem(atPath: appPath),
               let modDate = attrs[.modificationDate] as? Date,
               modDate > threshold {
                continue
            }

            let size = FileUtils.directorySize(at: appPath)
            if size > 0 {
                items.append(CleanableItem(name: entry, path: appPath, size: size, category: .macOSInstaller))
            }
        }

        // Also check /macOS Install Data
        let installData = "/macOS Install Data"
        if FileUtils.exists(installData) {
            if let attrs = try? fm.attributesOfItem(atPath: installData),
               let modDate = attrs[.modificationDate] as? Date,
               modDate < threshold {
                let size = FileUtils.directorySize(at: installData)
                if size > 0 {
                    items.append(CleanableItem(name: "macOS Install Data", path: installData, size: size, category: .macOSInstaller))
                }
            }
        }

        return ScanResult(category: "macOS Installer", items: items)
    }

    private func scanTrash() -> ScanResult {
        let trashPath = "\(home)/.Trash"
        guard FileUtils.exists(trashPath) else { return ScanResult(category: "Trash", items: []) }
        let size = FileUtils.directorySize(at: trashPath)
        var items: [CleanableItem] = []
        if size > 0 {
            items.append(CleanableItem(name: "Trash", path: trashPath, size: size, category: .trash))
        }
        return ScanResult(category: "Trash", items: items)
    }

    private func scanPaths(_ paths: [String], category: CleanCategory) -> [CleanableItem] {
        var items: [CleanableItem] = []
        for path in paths {
            guard FileUtils.exists(path) else { continue }
            let size = FileUtils.directorySize(at: path)
            if size > 0 {
                let name = URL(fileURLWithPath: path).lastPathComponent
                items.append(CleanableItem(name: name, path: path, size: size, category: category))
            }
        }
        return items
    }
}
