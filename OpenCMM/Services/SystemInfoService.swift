import Foundation

actor SystemInfoService {
    /// Health score based on disk space only.
    func healthScore() async -> Int {
        var score = 100

        // Disk penalty
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
           let total = attrs[.systemSize] as? UInt64,
           let free = attrs[.systemFreeSize] as? UInt64,
           total > 0 {
            let diskUsedPercent = Double(total - free) / Double(total) * 100
            if diskUsedPercent > AppConstants.Health.diskCritical { score -= AppConstants.Health.diskCriticalPenalty }
            else if diskUsedPercent > AppConstants.Health.diskWarning { score -= AppConstants.Health.diskWarningPenalty }
            else if diskUsedPercent > 60 { score -= AppConstants.Health.diskMildPenalty }
        }

        return max(0, min(100, score))
    }
}
