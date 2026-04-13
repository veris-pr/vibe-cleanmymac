import Foundation

/// Manages optional external tool dependencies.
/// Tools are checked at runtime; modules gracefully degrade if not available.
actor DependencyManager {
    static let shared = DependencyManager()

    struct ToolInfo {
        let id: String
        let name: String
        let description: String
        let brewPackage: String
        let isCask: Bool

        static let clamav = ToolInfo(id: "clamav", name: "ClamAV", description: "Industry-standard antivirus engine", brewPackage: "clamav", isCask: false)
        static let fclones = ToolInfo(id: "fclones", name: "fclones", description: "High-performance duplicate file finder", brewPackage: "fclones", isCask: false)
        static let osquery = ToolInfo(id: "osquery", name: "osquery", description: "SQL-powered system auditing", brewPackage: "osquery", isCask: true)
        static let mactop = ToolInfo(id: "mactop", name: "mactop", description: "Apple Silicon performance monitor", brewPackage: "mactop", isCask: false)
        static let mas = ToolInfo(id: "mas", name: "mas", description: "Mac App Store CLI", brewPackage: "mas", isCask: false)
        static let czkawka = ToolInfo(id: "czkawka", name: "czkawka", description: "Similar images, videos & music finder", brewPackage: "czkawka", isCask: false)
        static let gdu = ToolInfo(id: "gdu", name: "gdu", description: "Fast disk usage analyzer", brewPackage: "gdu", isCask: false)
        static let dust = ToolInfo(id: "dust", name: "dust", description: "Quick disk usage overview", brewPackage: "dust", isCask: false)

        static let all: [ToolInfo] = [.clamav, .fclones, .osquery, .mactop, .mas, .czkawka, .gdu, .dust]
    }

    struct ToolStatus {
        let info: ToolInfo
        let isInstalled: Bool
        let path: String?
        let version: String?
    }

    // MARK: - Tool Detection

    func status(for tool: ToolInfo) -> ToolStatus {
        let execName: String
        switch tool.id {
        case "clamav": execName = "clamscan"
        case "osquery": execName = "osqueryi"
        case "czkawka": execName = "czkawka_cli"
        default: execName = tool.id
        }

        if let path = findExecutable(execName) {
            let version = getVersion(tool: tool, path: path)
            return ToolStatus(info: tool, isInstalled: true, path: path, version: version)
        }
        return ToolStatus(info: tool, isInstalled: false, path: nil, version: nil)
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

    // MARK: - Installation

    func install(_ tool: ToolInfo) async throws {
        guard isHomebrewInstalled else {
            throw DependencyError.homebrewRequired
        }
        let cmd = tool.isCask ? "brew install --cask \(tool.brewPackage)" : "brew install \(tool.brewPackage)"
        try ShellExecutor.shell(cmd)

        // Post-install setup for ClamAV
        if tool.id == "clamav" {
            setupClamAV()
        }
    }

    // MARK: - Helpers

    private func setupClamAV() {
        let configPaths = [
            "/opt/homebrew/etc/clamav/freshclam.conf",
            "/usr/local/etc/clamav/freshclam.conf"
        ]
        let sampleSuffix = ".sample"
        for configPath in configPaths {
            let samplePath = configPath + sampleSuffix
            if !FileUtils.exists(configPath), FileUtils.exists(samplePath) {
                _ = try? ShellExecutor.shell("cp \(samplePath) \(configPath)")
                _ = try? ShellExecutor.shell("sed -i '' 's/^Example/#Example/' \(configPath)")
            }
        }
    }

    private func getVersion(tool: ToolInfo, path: String) -> String? {
        let cmd: String
        switch tool.id {
        case "clamav": cmd = "\(path) --version"
        case "osquery": cmd = "\(path) --version"
        case "mactop": cmd = "\(path) --version"
        case "mas": cmd = "\(path) version"
        case "gdu": cmd = "\(path) --version"
        case "dust": cmd = "\(path) --version"
        case "czkawka": cmd = "\(path) --version"
        default: cmd = "\(path) --version"
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
            return "Homebrew is required to install dependencies. Visit https://brew.sh"
        case .toolNotInstalled(let tool):
            return "\(tool) is not installed."
        case .installFailed(let msg):
            return "Installation failed: \(msg)"
        }
    }
}
