import SwiftUI

@MainActor
class SpeedViewModel: ObservableObject {
    @Published var systemInfo: SystemInfo?
    @Published var loginItems: [LoginItem] = []
    @Published var isLoading = false
    @Published var isPurging = false
    @Published var errorMessage: String?
    @Published var mactopMetrics: MactopService.Metrics?
    @Published var isMactopInstalled = false
    @Published var isAutoRefresh = false

    var scanStore: ScanStore?

    private let service = PerformanceService()
    private let mactopService = MactopService()
    private let deps = DependencyManager.shared
    private var refreshTask: Task<Void, Never>?

    func checkDependencies() async {
        isMactopInstalled = await deps.isInstalled(.mactop)
    }

    func loadData() async {
        isLoading = true
        errorMessage = nil
        async let info = service.getSystemInfo()
        async let items = service.getLoginItems()
        systemInfo = await info
        loginItems = await items
        await checkDependencies()
        if isMactopInstalled {
            mactopMetrics = await mactopService.snapshot()
        }
        isLoading = false
        updateSpeedSummary()
    }

    func analyze() async {
        errorMessage = nil
        systemInfo = await service.getSystemInfo()
        if isMactopInstalled {
            mactopMetrics = await mactopService.snapshot()
        }
        updateSpeedSummary()
    }

    func refresh() async {
        await analyze()
    }

    func toggleAutoRefresh() {
        isAutoRefresh.toggle()
        if isAutoRefresh {
            refreshTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    guard !Task.isCancelled else { break }
                    await analyze()
                }
            }
        } else {
            refreshTask?.cancel()
            refreshTask = nil
        }
    }

    func purgeMemory() async {
        isPurging = true
        _ = await service.purgeMemory()
        systemInfo = await service.getSystemInfo()
        isPurging = false
        scanStore?.invalidate(.speed)
    }

    func disableLoginItem(_ item: LoginItem) async {
        do {
            try ShellExecutor.shell("launchctl unload \"\(item.path)\"")
            if let index = loginItems.firstIndex(where: { $0.id == item.id }) {
                loginItems[index].isEnabled = false
            }
        } catch {
            errorMessage = "Failed to disable \(item.name): \(error.localizedDescription)"
        }
    }

    func enableLoginItem(_ item: LoginItem) async {
        do {
            try ShellExecutor.shell("launchctl load \"\(item.path)\"")
            if let index = loginItems.firstIndex(where: { $0.id == item.id }) {
                loginItems[index].isEnabled = true
            }
        } catch {
            errorMessage = "Failed to enable \(item.name): \(error.localizedDescription)"
        }
    }

    private func updateSpeedSummary() {
        guard let info = systemInfo else { return }
        var issues: [String] = []
        if info.memoryUsedPercent > 80 { issues.append("High memory usage: \(Int(info.memoryUsedPercent))%") }
        if info.diskUsedPercent > 80 { issues.append("Low disk space: \(Formatters.fileSize(Int64(info.diskFree))) free") }
        if info.cpuUsage > 70 { issues.append("High CPU: \(Int(info.cpuUsage))%") }
        scanStore?.updateSummary(ModuleScanSummary(
            module: .speed, itemCount: issues.count, totalSize: 0,
            issues: issues, timestamp: Date()
        ))
    }
}
