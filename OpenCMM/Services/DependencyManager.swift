import Foundation

/// Manages optional external tool dependencies.
/// All tools are installed via Homebrew with pinned versions.
/// A manifest tracks what OpenCMM installed for clean uninstall.
actor DependencyManager {
    static let shared = DependencyManager()

    /// Manifest directory for tracking our installs.
    static let dataDir: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.opencmm"
    }()

    private static let manifestPath = "\(dataDir)/manifest.json"

    struct ToolInfo: Identifiable {
        let id: String
        let name: String
        let description: String
        let brewPackage: String
        let isCask: Bool
        let testedVersion: String

        static let clamav = ToolInfo(id: "clamav", name: "ClamAV", description: "Industry-standard antivirus engine", brewPackage: "clamav", isCask: false, testedVersion: "1.5.2")
        static let fclones = ToolInfo(id: "fclones", name: "fclones", description: "High-performance duplicate file finder", brewPackage: "fclones", isCask: false, testedVersion: "0.35.0")
        static let osquery = ToolInfo(id: "osquery", name: "osquery", description: "SQL-powered system auditing", brewPackage: "osquery", isCask: true, testedVersion: "5.22.1")
        static let mactop = ToolInfo(id: "mactop", name: "mactop", description: "Apple Silicon performance monitor", brewPackage: "mactop", isCask: false, testedVersion: "0.2.7")
        static let mas = ToolInfo(id: "mas", name: "mas", description: "Mac App Store CLI", brewPackage: "mas", isCask: false, testedVersion: "6.0.1")
        static let czkawka = ToolInfo(id: "czkawka", name: "czkawka", description: "Similar images, videos & music finder", brewPackage: "czkawka", isCask: false, testedVersion: "11.0.1")
        static let gdu = ToolInfo(id: "gdu", name: "gdu", description: "Fast disk usage analyzer", brewPackage: "gdu", isCask: false, testedVersion: "5.35.0")
        static let dust = ToolInfo(id: "dust", name: "dust", description: "Quick disk usage overview", brewPackage: "dust", isCask: false, testedVersion: "1.2.4")

        static let all: [ToolInfo] = [.clamav, .fclones, .osquery, .mactop, .mas, .czkawka, .gdu, .dust]
    }

    struct ToolStatus {
        let info: ToolInfo
        let isInstalled: Bool
        let path: String?
        let version: String?
        let managedByUs: Bool
    }

    // MARK: - Manifest (tracks what we installed)

    private struct Manifest: Codable {
        var tools: [String: ManagedTool] = [:]

        struct ManagedTool: Codable {
            let installedAt: Date
            let version: String?
        }
    }

    private func loadManifest() -> Manifest {
        guard let data = FileManager.default.contents(atPath: Self.manifestPath),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else {
            return Manifest()
        }
        return manifest
    }

    private func saveManifest(_ manifest: Manifest) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(manifest) else { return }
        try? FileManager.default.createDirectory(atPath: Self.dataDir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: Self.manifestPath, contents: data)
    }

    func isManagedByUs(_ tool: ToolInfo) -> Bool {
        loadManifest().tools[tool.id] != nil
    }

    // MARK: - Tool Detection

    private func execName(for tool: ToolInfo) -> String {
        switch tool.id {
        case "clamav": return "clamscan"
        case "osquery": return "osqueryi"
        case "czkawka": return "czkawka_cli"
        default: return tool.id
        }
    }

    func status(for tool: ToolInfo) -> ToolStatus {
        let name = execName(for: tool)
        let managed = isManagedByUs(tool)
        if let path = findExecutable(name) {
            let version = getVersion(tool: tool, path: path)
            return ToolStatus(info: tool, isInstalled: true, path: path, version: version, managedByUs: managed)
        }
        return ToolStatus(info: tool, isInstalled: false, path: nil, version: nil, managedByUs: false)
    }

    func allStatuses() -> [ToolStatus] {
        ToolInfo.all.map { status(for: $0) }
    }

    func isInstalled(_ tool: ToolInfo) -> Bool {
        status(for: tool).isInstalled
    }

    func path(for tool: ToolInfo) -> String? {
        status(for: tool).path
    }

    var isHomebrewInstalled: Bool {
        findExecutable("brew") != nil
    }

    // MARK: - Installation via Homebrew

    func install(_ tool: ToolInfo) async throws {
        guard isHomebrewInstalled else {
            throw DependencyError.homebrewRequired
        }

        // If already installed but not by us, just use it — don't claim ownership
        let current = status(for: tool)
        if current.isInstalled && !current.managedByUs {
            return
        }

        let cmd = tool.isCask
            ? "brew install --cask \(tool.brewPackage)"
            : "brew install \(tool.brewPackage)"
        try ShellExecutor.shell(cmd)

        // Pin to prevent auto-upgrade
        if !tool.isCask {
            try? ShellExecutor.shell("brew pin \(tool.brewPackage)")
        }

        // Post-install setup for ClamAV
        if tool.id == "clamav" {
            setupClamAV()
        }

        // Record in manifest
        let version = status(for: tool).version
        var manifest = loadManifest()
        manifest.tools[tool.id] = Manifest.ManagedTool(installedAt: Date(), version: version)
        saveManifest(manifest)
    }

    // MARK: - Uninstall

    func uninstall(_ tool: ToolInfo) throws {
        guard isHomebrewInstalled else { return }
        guard isManagedByUs(tool) else { return }

        if !tool.isCask {
            try? ShellExecutor.shell("brew unpin \(tool.brewPackage)")
        }
        try ShellExecutor.shell(
            tool.isCask
                ? "brew uninstall --cask \(tool.brewPackage)"
                : "brew uninstall \(tool.brewPackage)"
        )

        var manifest = loadManifest()
        manifest.tools.removeValue(forKey: tool.id)
        saveManifest(manifest)
    }

    /// Remove all tools we installed. Called during app uninstall.
    func uninstallAll() {
        let manifest = loadManifest()
        for toolId in manifest.tools.keys {
            if let tool = ToolInfo.all.first(where: { $0.id == toolId }) {
                try? uninstall(tool)
            }
        }
        // Clean up manifest directory
        try? FileManager.default.removeItem(atPath: Self.dataDir)
    }

    // MARK: - Helpers

    private func setupClamAV() {
        let configPaths = [
            "/opt/homebrew/etc/clamav/freshclam.conf",
            "/usr/local/etc/clamav/freshclam.conf"
        ]
        for configPath in configPaths {
            let samplePath = configPath + ".sample"
            if !FileUtils.exists(configPath), FileUtils.exists(samplePath) {
                _ = try? ShellExecutor.shell("cp '\(samplePath)' '\(configPath)'")
                _ = try? ShellExecutor.shell("sed -i '' 's/^Example/#Example/' '\(configPath)'")
            }
        }
    }

    private func getVersion(tool: ToolInfo, path: String) -> String? {
        let cmd: String
        switch tool.id {
        case "mas": cmd = "'\(path)' version"
        default: cmd = "'\(path)' --version"
        }
        guard let output = try? ShellExecutor.shell(cmd) else { return nil }
        return output.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespaces)
    }

    private func findExecutable(_ name: String) -> String? {
        let searchPaths = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
        ]
        for path in searchPaths {
            if FileUtils.exists(path) { return path }
        }
        if let result = try? ShellExecutor.shell("which \(name)"),
           !result.isEmpty, !result.contains("not found") {
            return result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}

enum DependencyError: LocalizedError {
    case homebrewRequired
    case toolNotInstalled(String)
    case installFailed(String)

    var errorDescription: String? {
        switch self {
        case .homebrewRequired:
            return "Homebrew is required to install tools. Visit https://brew.sh"
        case .toolNotInstalled(let tool):
            return "\(tool) is not installed."
        case .installFailed(let msg):
            return "Installation failed: \(msg)"
        }
    }
}
