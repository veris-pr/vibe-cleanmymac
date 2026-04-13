import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    struct ToolRow: Identifiable {
        let id: String
        let name: String
        let description: String
        let module: String
        let testedVersion: String
        var isInstalled: Bool
        var version: String?
        var source: DependencyManager.InstallSource
        var isInstalling: Bool = false
        var isUninstalling: Bool = false

        var managedByUs: Bool { source == .managedByUs }

        init(status: DependencyManager.ToolStatus, module: String) {
            self.id = status.info.id
            self.name = status.info.name
            self.description = status.info.description
            self.module = module
            self.testedVersion = status.info.testedVersion
            self.isInstalled = status.isInstalled
            self.version = status.version
            self.source = status.source
        }
    }

    @Published var tools: [ToolRow] = []
    @Published var hasHomebrew = false
    @Published var errorMessage: String?

    private let deps = DependencyManager.shared

    private let moduleMap: [String: String] = [
        "clamav": "Security",
        "osquery": "Security",
        "mactop": "Boost",
        "mas": "Updates",
        "fclones": "Duplicates",
        "czkawka": "Duplicates",
        "gdu": "Disk Map",
        "dust": "Disk Map",
    ]

    func refresh() async {
        hasHomebrew = await deps.isHomebrewInstalled
        let statuses = await deps.allStatuses()
        tools = statuses.map { ToolRow(status: $0, module: moduleMap[$0.info.id] ?? "") }
    }

    func install(_ id: String) async {
        guard let idx = tools.firstIndex(where: { $0.id == id }) else { return }
        let info = DependencyManager.ToolInfo.all.first { $0.id == id }
        guard let info else { return }

        tools[idx].isInstalling = true
        errorMessage = nil

        do {
            try await deps.install(info)
            let status = await deps.status(for: info)
            tools[idx].isInstalled = true
            tools[idx].version = status.version
            tools[idx].source = status.source
        } catch {
            errorMessage = "\(info.name): \(error.localizedDescription)"
        }
        tools[idx].isInstalling = false
    }

    func uninstall(_ id: String) async {
        guard let idx = tools.firstIndex(where: { $0.id == id }) else { return }
        let info = DependencyManager.ToolInfo.all.first { $0.id == id }
        guard let info else { return }

        tools[idx].isUninstalling = true
        errorMessage = nil

        do {
            try await deps.uninstall(info)
            tools[idx].isInstalled = false
            tools[idx].version = nil
            tools[idx].source = .notInstalled
        } catch {
            errorMessage = "\(info.name): \(error.localizedDescription)"
        }
        tools[idx].isUninstalling = false
    }
}
