import Foundation

struct SystemInfo {
    let hostname: String
    let osVersion: String
    let uptime: TimeInterval
}

struct LoginItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let kind: LoginItemKind
    var isEnabled: Bool
}

enum LoginItemKind: String {
    case loginItem = "Login Item"
    case launchAgent = "Launch Agent"
    case launchDaemon = "Launch Daemon"
}

struct AppUpdateInfo: Identifiable {
    let id = UUID()
    let name: String
    let currentVersion: String
    let availableVersion: String
    let source: UpdateSource
    var isSelected: Bool = true
}

enum UpdateSource: String {
    case homebrew = "Homebrew"
    case homebrewCask = "Homebrew Cask"
    case manual = "Manual"
    case appStore = "App Store"
}

struct DuplicateGroup: Identifiable {
    let id = UUID()
    let hash: String
    let fileSize: Int64
    var files: [DuplicateFile]

    var wastedSpace: Int64 {
        fileSize * Int64(max(files.count - 1, 0))
    }
}

struct DuplicateFile: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let name: String
    let size: Int64
    let modifiedDate: Date
    var keepThis: Bool = false
}

struct LargeFile: Identifiable {
    let id = UUID()
    let path: String
    let name: String
    let size: Int64
    let lastAccessed: Date
    var isSelected: Bool = false
}
