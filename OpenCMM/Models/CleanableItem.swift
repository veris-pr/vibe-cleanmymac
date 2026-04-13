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
    case xcodeData = "Xcode Data"
    case trash = "Trash"
    case downloads = "Old Downloads"

    var icon: String {
        switch self {
        case .systemCache: return "internaldrive"
        case .userCache: return "person.crop.circle"
        case .browserCache: return "globe"
        case .systemLogs: return "doc.text"
        case .userLogs: return "doc.text.fill"
        case .xcodeData: return "hammer"
        case .trash: return "trash"
        case .downloads: return "arrow.down.circle"
        }
    }
}
