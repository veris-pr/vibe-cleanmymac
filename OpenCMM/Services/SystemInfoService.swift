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
        if info.memoryUsedPercent > 90 { score -= 30 }
        else if info.memoryUsedPercent > 75 { score -= 15 }
        else if info.memoryUsedPercent > 60 { score -= 5 }

        // Disk penalty
        if info.diskUsedPercent > 90 { score -= 30 }
        else if info.diskUsedPercent > 75 { score -= 15 }
        else if info.diskUsedPercent > 60 { score -= 5 }

        // CPU penalty
        if info.cpuUsage > 90 { score -= 20 }
        else if info.cpuUsage > 70 { score -= 10 }

        return max(0, min(100, score))
    }
}
