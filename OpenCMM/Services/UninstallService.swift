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

        // Crash Reports
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

        logger.info("Found \(leftovers.count) leftovers for \(app.name)")
        return leftovers.filter { $0.size > 0 }
    }

    // MARK: - Uninstall

    func uninstall(app: InstalledApp, leftovers: [AppLeftover]) async -> (removedApp: Bool, removedLeftovers: Int, freedBytes: Int64) {
        var removedLeftovers = 0
        var freedBytes: Int64 = 0

        // Remove leftover files first
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

        // Remove the app itself
        var removedApp = false
        do {
            try FileUtils.moveToTrash(app.path)
            removedApp = true
            freedBytes += app.size
            logger.info("Moved app to trash: \(app.path)")
        } catch {
            logger.error("Failed to remove app \(app.path): \(error.localizedDescription)")
        }

        return (removedApp, removedLeftovers, freedBytes)
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

        return InstalledApp(
            name: name,
            bundleIdentifier: bundleId,
            path: path,
            icon: icon,
            size: size
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
}
