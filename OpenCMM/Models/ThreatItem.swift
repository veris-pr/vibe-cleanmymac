import Foundation

struct ThreatItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let threatType: ThreatType
    let severity: ThreatSeverity
    var isSelected: Bool = true
}

enum ThreatType: String {
    case malware = "Malware"
    case adware = "Adware"
    case suspiciousFile = "Suspicious File"
    case privacyRisk = "Privacy Risk"
    case browserExtension = "Browser Extension"

    var icon: String {
        switch self {
        case .malware: return "ladybug.fill"
        case .adware: return "exclamationmark.triangle.fill"
        case .suspiciousFile: return "questionmark.folder.fill"
        case .privacyRisk: return "eye.slash.fill"
        case .browserExtension: return "puzzlepiece.extension.fill"
        }
    }
}

enum ThreatSeverity: String {
    case critical = "Critical"
    case warning = "Warning"
    case info = "Info"
}
