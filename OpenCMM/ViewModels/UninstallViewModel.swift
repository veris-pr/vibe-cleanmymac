import SwiftUI

@MainActor
class UninstallViewModel: ObservableObject {
    @Published var apps: [InstalledApp] = []
    @Published var filteredApps: [InstalledApp] = []
    @Published var selectedApp: InstalledApp?
    @Published var leftovers: [AppLeftover] = []
    @Published var isLoading = false
    @Published var isScanning = false
    @Published var isUninstalling = false
    @Published var searchText = ""
    @Published var errorMessage: String?
    @Published var lastFreedSize: Int64 = 0
    @Published var showConfirmation = false
    @Published var sortOrder: SortOrder = .name

    private let service = UninstallService()

    enum SortOrder: String, CaseIterable {
        case name = "Name"
        case size = "Size"
    }

    var totalLeftoverSize: Int64 {
        leftovers.reduce(0) { $0 + $1.size }
    }

    func loadApps() async {
        isLoading = true
        errorMessage = nil
        apps = await service.listApps()
        applyFilter()
        isLoading = false
    }

    func selectApp(_ app: InstalledApp) async {
        selectedApp = app
        isScanning = true
        leftovers = await service.findLeftovers(for: app)
        isScanning = false
    }

    func deselectApp() {
        selectedApp = nil
        leftovers = []
    }

    func uninstallSelected() async {
        guard let app = selectedApp else { return }
        isUninstalling = true
        errorMessage = nil

        let result = await service.uninstall(app: app, leftovers: leftovers)

        if result.removedApp {
            lastFreedSize = result.freedBytes
            apps.removeAll { $0.path == app.path }
            applyFilter()
            selectedApp = nil
            leftovers = []
        } else {
            errorMessage = "Failed to remove \(app.name). It may be in use."
        }

        isUninstalling = false
    }

    func updateSearch(_ text: String) {
        searchText = text
        applyFilter()
    }

    func updateSort(_ order: SortOrder) {
        sortOrder = order
        applyFilter()
    }

    private func applyFilter() {
        var result = apps

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
            }
        }

        switch sortOrder {
        case .name:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .size:
            result.sort { $0.size > $1.size }
        }

        filteredApps = result
    }
}
