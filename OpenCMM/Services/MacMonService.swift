import Foundation

/// Reads system metrics from macmon (sudoless Apple Silicon monitor).
/// Uses `macmon pipe -s 1` for a single JSON snapshot.
actor MacMonService {
    private let dependencyManager = DependencyManager.shared

    var isAvailable: Bool {
        get async { await dependencyManager.isInstalled(.macmon) }
    }

    func sample() async -> SystemMetrics? {
        guard let macmon = await dependencyManager.path(for: .macmon) else { return nil }

        guard let output = try? await ShellExecutor.runAsync(
            macmon, arguments: ["pipe", "-s", "1"]
        ) else { return nil }

        // macmon outputs one JSON line per sample
        guard let line = output.components(separatedBy: "\n").first(where: { $0.hasPrefix("{") }),
              let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return parseMetrics(json)
    }

    private func parseMetrics(_ json: [String: Any]) -> SystemMetrics {
        let cpuUsage = json["cpu_usage_pct"] as? Double ?? 0
        let cpuPower = json["cpu_power"] as? Double ?? 0
        let gpuPower = json["gpu_power"] as? Double ?? 0

        var ramUsed: Int64 = 0
        var ramTotal: Int64 = 0
        var swapUsed: Int64 = 0
        var swapTotal: Int64 = 0
        if let mem = json["memory"] as? [String: Any] {
            ramUsed = mem["ram_usage"] as? Int64 ?? 0
            ramTotal = mem["ram_total"] as? Int64 ?? 0
            swapUsed = mem["swap_usage"] as? Int64 ?? 0
            swapTotal = mem["swap_total"] as? Int64 ?? 0
        }

        var cpuTemp: Double = 0
        var gpuTemp: Double = 0
        if let temp = json["temp"] as? [String: Any] {
            cpuTemp = temp["cpu_temp_avg"] as? Double ?? 0
            gpuTemp = temp["gpu_temp_avg"] as? Double ?? 0
        }

        var gpuUsage: Double = 0
        if let gpu = json["gpu_usage"] as? [Any], gpu.count >= 2 {
            gpuUsage = gpu[1] as? Double ?? 0
        }

        return SystemMetrics(
            cpuUsage: cpuUsage,
            gpuUsage: gpuUsage,
            cpuPower: cpuPower,
            gpuPower: gpuPower,
            ramUsed: ramUsed,
            ramTotal: ramTotal,
            swapUsed: swapUsed,
            swapTotal: swapTotal,
            cpuTemp: cpuTemp,
            gpuTemp: gpuTemp
        )
    }
}
