import Foundation

/// Integrates mactop for Apple Silicon performance metrics.
/// Provides CPU/GPU usage, temperatures, power consumption, per-core stats.
actor MactopService {
    private let deps = DependencyManager.shared

    struct Metrics {
        var cpuUsage: Double = 0
        var gpuUsage: Double = 0
        var cpuTemp: Double = 0
        var gpuTemp: Double = 0
        var cpuPower: Double = 0
        var gpuPower: Double = 0
        var systemPower: Double = 0
        var memoryTotal: UInt64 = 0
        var memoryUsed: UInt64 = 0
        var memoryAvailable: UInt64 = 0
        var swapUsed: UInt64 = 0
        var thermalState: String = "nominal"
        var coreUsages: [CoreUsage] = []
    }

    struct CoreUsage: Identifiable {
        let id = UUID()
        let coreIndex: Int
        let coreType: String  // "E" or "P"
        let usage: Double
        let frequency: Double
    }

    var isAvailable: Bool {
        get async { await deps.isInstalled(.mactop) }
    }

    func snapshot() async -> Metrics? {
        guard let mactop = await deps.path(for: .mactop) else { return nil }

        guard let output = try? ShellExecutor.shell("\(mactop) --headless --count 1 2>/dev/null"),
              let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        var metrics = Metrics()

        if let cpu = json["cpu_usage"] as? Double { metrics.cpuUsage = cpu }
        if let gpu = json["gpu_usage"] as? Double { metrics.gpuUsage = gpu }

        if let soc = json["soc_metrics"] as? [String: Any] {
            if let cpuTemp = soc["cpu_temp"] as? Double { metrics.cpuTemp = cpuTemp }
            if let gpuTemp = soc["gpu_temp"] as? Double { metrics.gpuTemp = gpuTemp }
            if let cpuPower = soc["cpu_power"] as? Double { metrics.cpuPower = cpuPower }
            if let gpuPower = soc["gpu_power"] as? Double { metrics.gpuPower = gpuPower }
            if let sysPower = soc["system_power"] as? Double { metrics.systemPower = sysPower }
        }

        if let mem = json["memory"] as? [String: Any] {
            if let total = mem["total"] as? UInt64 { metrics.memoryTotal = total }
            if let used = mem["used"] as? UInt64 { metrics.memoryUsed = used }
            if let avail = mem["available"] as? UInt64 { metrics.memoryAvailable = avail }
            if let swap = mem["swap_used"] as? UInt64 { metrics.swapUsed = swap }
        }

        if let thermal = json["thermal_state"] as? String { metrics.thermalState = thermal }

        if let cores = json["core_usages"] as? [[String: Any]] {
            metrics.coreUsages = cores.enumerated().compactMap { (i, core) in
                guard let usage = core["usage"] as? Double else { return nil }
                return CoreUsage(
                    coreIndex: i,
                    coreType: core["type"] as? String ?? "P",
                    usage: usage,
                    frequency: core["frequency"] as? Double ?? 0
                )
            }
        }

        return metrics
    }
}
