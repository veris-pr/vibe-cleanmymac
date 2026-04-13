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

    /// Build a speed summary from system info (shared by SpeedVM + SmartCareVM).
    static func speed(from info: SystemInfo) -> ModuleScanSummary {
        var issues: [String] = []
        if info.memoryUsedPercent > AppConstants.Summary.highMemoryPercent {
            issues.append("High memory usage: \(Int(info.memoryUsedPercent))%")
        }
        if info.diskUsedPercent > AppConstants.Summary.lowDiskPercent {
            issues.append("Low disk space: \(Formatters.fileSize(Int64(info.diskFree))) free")
        }
        if info.cpuUsage > AppConstants.Summary.highCpuPercent {
            issues.append("High CPU: \(Int(info.cpuUsage))%")
        }
        return ModuleScanSummary(module: .speed, itemCount: issues.count, totalSize: 0, issues: issues, timestamp: Date())
    }
}
