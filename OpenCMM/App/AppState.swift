import SwiftUI

@MainActor
class AppState: ObservableObject {
    static let hasCompletedSetupKey = "hasCompletedSetup"

    @Published var selectedModule: Module = .smartCare
    @Published var hasCompletedSetup: Bool

    let scanStore = ScanStore()

    // Shared ViewModels — persist across navigation
    let smartCareVM = SmartCareViewModel()
    let cleanVM = CleanViewModel()
    let protectVM = ProtectViewModel()
    let speedVM = SpeedViewModel()
    let updateVM = UpdateViewModel()
    let declutterVM = DeclutterViewModel()
    let spaceLensVM = SpaceLensViewModel()
    let uninstallVM = UninstallViewModel()
    let settingsVM = SettingsViewModel()

    init() {
        self.hasCompletedSetup = UserDefaults.standard.bool(forKey: Self.hasCompletedSetupKey)

        // Wire scan store to all VMs
        smartCareVM.scanStore = scanStore
        cleanVM.scanStore = scanStore
        protectVM.scanStore = scanStore
        speedVM.scanStore = scanStore
        updateVM.scanStore = scanStore
        declutterVM.scanStore = scanStore
    }

    func completeSetup() {
        hasCompletedSetup = true
        UserDefaults.standard.set(true, forKey: Self.hasCompletedSetupKey)
    }
}
