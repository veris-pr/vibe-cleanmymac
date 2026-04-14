import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    struct ToolRow: Identifiable {
        let id: String
        let name: String
        let description: String
        let module: String
        let testedVersion: String
        let isCask: Bool
        var isInstalled: Bool
        var version: String?
        var source: DependencyManager.InstallSource
        var isInstalling: Bool = false
        var isUninstalling: Bool = false
        var statusText: String?
        var error: String?

        var managedByUs: Bool { source == .managedByUs }

        init(status: DependencyManager.ToolStatus, module: String) {
            self.id = status.info.id
            self.name = status.info.name
            self.description = status.info.description
            self.module = module
            self.testedVersion = status.info.testedVersion
            self.isCask = status.info.isCask
            self.isInstalled = status.isInstalled
            self.version = status.version
            self.source = status.source
        }
    }

    @Published var tools: [ToolRow] = []
    @Published var hasHomebrew = false
    @Published var errorMessage: String?
    @Published var isRefreshing = false
    @Published var isInstallingHomebrew = false
    @Published var homebrewInstallError: String?
    @Published var showUninstallConfirmation = false
    @Published var isUninstallingSelf = false

    private let dependencyManager = DependencyManager.shared

    private let moduleMap: [String: String] = [
        "clamav": "Security",
        "osquery": "Security",
        "mas": "Updates",
        "fclones": "Duplicates",
        "czkawka": "Duplicates",
        "macmon": "Boost",
        "mole": "Boost",
    ]

    func refresh() async {
        isRefreshing = true
        hasHomebrew = await dependencyManager.isHomebrewInstalled
        let statuses = await dependencyManager.allStatuses()
        tools = statuses.map { ToolRow(status: $0, module: moduleMap[$0.info.id] ?? "") }
        isRefreshing = false
    }

    func installHomebrew() async {
        isInstallingHomebrew = true
        homebrewInstallError = nil

        do {
            try await dependencyManager.installHomebrew()
            if await dependencyManager.waitForHomebrewInstall() {
                hasHomebrew = true
                await refresh()
                isInstallingHomebrew = false
                return
            }
            homebrewInstallError = "Homebrew not detected. Complete the install in Terminal, then refresh."
        } catch {
            homebrewInstallError = error.localizedDescription
        }

        isInstallingHomebrew = false
    }

    func install(_ id: String) async {
        guard let idx = tools.firstIndex(where: { $0.id == id }) else { return }
        let info = DependencyManager.ToolInfo.all.first { $0.id == id }
        guard let info else { return }

        tools[idx].isInstalling = true
        tools[idx].error = nil
        tools[idx].statusText = "Installing via Homebrew..."
        errorMessage = nil

        do {
            try await dependencyManager.install(info)
            let status = await dependencyManager.status(for: info)
            tools[idx].isInstalled = true
            tools[idx].version = status.version
            tools[idx].source = status.source
            tools[idx].statusText = "Installed successfully"

            // Clear success message after a moment
            let capturedId = id
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: AppConstants.Timing.statusMessageDelay)
                if let i = tools.firstIndex(where: { $0.id == capturedId }) {
                    tools[i].statusText = nil
                }
            }
        } catch {
            tools[idx].error = error.localizedDescription
            tools[idx].statusText = nil
        }
        tools[idx].isInstalling = false
    }

    func uninstall(_ id: String) async {
        guard let idx = tools.firstIndex(where: { $0.id == id }) else { return }
        let info = DependencyManager.ToolInfo.all.first { $0.id == id }
        guard let info else { return }

        tools[idx].isUninstalling = true
        tools[idx].error = nil
        tools[idx].statusText = "Removing..."
        errorMessage = nil

        do {
            try await dependencyManager.uninstall(info)
            tools[idx].isInstalled = false
            tools[idx].version = nil
            tools[idx].source = .notInstalled
            tools[idx].statusText = nil
        } catch {
            tools[idx].error = error.localizedDescription
            tools[idx].statusText = nil
        }
        tools[idx].isUninstalling = false
    }

    // MARK: - Self-Uninstall

    /// Number of managed tools that would be removed.
    var managedToolCount: Int {
        tools.filter { $0.managedByUs }.count
    }

    func uninstallOpenCMM() async {
        isUninstallingSelf = true

        // 1. Remove tools we installed
        await dependencyManager.uninstallAll()

        // 2. Remove app bundle (move to Trash)
        let appPath = Bundle.main.bundlePath
        do {
            try FileUtils.moveToTrash(appPath)
        } catch {
            // If app bundle removal fails (e.g. running from Xcode), try /Applications
            try? FileUtils.moveToTrash("/Applications/OpenCMM.app")
        }

        // 3. Quit
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApplication.shared.terminate(nil)
        }
    }
}
