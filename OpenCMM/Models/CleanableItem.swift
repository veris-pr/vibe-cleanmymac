import Foundation

struct CleanableItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    let category: CleanCategory
    var isSelected: Bool = true

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CleanableItem, rhs: CleanableItem) -> Bool {
        lhs.id == rhs.id
    }
}

enum CleanCategory: String, CaseIterable {
    case systemCache = "System Cache"
    case userCache = "User Cache"
    case browserCache = "Browser Cache"
    case systemLogs = "System Logs"
    case userLogs = "User Logs"
    case crashReports = "Crash Reports"
    case xcodeData = "Xcode Data"
    case appCache = "App Cache"
    case devCache = "Developer Cache"
    case mailDownloads = "Mail Downloads"
    case macOSInstaller = "macOS Installer"
    case trash = "Trash"

    var icon: String {
        switch self {
        case .systemCache: return "internaldrive"
        case .userCache: return "person.crop.circle"
        case .browserCache: return "globe"
        case .systemLogs: return "doc.text"
        case .userLogs: return "doc.text.fill"
        case .crashReports: return "exclamationmark.triangle"
        case .xcodeData: return "hammer"
        case .appCache: return "app.badge.fill"
        case .devCache: return "terminal"
        case .mailDownloads: return "envelope"
        case .macOSInstaller: return "arrow.down.app"
        case .trash: return "trash"
        }
    }
}
