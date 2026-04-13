import SwiftUI

class AppState: ObservableObject {
    @Published var selectedModule: Module = .smartCare
    @Published var isScanning = false
    @Published var lastScanDate: Date?
    @Published var overallHealthScore: Int = 0

    @Published var cleanResult: ModuleScanSummary?
    @Published var protectResult: ModuleScanSummary?
    @Published var speedResult: ModuleScanSummary?
    @Published var updateResult: ModuleScanSummary?
    @Published var declutterResult: ModuleScanSummary?
}

enum Module: String, CaseIterable, Identifiable {
    case smartCare = "Smart Care"
    case clean = "Clean"
    case protect = "Protect"
    case speed = "Speed"
    case update = "Update"
    case declutter = "Declutter"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .smartCare: return "square.grid.2x2"
        case .clean: return "trash"
        case .protect: return "shield"
        case .speed: return "gauge.with.needle"
        case .update: return "arrow.down.circle"
        case .declutter: return "doc.on.doc"
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
        }
    }
}
