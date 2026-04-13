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
    @Published var isMactopInstalling = false
    @Published var mactopInstallError: String?
    @Published var isAutoRefresh = false

    var scanStore: ScanStore?

    private let service = PerformanceService()
    private let mactopService = MactopService()
    private let deps = DependencyManager.shared
    private var refreshTask: Task<Void, Never>?

    func loadFromStore() {
        guard systemInfo == nil, let store = scanStore, let info = store.systemInfo else { return }
        systemInfo = info
    }

    func checkDependencies() async {
        isMactopInstalled = await deps.isInstalled(.mactop)
    }

    func installMactop() async {
        isMactopInstalling = true
        mactopInstallError = nil
        do {
            try await deps.install(.mactop)
            isMactopInstalled = true
            mactopMetrics = await mactopService.snapshot()
        } catch {
            mactopInstallError = error.localizedDescription
        }
        isMactopInstalling = false
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
                    try? await Task.sleep(nanoseconds: AppConstants.Timing.autoRefreshInterval)
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
        errorMessage = nil
        do {
            try await service.purgeMemory()
        } catch {
            errorMessage = "Failed to free RAM: \(error.localizedDescription)"
        }
        systemInfo = await service.getSystemInfo()
        isPurging = false
        scanStore?.invalidate(.speed)
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

    private func updateSpeedSummary() {
        guard let info = systemInfo else { return }
        scanStore?.systemInfo = info
        scanStore?.updateSummary(.speed(from: info))
    }
}
