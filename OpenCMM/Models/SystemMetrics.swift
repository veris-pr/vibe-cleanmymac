import Foundation

struct SystemMetrics {
    let cpuUsage: Double      // 0.0–1.0
    let gpuUsage: Double      // 0.0–1.0
    let cpuPower: Double      // Watts
    let gpuPower: Double      // Watts
    let ramUsed: Int64        // bytes
    let ramTotal: Int64       // bytes
    let swapUsed: Int64       // bytes
    let swapTotal: Int64      // bytes
    let cpuTemp: Double       // °C
    let gpuTemp: Double       // °C

    var ramUsagePercent: Double {
        guard ramTotal > 0 else { return 0 }
        return Double(ramUsed) / Double(ramTotal)
    }
}
