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
        let prefsDir = NSHomeDirectory() + "/Library/Preferences"
        let fm = FileManager.default
        guard fm.fileExists(atPath: prefsDir) else {
            return StepResult(detail: "All valid")
        }

        var brokenCount = 0
        let files = (try? fm.contentsOfDirectory(atPath: prefsDir)) ?? []
        for file in files where file.hasSuffix(".plist") {
            // Skip Apple system prefs
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
}
