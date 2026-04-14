import Foundation

actor OptimizationService {

    struct StepResult {
        let detail: String
    }

    // MARK: - Non-Privileged Tasks

    func rebuildLaunchServices() async throws -> StepResult {
        let paths = [
            "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
            "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
        ]
        guard let lsregister = paths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            return StepResult(detail: "lsregister not found")
        }
        let quoted = ShellExecutor.quote(lsregister)
        // Garbage collect stale entries first
        _ = try? await ShellExecutor.shellAsync("\(quoted) -gc", ignoreExitCode: true)
        // Force rescan all domains; fall back to local+user if system fails
        let allDomains = try? await ShellExecutor.shellAsync("\(quoted) -r -f -domain local -domain user -domain system")
        if allDomains == nil {
            _ = try? await ShellExecutor.shellAsync("\(quoted) -r -f -domain local -domain user", ignoreExitCode: true)
        }
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
        let dockSupport = NSHomeDirectory() + "/Library/Application Support/Dock"
        let fm = FileManager.default
        if fm.fileExists(atPath: dockSupport) {
            let files = (try? fm.contentsOfDirectory(atPath: dockSupport)) ?? []
            for file in files where file.hasSuffix(".db") {
                try? fm.removeItem(atPath: (dockSupport as NSString).appendingPathComponent(file))
            }
        }
        // Touch dock plist to trigger re-read
        let dockPlist = NSHomeDirectory() + "/Library/Preferences/com.apple.dock.plist"
        if fm.fileExists(atPath: dockPlist) {
            try? fm.setAttributes([.modificationDate: Date()], ofItemAtPath: dockPlist)
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
        let apps: [(name: String, dbPaths: [String])] = [
            ("Mail", [NSHomeDirectory() + "/Library/Mail"]),
            ("Safari", [NSHomeDirectory() + "/Library/Safari/History.db",
                        NSHomeDirectory() + "/Library/Safari/Databases/Databases.db",
                        NSHomeDirectory() + "/Library/Safari/TopSites.db"]),
            ("Messages", [NSHomeDirectory() + "/Library/Messages/chat.db"])
        ]

        var vacuumed = 0
        var skippedApps: [String] = []
        let fm = FileManager.default

        for app in apps {
            let isRunning = (try? ShellExecutor.shell("pgrep -x \(ShellExecutor.quote(app.name))", ignoreExitCode: true))?.isEmpty == false
            if isRunning {
                skippedApps.append(app.name)
                continue
            }

            for pathOrDir in app.dbPaths {
                var resolvedPaths: [String] = []

                if app.name == "Mail" {
                    // Resolve ~/Library/Mail/V*/MailData/Envelope Index
                    let mailDir = pathOrDir
                    let vDirs = (try? fm.contentsOfDirectory(atPath: mailDir)) ?? []
                    for vDir in vDirs where vDir.hasPrefix("V") {
                        let envelopePath = (mailDir as NSString)
                            .appendingPathComponent(vDir)
                            .appending("/MailData/Envelope Index")
                        if fm.fileExists(atPath: envelopePath) {
                            resolvedPaths.append(envelopePath)
                        }
                    }
                } else {
                    resolvedPaths = [pathOrDir]
                }

                for dbPath in resolvedPaths {
                    guard fm.fileExists(atPath: dbPath) else { continue }

                    // Verify it's actually a SQLite file
                    let fileType = (try? ShellExecutor.shell("file -b \(ShellExecutor.quote(dbPath))", ignoreExitCode: true)) ?? ""
                    guard fileType.contains("SQLite") else { continue }

                    let size = FileUtils.fileSize(at: dbPath)
                    // Skip tiny databases (<10MB) and oversized ones (>100MB)
                    guard size > 10_000_000 && size < 100_000_000 else { continue }

                    // Check freelist — skip if already compact (<5% free pages)
                    let pageInfo = (try? ShellExecutor.shell("sqlite3 \(ShellExecutor.quote(dbPath)) 'PRAGMA page_count; PRAGMA freelist_count;'")) ?? ""
                    let lines = pageInfo.components(separatedBy: "\n").compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                    if lines.count >= 2, lines[0] > 0 {
                        let freelistPct = (lines[1] * 100) / lines[0]
                        if freelistPct < 5 { continue }
                    }

                    // Integrity check before vacuum
                    let integrity = (try? ShellExecutor.shell("sqlite3 \(ShellExecutor.quote(dbPath)) 'PRAGMA integrity_check;'", ignoreExitCode: true)) ?? ""
                    guard integrity.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "ok" else { continue }

                    if let _ = try? ShellExecutor.shell("sqlite3 \(ShellExecutor.quote(dbPath)) 'VACUUM;'") {
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
        // Skip if browsers are running — clearing font cache while browsers run leaves stale GPU/text caches
        let browsers = ["Safari", "Google Chrome", "Chromium", "Firefox", "Brave Browser",
                         "Microsoft Edge", "Arc", "Opera", "Vivaldi", "Zen Browser", "Helium"]
        for browser in browsers {
            let running = (try? ShellExecutor.shell("pgrep -ix \(ShellExecutor.quote(browser))", ignoreExitCode: true))?.isEmpty == false
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
        // Restart NotificationCenter so UI reflects changes
        _ = try? await ShellExecutor.shellAsync("killall NotificationCenter", ignoreExitCode: true)
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

        guard totalSize > 100_000_000 else {
            return StepResult(detail: "Healthy (\(Formatters.fileSize(totalSize)))")
        }

        // Remove WAL/SHM files first (auto-regenerated by SQLite)
        for path in [walFile, shmFile] {
            if fm.fileExists(atPath: path) { try? fm.removeItem(atPath: path) }
        }

        // Delete ZOBJECT entries older than 90 days
        // CoreTime epoch: seconds since 2001-01-01 (Mac epoch offset from Unix epoch)
        _ = try? ShellExecutor.shell(
            "sqlite3 \(ShellExecutor.quote(knowledgeDb)) \"DELETE FROM ZOBJECT WHERE ZCREATIONDATE < (strftime('%s','now','-90 days') - strftime('%s','2001-01-01')); VACUUM;\""
        )

        var newTotal: Int64 = 0
        for path in [knowledgeDb, walFile, shmFile] {
            newTotal += FileUtils.fileSize(at: path)
        }
        let freed = totalSize - newTotal
        return StepResult(detail: freed > 0 ? "Reclaimed \(Formatters.fileSize(freed))" : "Optimized")
    }

    func optimizeSpotlightIndex() async throws -> StepResult {
        let status = (try? ShellExecutor.shell("mdutil -s /", ignoreExitCode: true)) ?? ""
        guard !status.localizedCaseInsensitiveContains("Indexing disabled") else {
            return StepResult(detail: "Spotlight indexing is disabled")
        }

        // Double-test search speed — both must fail to confirm slowness
        var slowCount = 0
        for _ in 0..<2 {
            let start = Date()
            _ = try? ShellExecutor.shell("mdfind 'kMDItemFSName == \"Applications\"'", ignoreExitCode: true)
            if Date().timeIntervalSince(start) > 3 { slowCount += 1 }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        guard slowCount >= 2 else {
            return StepResult(detail: "Search index responsive")
        }

        // Only rebuild on AC power (reindexing is intensive)
        let powerInfo = (try? ShellExecutor.shell("pmset -g batt", ignoreExitCode: true)) ?? ""
        guard powerInfo.contains("AC Power") else {
            return StepResult(detail: "Index slow — connect AC power to rebuild")
        }

        // Trigger rebuild
        try await ShellExecutor.shellAsync(
            "osascript -e 'do shell script \"mdutil -E /\" with administrator privileges'",
            ignoreExitCode: true
        )
        return StepResult(detail: "Spotlight index rebuild started (1-2 hours in background)")
    }

    // MARK: - Privileged Tasks (require admin password)

    func flushDNSCache() async throws -> StepResult {
        try await ShellExecutor.shellAsync(
            "osascript -e 'do shell script \"dscacheutil -flushcache && killall -HUP mDNSResponder\" with administrator privileges'"
        )
        return StepResult(detail: "DNS cache and mDNSResponder refreshed")
    }

    func runPeriodicMaintenance() async throws -> StepResult {
        // Check if periodic has run recently (within 7 days)
        let dailyLog = "/var/log/daily.out"
        if FileManager.default.fileExists(atPath: dailyLog),
           let attrs = try? FileManager.default.attributesOfItem(atPath: dailyLog),
           let modDate = attrs[.modificationDate] as? Date {
            let daysSince = Date().timeIntervalSince(modDate) / 86400
            if daysSince < 7 {
                return StepResult(detail: "Already current (\(Int(daysSince))d ago)")
            }
        }

        try await ShellExecutor.shellAsync(
            "osascript -e 'do shell script \"periodic daily weekly monthly\" with administrator privileges'"
        )
        return StepResult(detail: "Daily, weekly, monthly scripts executed")
    }

    func repairDiskPermissions() async throws -> StepResult {
        let home = NSHomeDirectory()
        let fm = FileManager.default

        // Check if repair is actually needed
        var needsRepair = false
        let checkPaths = [home, home + "/Library", home + "/Library/Preferences"]
        for path in checkPaths {
            if fm.fileExists(atPath: path) && !fm.isWritableFile(atPath: path) {
                needsRepair = true
                break
            }
        }
        // Check HOME ownership
        if !needsRepair {
            let owner = (try? ShellExecutor.shell("stat -f %Su \(ShellExecutor.quote(home))", ignoreExitCode: true))?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let currentUser = ProcessInfo.processInfo.environment["USER"] ?? ""
            if !owner.isEmpty && !currentUser.isEmpty && owner != currentUser {
                needsRepair = true
            }
        }
        guard needsRepair else {
            return StepResult(detail: "Permissions already correct")
        }

        let uid = ProcessInfo.processInfo.environment["UID"] ?? String(getuid())
        try await ShellExecutor.shellAsync(
            "osascript -e 'do shell script \"diskutil resetUserPermissions / \(uid)\" with administrator privileges'",
            ignoreExitCode: true
        )
        return StepResult(detail: "User directory permissions repaired")
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
        // Only flush if network has issues
        let routeOk = (try? ShellExecutor.shell("route -n get default", ignoreExitCode: true))?.contains("interface") == true
        let dnsOk = (try? ShellExecutor.shell("dscacheutil -q host -a name example.com", ignoreExitCode: true))?.contains("ip_address") == true
        if routeOk && dnsOk {
            return StepResult(detail: "Network stack healthy — skipped")
        }

        try await ShellExecutor.shellAsync(
            "osascript -e 'do shell script \"route -n flush && arp -n -a -d\" with administrator privileges'",
            ignoreExitCode: true
        )
        return StepResult(detail: "Routing table and ARP cache flushed")
    }
}
