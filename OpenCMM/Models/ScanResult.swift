import Foundation

enum ScanMode: String, CaseIterable {
    case quick = "Quick"
    case deep = "Deep"
}

struct ScanResult: Identifiable {
    let id = UUID()
    let category: String
    var items: [CleanableItem]
    var isSelected: Bool = true

    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }
}

struct ModuleScanSummary: Identifiable {
    let id = UUID()
    let module: Module
    let itemCount: Int
    let totalSize: Int64
    let issues: [String]
    let timestamp: Date

    var hasIssues: Bool { itemCount > 0 }
}
