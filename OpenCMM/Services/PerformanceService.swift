import Foundation

actor PerformanceService {
    private let home = FileUtils.homeDirectory()

    func getLoginItems() async -> [LoginItem] {
        var items: [LoginItem] = []
        items.append(contentsOf: scanLaunchDirectory("\(home)/Library/LaunchAgents", kind: .launchAgent))
        items.append(contentsOf: scanLaunchDirectory("/Library/LaunchAgents", kind: .launchAgent))
        items.append(contentsOf: scanLaunchDirectory("/Library/LaunchDaemons", kind: .launchDaemon))
        return items
    }

    private func scanLaunchDirectory(_ path: String, kind: LoginItemKind) -> [LoginItem] {
        FileUtils.contentsOfDirectory(path)
            .filter { $0.hasSuffix(".plist") }
            .map { file in
                LoginItem(
                    name: file.replacingOccurrences(of: ".plist", with: ""),
                    path: "\(path)/\(file)",
                    kind: kind,
                    isEnabled: true
                )
            }
    }

    func disableLoginItem(path: String) throws {
        try ShellExecutor.shell("launchctl unload \(ShellExecutor.quote(path))")
    }

    func enableLoginItem(path: String) throws {
        try ShellExecutor.shell("launchctl load \(ShellExecutor.quote(path))")
    }
}
