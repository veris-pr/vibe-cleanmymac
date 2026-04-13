import Foundation

/// Integrates mas (Mac App Store CLI) for App Store app management.
actor MasService {
    private let dependencyManager = DependencyManager.shared

    struct AppStoreApp: Identifiable {
        let id: String  // App Store ID
        let name: String
        let currentVersion: String
        let availableVersion: String?
        let isOutdated: Bool
    }

    var isAvailable: Bool {
        get async { await dependencyManager.isInstalled(.mas) }
    }

    func listInstalled() async -> [AppStoreApp] {
        guard let mas = await dependencyManager.path(for: .mas) else { return [] }
        guard let output = try? ShellExecutor.shell("\(ShellExecutor.quote(mas)) list 2>/dev/null") else { return [] }

        // Format: "497799835 Xcode (15.4)"
        return output.components(separatedBy: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }

            let parts = trimmed.split(maxSplits: 1, omittingEmptySubsequences: true, whereSeparator: { $0 == " " })
            guard parts.count == 2 else { return nil }
            let appId = String(parts[0])
            let rest = String(parts[1])

            // Parse "Name (version)"
            if let parenRange = rest.range(of: " (", options: .backwards) {
                let name = String(rest[rest.startIndex..<parenRange.lowerBound])
                var version = String(rest[parenRange.upperBound...])
                if version.hasSuffix(")") { version = String(version.dropLast()) }
                return AppStoreApp(id: appId, name: name, currentVersion: version, availableVersion: nil, isOutdated: false)
            }
            return AppStoreApp(id: appId, name: rest, currentVersion: "unknown", availableVersion: nil, isOutdated: false)
        }
    }

    func listOutdated() async -> [AppStoreApp] {
        guard let mas = await dependencyManager.path(for: .mas) else { return [] }
        guard let output = try? ShellExecutor.shell("\(ShellExecutor.quote(mas)) outdated 2>/dev/null") else { return [] }

        // Format: "497799835 Xcode (15.4 -> 16.0)"
        return output.components(separatedBy: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }

            let parts = trimmed.split(maxSplits: 1, omittingEmptySubsequences: true, whereSeparator: { $0 == " " })
            guard parts.count == 2 else { return nil }
            let appId = String(parts[0])
            let rest = String(parts[1])

            if let parenRange = rest.range(of: " (", options: .backwards) {
                let name = String(rest[rest.startIndex..<parenRange.lowerBound])
                var versionStr = String(rest[parenRange.upperBound...])
                if versionStr.hasSuffix(")") { versionStr = String(versionStr.dropLast()) }

                let versions = versionStr.components(separatedBy: " -> ")
                let current = versions.first ?? "unknown"
                let available = versions.count > 1 ? versions[1] : nil

                return AppStoreApp(id: appId, name: name, currentVersion: current, availableVersion: available, isOutdated: true)
            }
            return AppStoreApp(id: appId, name: rest, currentVersion: "unknown", availableVersion: nil, isOutdated: true)
        }
    }

    func update(appId: String) async throws {
        guard let mas = await dependencyManager.path(for: .mas) else {
            throw DependencyError.toolNotInstalled("mas")
        }
        try ShellExecutor.shell("\(ShellExecutor.quote(mas)) upgrade \(ShellExecutor.quote(appId)) 2>/dev/null")
    }
}
