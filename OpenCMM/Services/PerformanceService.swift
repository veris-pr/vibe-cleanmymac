import Foundation

actor PerformanceService {
    private let home = FileUtils.homeDirectory()

    func getLoginItems() async -> [LoginItem] {
        var items: [LoginItem] = []

        // Scan user Launch Agents
        let userAgentsPath = "\(home)/Library/LaunchAgents"
        for file in FileUtils.contentsOfDirectory(userAgentsPath) {
            guard file.hasSuffix(".plist") else { continue }
            items.append(LoginItem(
                name: file.replacingOccurrences(of: ".plist", with: ""),
                path: "\(userAgentsPath)/\(file)",
                kind: .launchAgent,
                isEnabled: true
            ))
        }

        // Scan system Launch Agents
        let systemAgentsPath = "/Library/LaunchAgents"
        for file in FileUtils.contentsOfDirectory(systemAgentsPath) {
            guard file.hasSuffix(".plist") else { continue }
            items.append(LoginItem(
                name: file.replacingOccurrences(of: ".plist", with: ""),
                path: "\(systemAgentsPath)/\(file)",
                kind: .launchAgent,
                isEnabled: true
            ))
        }

        // Scan Launch Daemons
        let daemonsPath = "/Library/LaunchDaemons"
        for file in FileUtils.contentsOfDirectory(daemonsPath) {
            guard file.hasSuffix(".plist") else { continue }
            items.append(LoginItem(
                name: file.replacingOccurrences(of: ".plist", with: ""),
                path: "\(daemonsPath)/\(file)",
                kind: .launchDaemon,
                isEnabled: true
            ))
        }

        return items
    }

    func disableLoginItem(path: String) throws {
        try ShellExecutor.shell("launchctl unload \(ShellExecutor.quote(path))")
    }

    func enableLoginItem(path: String) throws {
        try ShellExecutor.shell("launchctl load \(ShellExecutor.quote(path))")
    }
}
