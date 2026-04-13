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

enum Module: String, CaseIterable, Identifiable {
    case smartCare = "Overview"
    case clean = "Sweep"
    case protect = "Security"
    case speed = "Boost"
    case update = "Updates"
    case declutter = "Duplicates"
    case spaceLens = "Disk Map"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .smartCare: return "square.grid.2x2"
        case .clean: return "trash"
        case .protect: return "shield"
        case .speed: return "gauge.with.needle"
        case .update: return "arrow.down.circle"
        case .declutter: return "doc.on.doc"
        case .spaceLens: return "circle.grid.cross"
        case .settings: return "gearshape"
        }
    }
}
