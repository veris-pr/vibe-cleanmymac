import Foundation

/// Manages optional external tool dependencies (ClamAV, fclones).
/// Tools are checked at runtime; modules gracefully degrade if not available.
actor DependencyManager {
    static let shared = DependencyManager()

    struct ToolStatus {
        let isInstalled: Bool
        let path: String?
        let version: String?
    }

    // MARK: - Tool Detection

    func clamavStatus() -> ToolStatus {
        if let path = findExecutable("clamscan") {
            let version = (try? ShellExecutor.shell("\(path) --version"))?.components(separatedBy: "\n").first
            return ToolStatus(isInstalled: true, path: path, version: version)
        }
        return ToolStatus(isInstalled: false, path: nil, version: nil)
    }

    func fclonesStatus() -> ToolStatus {
        if let path = findExecutable("fclones") {
            let version = try? ShellExecutor.shell("\(path) --version")
            return ToolStatus(isInstalled: true, path: path, version: version?.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return ToolStatus(isInstalled: false, path: nil, version: nil)
    }

    func homebrewStatus() -> ToolStatus {
        if let path = findExecutable("brew") {
            return ToolStatus(isInstalled: true, path: path, version: nil)
        }
        return ToolStatus(isInstalled: false, path: nil, version: nil)
    }

    var isHomebrewInstalled: Bool {
        homebrewStatus().isInstalled
    }

    // MARK: - Installation

    func installClamAV() async throws {
        guard isHomebrewInstalled else {
            throw DependencyError.homebrewRequired
        }
        try ShellExecutor.shell("brew install clamav")
        // Initialize freshclam config if needed
        let configPath = "/opt/homebrew/etc/clamav/freshclam.conf"
        let samplePath = "/opt/homebrew/etc/clamav/freshclam.conf.sample"
        if !FileUtils.exists(configPath), FileUtils.exists(samplePath) {
            try ShellExecutor.shell("cp \(samplePath) \(configPath)")
            try ShellExecutor.shell("sed -i '' 's/^Example/#Example/' \(configPath)")
        }
    }

    func installFclones() async throws {
        guard isHomebrewInstalled else {
            throw DependencyError.homebrewRequired
        }
        try ShellExecutor.shell("brew install fclones")
    }

    func updateClamAVDatabase() async throws {
        guard clamavStatus().isInstalled else {
            throw DependencyError.toolNotInstalled("clamav")
        }
        try ShellExecutor.shell("freshclam")
    }

    // MARK: - Helpers

    private func findExecutable(_ name: String) -> String? {
        let searchPaths = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
        ]
        for path in searchPaths {
            if FileUtils.exists(path) { return path }
        }
        // Try which as fallback
        if let result = try? ShellExecutor.shell("which \(name)"),
           !result.isEmpty, !result.contains("not found") {
            return result
        }
        return nil
    }
}

enum DependencyError: LocalizedError {
    case homebrewRequired
    case toolNotInstalled(String)

    var errorDescription: String? {
        switch self {
        case .homebrewRequired:
            return "Homebrew is required to install dependencies. Visit https://brew.sh"
        case .toolNotInstalled(let tool):
            return "\(tool) is not installed."
        }
    }
}
