import Foundation

enum Module: String, CaseIterable, Identifiable {
    case smartCare = "Overview"
    case clean = "Sweep"
    case protect = "Security"
    case speed = "Boost"
    case update = "Updates"
    case uninstall = "Uninstaller"
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
        case .uninstall: return "trash.square"
        case .declutter: return "doc.on.doc"
        case .spaceLens: return "circle.grid.cross"
        case .settings: return "gearshape"
        }
    }
}
