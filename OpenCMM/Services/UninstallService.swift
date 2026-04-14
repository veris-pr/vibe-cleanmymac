import Foundation
import os
import AppKit

private let logger = Logger(subsystem: "com.opencmm.app", category: "UninstallService")

/// Discovers installed apps and their leftover files for complete removal.
actor UninstallService {
    private let home = FileUtils.homeDirectory()

    // MARK: - App Discovery

    func listApps() async -> [InstalledApp] {
        let appDirs = ["/Applications", "\(home)/Applications"]
        var apps: [InstalledApp] = []

        for dir in appDirs {
            let contents = FileUtils.contentsOfDirectory(dir)
            for item in contents where item.hasSuffix(".app") {
                let appPath = "\(dir)/\(item)"
                if let app = inspectApp(at: appPath) {
                    apps.append(app)
                }
            }
        }

        logger.info("Found \(apps.count) installed applications")
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Leftover Scanning

    func findLeftovers(for app: InstalledApp) async -> [AppLeftover] {
        var leftovers: [AppLeftover] = []
        let bundleId = app.bundleIdentifier
        let appName = app.name

        // Derive search terms from bundle ID and app name
        let searchTerms = buildSearchTerms(bundleId: bundleId, appName: appName)

        // Application Support
        leftovers += scanDirectory(
            "\(home)/Library/Application Support",
            matching: searchTerms,
            category: .appSupport
        )

        // Caches
        leftovers += scanDirectory(
            "\(home)/Library/Caches",
            matching: searchTerms,
            category: .caches
        )

        // Preferences
        let prefsDir = "\(home)/Library/Preferences"
        for file in FileUtils.contentsOfDirectory(prefsDir) {
            if searchTerms.contains(where: { file.localizedCaseInsensitiveContains($0) }) {
                let path = "\(prefsDir)/\(file)"
                leftovers.append(AppLeftover(path: path, category: .preferences, size: FileUtils.fileSize(at: path)))
            }
        }

        // ByHost preferences (machine-specific prefs like com.app.id.XXXX.plist)
        let byHostDir = "\(home)/Library/Preferences/ByHost"
        for file in FileUtils.contentsOfDirectory(byHostDir) {
            if searchTerms.contains(where: { file.localizedCaseInsensitiveContains($0) }) {
                let path = "\(byHostDir)/\(file)"
                leftovers.append(AppLeftover(path: path, category: .preferences, size: FileUtils.fileSize(at: path)))
            }
        }

        // Logs
        leftovers += scanDirectory(
            "\(home)/Library/Logs",
            matching: searchTerms,
            category: .logs
        )

        // Containers (sandboxed apps)
        leftovers += scanDirectory(
            "\(home)/Library/Containers",
            matching: [bundleId],
            category: .containers
        )

        // Group Containers
        leftovers += scanGroupContainers(bundleId: bundleId)

        // Crash Reports (user-level)
        leftovers += scanDirectory(
            "\(home)/Library/Logs/DiagnosticReports",
            matching: searchTerms,
            category: .crashReports
        )

        // Saved Application State
        let savedState = "\(home)/Library/Saved Application State/\(bundleId).savedState"
        if FileUtils.exists(savedState) {
            leftovers.append(AppLeftover(
                path: savedState, category: .savedState,
                size: FileUtils.directorySize(at: savedState)
            ))
        }

        // HTTPStorages
        leftovers += scanDirectory(
            "\(home)/Library/HTTPStorages",
            matching: searchTerms,
            category: .other
        )

        // WebKit data
        leftovers += scanDirectory(
            "\(home)/Library/WebKit",
            matching: searchTerms,
            category: .other
        )

        // Launch Agents (user-level)
        let launchAgentsDir = "\(home)/Library/LaunchAgents"
        for file in FileUtils.contentsOfDirectory(launchAgentsDir) {
            if file.localizedCaseInsensitiveContains(bundleId) ||
                searchTerms.contains(where: { file.localizedCaseInsensitiveContains($0) }) {
                let path = "\(launchAgentsDir)/\(file)"
                leftovers.append(AppLeftover(path: path, category: .launchItems, size: FileUtils.fileSize(at: path)))
            }
        }

        logger.info("Found \(leftovers.count) leftovers for \(app.name)")
        return leftovers.filter { $0.size > 0 }
    }

    // MARK: - Running App Detection

    /// Check if an app is currently running by its bundle identifier.
    func isAppRunning(_ app: InstalledApp) -> Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier).first != nil
    }

    // MARK: - Uninstall

    func uninstall(app: InstalledApp, leftovers: [AppLeftover]) async -> (removedApp: Bool, removedLeftovers: Int, freedBytes: Int64) {
        var removedLeftovers = 0
        var freedBytes: Int64 = 0
        let bundleId = app.bundleIdentifier

        // 1. Quit the app if running
        await quitApp(bundleId: bundleId)

        // 2. Unload Launch Agents for this app
        await unloadLaunchAgents(bundleId: bundleId)

        // 3. Deregister from LaunchServices (clears Spotlight/Open With)
        await deregisterFromLaunchServices(appPath: app.path)

        // 4. Remove leftover files
        for leftover in leftovers {
            do {
                try FileUtils.moveToTrash(leftover.path)
                removedLeftovers += 1
                freedBytes += leftover.size
                logger.info("Removed leftover: \(leftover.path)")
            } catch {
                logger.warning("Failed to remove leftover \(leftover.path): \(error.localizedDescription)")
            }
        }

        // 5. Remove the app itself (brew cask or manual)
        var removedApp = false
        if let caskName = app.brewCaskName {
            // Use brew uninstall --cask --zap for brew-managed apps
            removedApp = await uninstallBrewCask(caskName: caskName, appPath: app.path)
            if removedApp {
                freedBytes += app.size
            }
        } else {
            do {
                try FileUtils.moveToTrash(app.path)
                removedApp = true
                freedBytes += app.size
                logger.info("Moved app to trash: \(app.path)")
            } catch {
                logger.error("Failed to remove app \(app.path): \(error.localizedDescription)")
            }
        }

        // 6. Post-removal cleanup (only if app was removed)
        if removedApp {
            await deleteDefaultsDomain(bundleId: bundleId)
            await removeFromDock(appPath: app.path)
        }

        return (removedApp, removedLeftovers, freedBytes)
    }

    // MARK: - Pre/Post Uninstall Helpers

    /// Gracefully quit a running app via its bundle identifier.
    private func quitApp(bundleId: String) async {
        await MainActor.run {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleId) {
                app.terminate()
            }
        }
        // Brief wait for process to exit
        try? await Task.sleep(nanoseconds: 500_000_000)
    }

    /// Unload user-level Launch Agents matching the bundle identifier.
    private func unloadLaunchAgents(bundleId: String) async {
        let launchAgentsDir = "\(home)/Library/LaunchAgents"
        for file in FileUtils.contentsOfDirectory(launchAgentsDir) {
            if file.localizedCaseInsensitiveContains(bundleId) {
                let plistPath = "\(launchAgentsDir)/\(file)"
                _ = try? await ShellExecutor.shellAsync("launchctl unload \(ShellExecutor.quote(plistPath))")
            }
        }
    }

    /// Deregister the app bundle from LaunchServices to clear stale Spotlight and Open With entries.
    private func deregisterFromLaunchServices(appPath: String) async {
        let lsregisterPaths = [
            "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister",
            "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        ]
        for path in lsregisterPaths {
            if FileUtils.exists(path) {
                _ = try? await ShellExecutor.shellAsync("\(ShellExecutor.quote(path)) -u \(ShellExecutor.quote(appPath))")
                return
            }
        }
    }

    /// Delete the defaults domain for a bundle ID (removes preferences from defaults system).
    private func deleteDefaultsDomain(bundleId: String) async {
        // Validate bundle ID format to prevent injection
        let validBundleId = bundleId.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == "_" }
        guard validBundleId, !bundleId.isEmpty else { return }

        _ = try? await ShellExecutor.shellAsync("defaults delete \(ShellExecutor.quote(bundleId))")
    }

    /// Remove uninstalled app from the macOS Dock.
    private func removeFromDock(appPath: String) async {
        // Restart the Dock process — it automatically removes entries for apps that no longer exist
        _ = try? await ShellExecutor.shellAsync("killall Dock 2>/dev/null; true")
    }

    // MARK: - Brew Cask Detection

    /// Multi-stage brew cask detection (fast → slow, deterministic → heuristic).
    /// Returns the cask token if the app is Homebrew-managed, nil otherwise.
    private func detectBrewCask(appPath: String) -> String? {
        let fm = FileManager.default

        // Stage 1: Resolve symlink and check if inside Caskroom
        if let resolved = try? fm.destinationOfSymbolicLink(atPath: appPath) {
            if let token = extractCaskToken(from: resolved) {
                return token
            }
        }

        // Stage 1b: Also try resolving the real path (for indirect symlinks)
        let realPath = URL(fileURLWithPath: appPath).resolvingSymlinksInPath().path
        if let token = extractCaskToken(from: realPath) {
            return token
        }

        // Stage 2: Search Caskroom for matching .app bundle name
        let appBundleName = (appPath as NSString).lastPathComponent
        let caskrooms = ["/opt/homebrew/Caskroom", "/usr/local/Caskroom"]
        var foundTokens: Set<String> = []

        for caskroom in caskrooms {
            guard fm.fileExists(atPath: caskroom) else { continue }
            // Look for .app bundles inside Caskroom/<token>/<version>/
            if let tokens = try? fm.contentsOfDirectory(atPath: caskroom) {
                for token in tokens {
                    let tokenPath = "\(caskroom)/\(token)"
                    if let versions = try? fm.contentsOfDirectory(atPath: tokenPath) {
                        for version in versions {
                            let appInCask = "\(tokenPath)/\(version)/\(appBundleName)"
                            if fm.fileExists(atPath: appInCask) {
                                foundTokens.insert(token)
                            }
                        }
                    }
                }
            }
        }

        // Only succeed if exactly one cask matches (avoid wrong uninstall)
        if foundTokens.count == 1, let token = foundTokens.first {
            return token
        }

        return nil
    }

    /// Extract cask token from a Caskroom path.
    private func extractCaskToken(from path: String) -> String? {
        // Path must be inside Caskroom: /opt/homebrew/Caskroom/<token>/... or /usr/local/Caskroom/<token>/...
        let prefixes = ["/opt/homebrew/Caskroom/", "/usr/local/Caskroom/"]
        for prefix in prefixes {
            if path.hasPrefix(prefix) {
                let remainder = String(path.dropFirst(prefix.count))
                let token = remainder.components(separatedBy: "/").first ?? ""
                // Validate: cask tokens are lowercase alphanumeric with hyphens
                if !token.isEmpty, token.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) {
                    return token
                }
            }
        }
        return nil
    }

    /// Uninstall a Homebrew cask using `brew uninstall --cask --zap`.
    private func uninstallBrewCask(caskName: String, appPath: String) async -> Bool {
        logger.info("Uninstalling brew cask: \(caskName)")
        let result = try? await ShellExecutor.shellAsync(
            "HOMEBREW_NO_ENV_HINTS=1 HOMEBREW_NO_AUTO_UPDATE=1 NONINTERACTIVE=1 brew uninstall --cask --zap \(ShellExecutor.quote(caskName))"
        )

        let success = result != nil && !FileUtils.exists(appPath)
        if success {
            logger.info("Successfully uninstalled brew cask: \(caskName)")
        } else {
            // Fallback: try manual removal if brew uninstall failed
            logger.warning("brew uninstall --cask --zap failed for \(caskName), falling back to manual removal")
            do {
                try FileUtils.moveToTrash(appPath)
                return true
            } catch {
                logger.error("Manual fallback also failed for \(appPath): \(error.localizedDescription)")
                return false
            }
        }
        return success
    }

    // MARK: - Private Helpers

    private func inspectApp(at path: String) -> InstalledApp? {
        let bundle = Bundle(path: path)
        let name = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? ((path as NSString).lastPathComponent as NSString).deletingPathExtension

        let bundleId = bundle?.bundleIdentifier ?? name.lowercased().replacingOccurrences(of: " ", with: ".")
        let size = FileUtils.directorySize(at: path)

        // Load icon from app bundle
        let icon = NSWorkspace.shared.icon(forFile: path)

        // Detect brew cask
        let caskName = detectBrewCask(appPath: path)

        return InstalledApp(
            name: name,
            bundleIdentifier: bundleId,
            path: path,
            icon: icon,
            size: size,
            brewCaskName: caskName
        )
    }

    private func buildSearchTerms(bundleId: String, appName: String) -> [String] {
        var terms: Set<String> = []
        terms.insert(bundleId)
        terms.insert(appName)

        // Extract org name from bundle ID: com.company.AppName → company
        let parts = bundleId.components(separatedBy: ".")
        if parts.count >= 3 {
            terms.insert(parts[1]) // company/org name
            terms.insert(parts.dropFirst(2).joined(separator: ".")) // app part
        }

        // Filter out generic terms that would cause false positives
        let generic: Set<String> = ["com", "app", "mac", "macos", "the", "desktop"]
        return Array(terms.filter { $0.count > 2 && !generic.contains($0.lowercased()) })
    }

    private func scanDirectory(_ dirPath: String, matching terms: [String], category: AppLeftover.LeftoverCategory) -> [AppLeftover] {
        var results: [AppLeftover] = []
        for item in FileUtils.contentsOfDirectory(dirPath) {
            if terms.contains(where: { item.localizedCaseInsensitiveContains($0) }) {
                let fullPath = "\(dirPath)/\(item)"
                let size = FileUtils.isDirectory(fullPath)
                    ? FileUtils.directorySize(at: fullPath)
                    : FileUtils.fileSize(at: fullPath)
                results.append(AppLeftover(path: fullPath, category: category, size: size))
            }
        }
        return results
    }

    private func scanGroupContainers(bundleId: String) -> [AppLeftover] {
        let groupDir = "\(home)/Library/Group Containers"
        var results: [AppLeftover] = []
        for item in FileUtils.contentsOfDirectory(groupDir) {
            if item.localizedCaseInsensitiveContains(bundleId) {
                let fullPath = "\(groupDir)/\(item)"
                results.append(AppLeftover(
                    path: fullPath, category: .containers,
                    size: FileUtils.directorySize(at: fullPath)
                ))
            }
        }
        return results
    }

    // MARK: - Homebrew Packages

    func listBrewPackages() async -> [BrewPackage] {
        guard await DependencyManager.shared.isHomebrewInstalled else { return [] }

        // Get leaves (top-level, not depended on by others)
        let leavesStr = (try? await ShellExecutor.shellAsync("brew leaves")) ?? ""
        let leaves = Set(leavesStr.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })

        // Get full info via JSON
        guard let jsonStr = try? await ShellExecutor.shellAsync("brew info --json=v2 --installed") else { return [] }
        guard let data = jsonStr.data(using: .utf8) else { return [] }

        struct BrewJSON: Decodable {
            let formulae: [Formula]
            struct Formula: Decodable {
                let name: String
                let desc: String?
                let dependencies: [String]?
                let installed: [Installed]?
                struct Installed: Decodable {
                    let version: String
                    let installed_on_request: Bool
                }
            }
        }

        guard let brew = try? JSONDecoder().decode(BrewJSON.self, from: data) else { return [] }

        // Detect cellar location
        let cellarBase: String
        if FileManager.default.fileExists(atPath: "/opt/homebrew/Cellar") {
            cellarBase = "/opt/homebrew/Cellar"
        } else {
            cellarBase = "/usr/local/Cellar"
        }

        var packages: [BrewPackage] = []
        for formula in brew.formulae {
            guard let inst = formula.installed?.first else { continue }
            let cellarPath = "\(cellarBase)/\(formula.name)"
            let size = FileUtils.directorySize(at: cellarPath)

            packages.append(BrewPackage(
                id: formula.name,
                name: formula.name,
                version: inst.version,
                description: formula.desc ?? "",
                size: size,
                dependencies: formula.dependencies ?? [],
                isLeaf: leaves.contains(formula.name),
                installedOnRequest: inst.installed_on_request
            ))
        }

        logger.info("Found \(packages.count) Homebrew packages (\(leaves.count) leaves)")
        
        // Build reverse-dependency map (dependents)
        let packageNames = Set(packages.map(\.name))
        var dependentsMap: [String: [String]] = [:]
        for pkg in packages {
            for dep in pkg.dependencies where packageNames.contains(dep) {
                dependentsMap[dep, default: []].append(pkg.name)
            }
        }
        for i in packages.indices {
            packages[i].dependents = (dependentsMap[packages[i].name] ?? []).sorted()
        }

        return packages.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func uninstallBrewPackage(_ pkg: BrewPackage) async throws {
        try await ShellExecutor.shellAsync("brew uninstall \(ShellExecutor.quote(pkg.name))")
    }

    /// Remove orphaned Homebrew dependencies no longer needed by any installed formula.
    func brewAutoremove() async {
        _ = try? await ShellExecutor.shellAsync("HOMEBREW_NO_AUTO_UPDATE=1 brew autoremove")
    }
}
