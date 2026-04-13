import SwiftUI

@MainActor
class SpeedViewModel: ObservableObject {
    @Published var loginItems: [LoginItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hostname: String = "Mac"
    @Published var osVersion: String = ""
    @Published var uptime: TimeInterval = 0

    // macmon metrics
    @Published var metrics: SystemMetrics?
    @Published var isMacmonInstalled = false
    @Published var isInstallingMacmon = false
    @Published var installError: String?
    @Published var isMonitoring = false

    var scanStore: ScanStore?

    private let service = PerformanceService()
    private let macmonService = MacMonService()
    private let dependencyManager = DependencyManager.shared
    private var monitorTask: Task<Void, Never>?

    func loadData() async {
        isLoading = true
        errorMessage = nil
        loginItems = await service.getLoginItems()
        hostname = Host.current().localizedName ?? "Mac"
        osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        uptime = ProcessInfo.processInfo.systemUptime
        isMacmonInstalled = await dependencyManager.isInstalled(.macmon)
        isLoading = false
        updateSummary()

        if isMacmonInstalled {
            startMonitoring()
        }
    }

    func installMacmon() async {
        isInstallingMacmon = true
        installError = nil
        do {
            try await dependencyManager.install(.macmon)
            isMacmonInstalled = true
            startMonitoring()
        } catch {
            installError = error.localizedDescription
        }
        isInstallingMacmon = false
    }

    func startMonitoring() {
        guard monitorTask == nil else { return }
        isMonitoring = true
        monitorTask = Task {
            while !Task.isCancelled {
                metrics = await macmonService.sample()
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s interval
            }
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
        isMonitoring = false
        metrics = nil
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
