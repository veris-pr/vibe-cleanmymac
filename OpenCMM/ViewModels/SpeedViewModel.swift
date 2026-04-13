import SwiftUI

@MainActor
class SpeedViewModel: ObservableObject {
    @Published var systemInfo: SystemInfo?
    @Published var loginItems: [LoginItem] = []
    @Published var isLoading = false
    @Published var isPurging = false

    private let service = PerformanceService()

    func loadData() async {
        isLoading = true
        async let info = service.getSystemInfo()
        async let items = service.getLoginItems()
        systemInfo = await info
        loginItems = await items
        isLoading = false
    }

    func refresh() async {
        systemInfo = await service.getSystemInfo()
    }

    func purgeMemory() async {
        isPurging = true
        _ = await service.purgeMemory()
        // Refresh system info after purge
        systemInfo = await service.getSystemInfo()
        isPurging = false
    }

    func disableLoginItem(_ item: LoginItem) async {
        do {
            try ShellExecutor.shell("launchctl unload \"\(item.path)\"")
            if let index = loginItems.firstIndex(where: { $0.id == item.id }) {
                loginItems[index].isEnabled = false
            }
        } catch {
            print("Failed to disable \(item.name): \(error)")
        }
    }

    func enableLoginItem(_ item: LoginItem) async {
        do {
            try ShellExecutor.shell("launchctl load \"\(item.path)\"")
            if let index = loginItems.firstIndex(where: { $0.id == item.id }) {
                loginItems[index].isEnabled = true
            }
        } catch {
            print("Failed to enable \(item.name): \(error)")
        }
    }
}
