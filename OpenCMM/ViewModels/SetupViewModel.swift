import SwiftUI

@MainActor
class SetupViewModel: ObservableObject {
    struct SetupTool: Identifiable {
        let info: DependencyManager.ToolInfo
        let module: String
        let icon: String
        var isInstalled: Bool = false
        var isSelected: Bool = false
        var installState: InstallState = .idle

        var id: String { info.id }
    }

    enum InstallState {
        case idle, installing, done, failed
    }

    @Published var tools: [SetupTool] = []
    @Published var hasHomebrew = false
    @Published var isInstalling = false
    @Published var installProgress: Double = 0
    @Published var installStatus = ""
    @Published var errorMessage: String?
    @Published var isInstallingHomebrew = false
    @Published var homebrewInstallError: String?

    private let dependencyManager = DependencyManager.shared

    var selectedCount: Int {
        tools.filter { $0.isSelected && !$0.isInstalled }.count
    }

    func checkStatus() async {
        hasHomebrew = await dependencyManager.isHomebrewInstalled

        let toolDefs: [(DependencyManager.ToolInfo, String, String)] = [
            (.clamav,  "Security",   "shield"),
            (.osquery, "Security",   "magnifyingglass"),
            (.mas,     "Updates",    "arrow.down.circle"),
            (.fclones, "Duplicates", "doc.on.doc"),
            (.czkawka, "Duplicates", "photo.on.rectangle"),
            (.gdu,     "Disk Map",   "circle.grid.cross"),
        ]

        var result: [SetupTool] = []
        for (info, module, icon) in toolDefs {
            let installed = await dependencyManager.isInstalled(info)
            result.append(SetupTool(
                info: info,
                module: module,
                icon: icon,
                isInstalled: installed,
                isSelected: !installed  // Pre-select tools that aren't installed
            ))
        }
        tools = result
    }

    func toggle(_ id: String) {
        guard let idx = tools.firstIndex(where: { $0.id == id }) else { return }
        guard !tools[idx].isInstalled else { return }
        tools[idx].isSelected.toggle()
    }

    func installHomebrew() async {
        isInstallingHomebrew = true
        homebrewInstallError = nil

        do {
            try await dependencyManager.installHomebrew()
            // The official installer runs in Terminal — poll for completion
            await pollForHomebrew()
        } catch {
            homebrewInstallError = error.localizedDescription
        }

        isInstallingHomebrew = false
    }

    private func pollForHomebrew() async {
        if await dependencyManager.waitForHomebrewInstall() {
            hasHomebrew = true
            await checkStatus()
        } else {
            homebrewInstallError = "Homebrew not detected. Complete the install in Terminal, then refresh."
        }
    }

    func installSelected(completion: @escaping () -> Void) async {
        let toInstall = tools.enumerated().filter { $0.element.isSelected && !$0.element.isInstalled }
        guard !toInstall.isEmpty else {
            completion()
            return
        }

        isInstalling = true
        installProgress = 0
        errorMessage = nil
        var failures: [String] = []

        for (i, (idx, tool)) in toInstall.enumerated() {
            tools[idx].installState = .installing
            installStatus = "Installing \(tool.info.name)..."
            installProgress = Double(i) / Double(toInstall.count)

            do {
                try await dependencyManager.install(tool.info)
                tools[idx].installState = .done
                tools[idx].isInstalled = true
                tools[idx].isSelected = false
            } catch {
                tools[idx].installState = .failed
                failures.append("\(tool.info.name): \(error.localizedDescription)")
            }
        }

        installProgress = 1.0
        isInstalling = false

        if !failures.isEmpty {
            errorMessage = "Some tools failed to install: \(failures.joined(separator: "; "))"
            installStatus = "Completed with errors"
        } else {
            installStatus = "All tools installed"
            // Brief pause so user sees completion, then proceed
            try? await Task.sleep(nanoseconds: AppConstants.Timing.completionDelay)
            completion()
        }
    }
}
