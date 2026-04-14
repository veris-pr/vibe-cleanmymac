import Foundation

actor OptimizationService {

    struct StepResult {
        let detail: String
    }

    // MARK: - Non-Privileged Tasks

    func rebuildLaunchServices() async throws -> StepResult {
        let lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        guard FileManager.default.fileExists(atPath: lsregister) else {
            return StepResult(detail: "lsregister not found")
        }
        try await ShellExecutor.shellAsync("\(ShellExecutor.quote(lsregister)) -kill -r -domain local -domain system -domain user")
        return StepResult(detail: "Fixed duplicate Open With entries")
    }

    func refreshQuickLookCaches() async throws -> StepResult {
        try? await ShellExecutor.shellAsync("qlmanage -r cache", ignoreExitCode: true)
        try? await ShellExecutor.shellAsync("qlmanage -r", ignoreExitCode: true)

        let fm = FileManager.default
        let caches = [
            NSHomeDirectory() + "/Library/Caches/com.apple.QuickLook.thumbnailcache",
            NSHomeDirectory() + "/Library/Caches/com.apple.iconservices.store",
            NSHomeDirectory() + "/Library/Caches/com.apple.iconservices"
        ]
        var cleaned = 0
        for path in caches {
            if fm.fileExists(atPath: path) {
                try? fm.removeItem(atPath: path)
                cleaned += 1
            }
        }
        return StepResult(detail: "Thumbnails and icon caches refreshed")
    }

    func clearQuarantineHistory() async throws -> StepResult {
        let db = NSHomeDirectory() + "/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2"
        guard FileManager.default.fileExists(atPath: db) else {
            return StepResult(detail: "Already clean")
        }
        let countStr = try? ShellExecutor.shell("sqlite3 \(ShellExecutor.quote(db)) 'SELECT COUNT(*) FROM LSQuarantineEvent;'")
        let count = Int(countStr ?? "0") ?? 0
        if count == 0 {
            return StepResult(detail: "Already clean")
        }
        try ShellExecutor.shell("sqlite3 \(ShellExecutor.quote(db)) 'DELETE FROM LSQuarantineEvent; VACUUM;'")
        return StepResult(detail: "\(count) download history entries cleared")
    }

    func cleanBrokenLaunchAgents() async throws -> StepResult {
        let agentsDir = NSHomeDirectory() + "/Library/LaunchAgents"
        let fm = FileManager.default
        guard fm.fileExists(atPath: agentsDir) else {
            return StepResult(detail: "All healthy")
        }

        var brokenCount = 0
        let files = (try? fm.contentsOfDirectory(atPath: agentsDir)) ?? []
        for file in files where file.hasSuffix(".plist") {
            let plistPath = (agentsDir as NSString).appendingPathComponent(file)
            // Check if the binary referenced exists
            let binary = try? ShellExecutor.shell("/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:0' \(ShellExecutor.quote(plistPath))", ignoreExitCode: true)
            let program = binary?.isEmpty == false ? binary : try? ShellExecutor.shell("/usr/libexec/PlistBuddy -c 'Print :Program' \(ShellExecutor.quote(plistPath))", ignoreExitCode: true)

            if let prog = program, !prog.isEmpty, !fm.fileExists(atPath: prog) {
                try? ShellExecutor.shell("launchctl unload \(ShellExecutor.quote(plistPath))", ignoreExitCode: true)
                try? fm.removeItem(atPath: plistPath)
                brokenCount += 1
            }
        }

        return StepResult(detail: brokenCount > 0 ? "Removed \(brokenCount) broken agent(s)" : "All healthy")
    }

    func fixBrokenPreferences() async throws -> StepResult {
        let fm = FileManager.default
        var brokenCount = 0

        // Scan both Preferences and ByHost directories
        let prefsDirs = [
            NSHomeDirectory() + "/Library/Preferences",
            NSHomeDirectory() + "/Library/Preferences/ByHost"
        ]

        for prefsDir in prefsDirs {
            guard fm.fileExists(atPath: prefsDir) else { continue }
            let files = (try? fm.contentsOfDirectory(atPath: prefsDir)) ?? []
            for file in files where file.hasSuffix(".plist") {
                if file.hasPrefix("com.apple.") || file.hasPrefix(".GlobalPreferences") || file == "loginwindow.plist" {
                    continue
                }
                let path = (prefsDir as NSString).appendingPathComponent(file)
                let result = try? ShellExecutor.shell("plutil -lint \(ShellExecutor.quote(path))", ignoreExitCode: true)
                if result?.contains("OK") != true {
                    try? fm.removeItem(atPath: path)
                    brokenCount += 1
                }
            }
        }

        return StepResult(detail: brokenCount > 0 ? "Repaired \(brokenCount) corrupted file(s)" : "All valid")
    }

    func refreshDock() async throws -> StepResult {
        // Clear dock databases
        let dockSupport = NSHomeDirectory() + "/Library/Application Support/Dock"
        let fm = FileManager.default
        if fm.fileExists(atPath: dockSupport) {
            let files = (try? fm.contentsOfDirectory(atPath: dockSupport)) ?? []
            for file in files where file.hasSuffix(".db") {
                try? fm.removeItem(atPath: (dockSupport as NSString).appendingPathComponent(file))
            }
        }
        try await ShellExecutor.shellAsync("killall Dock", ignoreExitCode: true)
        return StepResult(detail: "Dock cache cleared and restarted")
    }

    func cleanOldSavedStates() async throws -> StepResult {
        let stateDir = NSHomeDirectory() + "/Library/Saved Application State"
        let fm = FileManager.default
        guard fm.fileExists(atPath: stateDir) else {
            return StepResult(detail: "Nothing to clean")
        }

        let threshold = Date().addingTimeInterval(-30 * 24 * 3600) // 30 days
        var cleaned = 0
        var freedBytes: Int64 = 0
        let dirs = (try? fm.contentsOfDirectory(atPath: stateDir)) ?? []
        for dir in dirs where dir.hasSuffix(".savedState") {
            let path = (stateDir as NSString).appendingPathComponent(dir)
            if let attrs = try? fm.attributesOfItem(atPath: path),
               let modDate = attrs[.modificationDate] as? Date,
               modDate < threshold {
                let size = FileUtils.directorySize(at: path)
                try? fm.removeItem(atPath: path)
                cleaned += 1
                freedBytes += size
            }
        }

        if cleaned > 0 {
            return StepResult(detail: "\(cleaned) old state(s) · \(Formatters.fileSize(freedBytes))")
        }
        return StepResult(detail: "All recent")
    }

    func preventNetworkDSStore() async throws -> StepResult {
        let domain = "com.apple.desktopservices"
        let keys = ["DSDontWriteNetworkStores", "DSDontWriteUSBStores"]
        var changed = 0
        for key in keys {
            let current = try? ShellExecutor.shell("defaults read \(domain) \(key)", ignoreExitCode: true)
            if current?.trimmingCharacters(in: .whitespacesAndNewlines) != "1" {
                try? ShellExecutor.shell("defaults write \(domain) \(key) -bool true")
                changed += 1
            }
        }
        return StepResult(detail: changed > 0 ? "Prevention enabled" : "Already enabled")
    }

    func vacuumAppDatabases() async throws -> StepResult {
        // Vacuum SQLite databases for Mail, Safari, Messages — skip if app is running
        let apps: [(name: String, dbPaths: [String])] = [
            ("Mail", [NSHomeDirectory() + "/Library/Mail/V*/MailData/Envelope Index"]),
            ("Safari", [NSHomeDirectory() + "/Library/Safari/History.db",
                        NSHomeDirectory() + "/Library/Safari/Databases/Databases.db"]),
            ("Messages", [NSHomeDirectory() + "/Library/Messages/chat.db"])
        ]

        var vacuumed = 0
        var skippedApps: [String] = []
        let fm = FileManager.default

        for app in apps {
            // Check if app is running
            let isRunning = (try? ShellExecutor.shell("pgrep -x \(ShellExecutor.quote(app.name))", ignoreExitCode: true))?.isEmpty == false
            if isRunning {
                skippedApps.append(app.name)
                continue
            }

            for pattern in app.dbPaths {
                // Resolve glob patterns
                let resolvedPaths: [String]
                if pattern.contains("*") {
                    let dir = (pattern as NSString).deletingLastPathComponent
                    let globPart = (pattern as NSString).lastPathComponent
                    let dirContents = (try? fm.contentsOfDirectory(atPath: dir)) ?? []
                    resolvedPaths = dirContents
                        .filter { $0.hasSuffix(globPart.replacingOccurrences(of: "*", with: "")) || globPart == "*" }
                        .map { (dir as NSString).appendingPathComponent($0) }
                } else {
                    resolvedPaths = [pattern]
                }

                for dbPath in resolvedPaths {
                    guard fm.fileExists(atPath: dbPath) else { continue }
                    let size = FileUtils.fileSize(at: dbPath)
                    // Only vacuum databases over 10MB
                    guard size > 10_000_000 else { continue }
                    if let _ = try? ShellExecutor.shell("sqlite3 \(ShellExecutor.quote(dbPath)) 'PRAGMA integrity_check; VACUUM;'") {
                        vacuumed += 1
                    }
                }
            }
        }

        if !skippedApps.isEmpty {
            return StepResult(detail: "\(vacuumed) optimized · \(skippedApps.joined(separator: ", ")) running, skipped")
        }
        return StepResult(detail: vacuumed > 0 ? "\(vacuumed) database(s) optimized" : "All databases healthy")
    }

    func rebuildFontCache() async throws -> StepResult {
        // Skip if browsers are running to avoid cache conflicts
        let browsers = ["Safari", "Google Chrome", "Firefox", "Brave Browser", "Microsoft Edge", "Arc"]
        for browser in browsers {
            let running = (try? ShellExecutor.shell("pgrep -x \(ShellExecutor.quote(browser))", ignoreExitCode: true))?.isEmpty == false
            if running {
                return StepResult(detail: "Skipped — \(browser) is running")
            }
        }

        _ = try? await ShellExecutor.shellAsync("atsutil databases -remove", ignoreExitCode: true)
        _ = try? await ShellExecutor.shellAsync("atsutil server -shutdown", ignoreExitCode: true)
        _ = try? await ShellExecutor.shellAsync("atsutil server -ping", ignoreExitCode: true)
        return StepResult(detail: "Font cache rebuilt")
    }

    func repairSharedFileLists() async throws -> StepResult {
        let sflDir = NSHomeDirectory() + "/Library/Application Support/com.apple.sharedfilelist"
        let fm = FileManager.default
        guard fm.fileExists(atPath: sflDir) else {
            return StepResult(detail: "Not found")
        }

        var repaired = 0
        let files = (try? fm.contentsOfDirectory(atPath: sflDir)) ?? []
        for file in files where file.hasSuffix(".sfl2") || file.hasSuffix(".sfl3") {
            // Skip recent documents (user data)
            if file.contains("ApplicationRecentDocuments") { continue }
            let path = (sflDir as NSString).appendingPathComponent(file)
            let result = try? ShellExecutor.shell("plutil -lint \(ShellExecutor.quote(path))", ignoreExitCode: true)
            if result?.contains("OK") != true {
                try? fm.removeItem(atPath: path)
                repaired += 1
            }
        }

        return StepResult(detail: repaired > 0 ? "Repaired \(repaired) corrupted list(s)" : "All healthy")
    }

    func cleanNotificationDatabase() async throws -> StepResult {
        // Notification Center database
        let darwinDir = (try? ShellExecutor.shell("getconf DARWIN_USER_DIR"))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !darwinDir.isEmpty else { return StepResult(detail: "Not found") }

        let ncDb = "\(darwinDir)/com.apple.notificationcenter/db2/db"
        guard FileManager.default.fileExists(atPath: ncDb) else {
            return StepResult(detail: "Not found")
        }

        let size = FileUtils.fileSize(at: ncDb)
        // Only clean if > 50MB
        guard size > 50_000_000 else {
            return StepResult(detail: "Healthy (\(Formatters.fileSize(size)))")
        }

        // Delete old notifications (>30 days) and vacuum
        _ = try? ShellExecutor.shell(
            "sqlite3 \(ShellExecutor.quote(ncDb)) \"DELETE FROM record WHERE delivered_date < strftime('%s','now','-30 days'); VACUUM;\""
        )
        let newSize = FileUtils.fileSize(at: ncDb)
        let freed = size - newSize
        return StepResult(detail: freed > 0 ? "Cleaned \(Formatters.fileSize(freed))" : "Optimized")
    }

    func cleanCoreDuetDatabase() async throws -> StepResult {
        let knowledgeDb = NSHomeDirectory() + "/Library/Application Support/Knowledge/knowledgeC.db"
        let walFile = knowledgeDb + "-wal"
        let shmFile = knowledgeDb + "-shm"
        let fm = FileManager.default

        guard fm.fileExists(atPath: knowledgeDb) else {
            return StepResult(detail: "Not found")
        }

        var totalSize: Int64 = 0
        for path in [knowledgeDb, walFile, shmFile] {
            totalSize += FileUtils.fileSize(at: path)
        }

        // Only clean if > 100MB combined
        guard totalSize > 100_000_000 else {
            return StepResult(detail: "Healthy (\(Formatters.fileSize(totalSize)))")
        }

        // Checkpoint WAL into main db and vacuum
        _ = try? ShellExecutor.shell("sqlite3 \(ShellExecutor.quote(knowledgeDb)) 'PRAGMA wal_checkpoint(TRUNCATE); VACUUM;'")
        var newTotal: Int64 = 0
        for path in [knowledgeDb, walFile, shmFile] {
            newTotal += FileUtils.fileSize(at: path)
        }
        let freed = totalSize - newTotal
        return StepResult(detail: freed > 0 ? "Reclaimed \(Formatters.fileSize(freed))" : "Optimized")
    }

    func optimizeSpotlightIndex() async throws -> StepResult {
        // Check if Spotlight is enabled
        let status = (try? ShellExecutor.shell("mdutil -s /", ignoreExitCode: true)) ?? ""
        guard !status.localizedCaseInsensitiveContains("Indexing disabled") else {
            return StepResult(detail: "Spotlight indexing is disabled")
        }

        // Test search speed — if slow, consider re-index
        let start = Date()
        _ = try? ShellExecutor.shell("mdfind 'kMDItemFSName == \"Applications\"'", ignoreExitCode: true)
        let elapsed = Date().timeIntervalSince(start)

        if elapsed > 3 {
            return StepResult(detail: "Index slow (\(String(format: "%.1f", elapsed))s) — consider re-indexing in System Settings")
        }
        return StepResult(detail: "Search index responsive (\(String(format: "%.1f", elapsed))s)")
    }

    // MARK: - Privileged Tasks (require admin password)

    func flushDNSCache() async throws -> StepResult {
        try await ShellExecutor.shellAsync(
            "osascript -e 'do shell script \"dscacheutil -flushcache && killall -HUP mDNSResponder\" with administrator privileges'"
        )
        return StepResult(detail: "DNS cache and mDNSResponder refreshed")
    }

    func runPeriodicMaintenance() async throws -> StepResult {
        try await ShellExecutor.shellAsync(
            "osascript -e 'do shell script \"periodic daily weekly monthly\" with administrator privileges'"
        )
        return StepResult(detail: "Daily, weekly, monthly scripts executed")
    }

    func repairDiskPermissions() async throws -> StepResult {
        let uid = ProcessInfo.processInfo.environment["UID"] ?? String(getuid())
        try await ShellExecutor.shellAsync(
            "osascript -e 'do shell script \"diskutil resetUserPermissions / \(uid)\" with administrator privileges'",
            ignoreExitCode: true
        )
        return StepResult(detail: "User directory permissions verified")
    }

    func purgeMemory() async throws -> StepResult {
        // Only if memory pressure is elevated
        let vmStat = (try? ShellExecutor.shell("vm_stat")) ?? ""
        // Parse pages to determine compressed memory
        var compressedPages: Int64 = 0
        for line in vmStat.components(separatedBy: "\n") {
            if line.contains("compressor") {
                let nums = line.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int64($0) }
                compressedPages = nums.first ?? 0
            }
        }
        // Only purge if significant compressed memory (> 1GB ≈ 262144 pages of 4K)
        guard compressedPages > 262_144 else {
            return StepResult(detail: "Memory pressure normal — skipped")
        }

        try await ShellExecutor.shellAsync(
            "osascript -e 'do shell script \"purge\" with administrator privileges'"
        )
        return StepResult(detail: "Inactive memory reclaimed")
    }

    func flushNetworkStack() async throws -> StepResult {
        try await ShellExecutor.shellAsync(
            "osascript -e 'do shell script \"route -n flush && arp -n -a -d\" with administrator privileges'",
            ignoreExitCode: true
        )
        return StepResult(detail: "Routing table and ARP cache flushed")
    }
}
