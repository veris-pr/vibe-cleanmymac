import SwiftUI

@MainActor
class SpeedViewModel: ObservableObject {
    @Published var loginItems: [LoginItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hostname: String = "Mac"
    @Published var osVersion: String = ""
    @Published var uptime: TimeInterval = 0

    var scanStore: ScanStore?

    private let service = PerformanceService()

    func loadFromStore() {
        // Startup items are loaded fresh each time
    }

    func loadData() async {
        isLoading = true
        errorMessage = nil
        loginItems = await service.getLoginItems()
        hostname = Host.current().localizedName ?? "Mac"
        osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        uptime = ProcessInfo.processInfo.systemUptime
        isLoading = false
        updateSummary()
    }

    func disableLoginItem(_ item: LoginItem) async {
        do {
            try await service.disableLoginItem(path: item.path)
            if let index = loginItems.firstIndex(where: { $0.id == item.id }) {
                loginItems[index].isEnabled = false
            }
        } catch {
            errorMessage = "Failed to disable \(item.name): \(error.localizedDescription)"
        }
    }

    func enableLoginItem(_ item: LoginItem) async {
        do {
            try await service.enableLoginItem(path: item.path)
            if let index = loginItems.firstIndex(where: { $0.id == item.id }) {
                loginItems[index].isEnabled = true
            }
        } catch {
            errorMessage = "Failed to enable \(item.name): \(error.localizedDescription)"
        }
    }

    private func updateSummary() {
        let issues = loginItems.isEmpty ? [String]() : ["\(loginItems.count) startup item\(loginItems.count == 1 ? "" : "s")"]
        let summary = ModuleScanSummary(
            module: .speed,
            itemCount: loginItems.count,
            totalSize: 0,
            issues: issues,
            timestamp: Date()
        )
        scanStore?.updateSummary(summary)
    }
}
