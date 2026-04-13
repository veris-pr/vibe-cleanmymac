import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var selectedModule: Module = .smartCare
    @Published var hasCompletedSetup: Bool

    // Shared ViewModels — persist across navigation
    let smartCareVM = SmartCareViewModel()
    let cleanVM = CleanViewModel()
    let protectVM = ProtectViewModel()
    let speedVM = SpeedViewModel()
    let updateVM = UpdateViewModel()
    let declutterVM = DeclutterViewModel()
    let spaceLensVM = SpaceLensViewModel()

    init() {
        self.hasCompletedSetup = UserDefaults.standard.bool(forKey: "hasCompletedSetup")
    }

    func completeSetup() {
        hasCompletedSetup = true
        UserDefaults.standard.set(true, forKey: "hasCompletedSetup")
    }
}

enum Module: String, CaseIterable, Identifiable {
    case smartCare = "Smart Care"
    case clean = "Clean"
    case protect = "Protect"
    case speed = "Speed"
    case update = "Update"
    case declutter = "Declutter"
    case spaceLens = "Space Lens"
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

    var color: Color {
        .primary.opacity(0.7)
    }

    var description: String {
        switch self {
        case .smartCare: return "One scan. Five routines."
        case .clean: return "Free up space for things you truly need"
        case .protect: return "Neutralize threats before they do any harm"
        case .speed: return "Make your slow Mac fast again"
        case .update: return "Keep your apps up to date"
        case .declutter: return "Take control of the clutter"
        case .spaceLens: return "See what's taking up space"
        case .settings: return "Manage tools and preferences"
        }
    }
}
