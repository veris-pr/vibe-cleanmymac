import SwiftUI

@MainActor
class UpdateViewModel: ObservableObject {
    @Published var updates: [AppUpdateInfo] = []
    @Published var isChecking = false
    @Published var isUpdating = false
    @Published var checkComplete = false
    @Published var errorMessage: String?
    @Published var isHomebrewInstalled = false
    @Published var isMasInstalled = false
    @Published var isInstallingHomebrew = false
    @Published var isInstallingMas = false
    @Published var installError: String?
    @Published var showConfirmation = false

    var scanStore: ScanStore?

    private let service = UpdateService()
    private let masService = MasService()
    private let dependencyManager = DependencyManager.shared
    private var scanTask: Task<Void, Never>?

    var updateCount: Int { updates.count }
    var selectedCount: Int { updates.filter(\.isSelected).count }

    func loadFromStore() {
        guard !checkComplete, let store = scanStore, !store.updates.isEmpty else { return }
        updates = store.updates
        checkComplete = true
    }

    func checkDependencies() async {
        isHomebrewInstalled = await dependencyManager.isHomebrewInstalled
        isMasInstalled = await dependencyManager.isInstalled(.mas)
    }

    func installHomebrew() async {
        isInstallingHomebrew = true
        installError = nil
        do {
            try await dependencyManager.installHomebrew()
            if await dependencyManager.waitForHomebrewInstall() {
                isHomebrewInstalled = true
                isInstallingHomebrew = false
                return
            }
            installError = "Homebrew not detected. Complete the install in Terminal, then refresh."
        } catch {
            installError = error.localizedDescription
        }
        isInstallingHomebrew = false
    }

    func installMas() async {
        isInstallingMas = true
        installError = nil
        do {
            try await dependencyManager.install(.mas)
            isMasInstalled = true
        } catch {
            installError = error.localizedDescription
        }
        isInstallingMas = false
    }

    func startCheckForUpdates() {
        scanTask?.cancel()
        scanTask = Task { await checkForUpdates() }
    }

    func cancelCheck() {
        scanTask?.cancel()
        scanTask = nil
        isChecking = false
    }

    private func checkForUpdates() async {
        isChecking = true
        checkComplete = false
        errorMessage = nil
        await checkDependencies()

        var allUpdates: [AppUpdateInfo] = []

        // Homebrew updates
        let brewUpdates = await service.checkForUpdates()
        guard !Task.isCancelled else { return }
        allUpdates.append(contentsOf: brewUpdates)

        // App Store updates via mas
        if isMasInstalled {
            let masOutdated = await masService.listOutdated()
            guard !Task.isCancelled else { return }
            let masUpdates = masOutdated.map { app in
                AppUpdateInfo(
                    name: app.name,
                    currentVersion: app.currentVersion,
                    availableVersion: app.availableVersion ?? "latest",
                    source: .appStore
                )
            }
            allUpdates.append(contentsOf: masUpdates)
        }

        updates = allUpdates
        isChecking = false
        checkComplete = true

        // Update global store
        scanStore?.updates = updates
        let issues = updates.prefix(3).map { "\($0.name) → \($0.availableVersion)" }
        scanStore?.updateSummary(ModuleScanSummary(
            module: .update, itemCount: updates.count, totalSize: 0,
            issues: Array(issues), timestamp: Date()
        ))
    }

    func updateSelected() async {
        isUpdating = true
        errorMessage = nil
        let selected = updates.filter(\.isSelected)
        for app in selected {
            if app.source == .appStore {
                // Use mas for App Store apps — find the ID by name match
                let installed = await masService.listOutdated()
                if let match = installed.first(where: { $0.name == app.name }) {
                    do {
                        try await masService.update(appId: match.id)
                        updates.removeAll { $0.id == app.id }
                    } catch {
                        errorMessage = "Failed to update \(app.name): \(error.localizedDescription)"
                    }
                }
            } else {
                let success = await service.updateApp(app)
                if success {
                    updates.removeAll { $0.id == app.id }
                }
            }
        }
        isUpdating = false
        scanStore?.invalidate(.update)
    }

    func updateSingle(_ app: AppUpdateInfo) async {
        errorMessage = nil
        if app.source == .appStore {
            let installed = await masService.listOutdated()
            if let match = installed.first(where: { $0.name == app.name }) {
                do {
                    try await masService.update(appId: match.id)
                    updates.removeAll { $0.id == app.id }
                } catch {
                    errorMessage = "Failed to update \(app.name): \(error.localizedDescription)"
                }
            }
        } else {
            let success = await service.updateApp(app)
            if success {
                updates.removeAll { $0.id == app.id }
            }
        }
        scanStore?.invalidate(.update)
    }

    func toggleApp(_ id: UUID) {
        if let index = updates.firstIndex(where: { $0.id == id }) {
            updates[index].isSelected.toggle()
        }
    }
}
