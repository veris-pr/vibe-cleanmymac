import Foundation

actor SystemInfoService {
    private let performanceService = PerformanceService()

    func getQuickStatus() async -> (memoryPercent: Double, diskPercent: Double, cpuPercent: Double) {
        let info = await performanceService.getSystemInfo()
        return (info.memoryUsedPercent, info.diskUsedPercent, info.cpuUsage)
    }

    func getDetailedInfo() async -> SystemInfo {
        await performanceService.getSystemInfo()
    }

    func healthScore() async -> Int {
        let info = await performanceService.getSystemInfo()

        var score = 100

        // Memory penalty
        if info.memoryUsedPercent > AppConstants.Health.memoryCritical { score -= AppConstants.Health.memoryCriticalPenalty }
        else if info.memoryUsedPercent > AppConstants.Health.memoryWarning { score -= AppConstants.Health.memoryWarningPenalty }
        else if info.memoryUsedPercent > 60 { score -= AppConstants.Health.memoryMildPenalty }

        // Disk penalty
        if info.diskUsedPercent > AppConstants.Health.diskCritical { score -= AppConstants.Health.diskCriticalPenalty }
        else if info.diskUsedPercent > AppConstants.Health.diskWarning { score -= AppConstants.Health.diskWarningPenalty }
        else if info.diskUsedPercent > 60 { score -= AppConstants.Health.diskMildPenalty }

        // CPU penalty
        if info.cpuUsage > AppConstants.Health.cpuCritical { score -= AppConstants.Health.cpuCriticalPenalty }
        else if info.cpuUsage > AppConstants.Health.cpuWarning { score -= AppConstants.Health.cpuWarningPenalty }

        return max(0, min(100, score))
    }
}
