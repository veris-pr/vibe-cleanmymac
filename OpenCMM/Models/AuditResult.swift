import Foundation

/// Security audit result from osquery.
struct AuditResult {
    var launchItems: [LaunchItemAudit] = []
    var listeningPorts: [ListeningPort] = []
    var browserExtensions: [BrowserExtension] = []
    var firewallEnabled: Bool = false
    var sipEnabled: Bool = true
}

struct LaunchItemAudit: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let programPath: String
    let runAtLoad: Bool
    let isApple: Bool
}

struct ListeningPort: Identifiable {
    let id = UUID()
    let port: Int
    let protocol_: String
    let processName: String
    let pid: Int
}

struct BrowserExtension: Identifiable {
    let id = UUID()
    let name: String
    let identifier: String
    let browser: String
    let version: String
}
