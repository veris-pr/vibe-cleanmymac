import Foundation
import IOKit

actor PerformanceService {
    private let home = FileUtils.homeDirectory()

    func getSystemInfo() async -> SystemInfo {
        let memory = getMemoryInfo()
        let disk = getDiskInfo()
        let cpu = getCPUUsage()
        let hostname = Host.current().localizedName ?? "Mac"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let uptime = ProcessInfo.processInfo.systemUptime

        return SystemInfo(
            hostname: hostname,
            osVersion: osVersion,
            cpuUsage: cpu,
            memoryTotal: memory.total,
            memoryUsed: memory.used,
            diskTotal: disk.total,
            diskUsed: disk.used,
            uptime: uptime
        )
    }

    func getLoginItems() async -> [LoginItem] {
        var items: [LoginItem] = []

        // Scan user Launch Agents
        let userAgentsPath = "\(home)/Library/LaunchAgents"
        for file in FileUtils.contentsOfDirectory(userAgentsPath) {
            guard file.hasSuffix(".plist") else { continue }
            items.append(LoginItem(
                name: file.replacingOccurrences(of: ".plist", with: ""),
                path: "\(userAgentsPath)/\(file)",
                kind: .launchAgent,
                isEnabled: true
            ))
        }

        // Scan system Launch Agents
        let systemAgentsPath = "/Library/LaunchAgents"
        for file in FileUtils.contentsOfDirectory(systemAgentsPath) {
            guard file.hasSuffix(".plist") else { continue }
            items.append(LoginItem(
                name: file.replacingOccurrences(of: ".plist", with: ""),
                path: "\(systemAgentsPath)/\(file)",
                kind: .launchAgent,
                isEnabled: true
            ))
        }

        // Scan Launch Daemons
        let daemonsPath = "/Library/LaunchDaemons"
        for file in FileUtils.contentsOfDirectory(daemonsPath) {
            guard file.hasSuffix(".plist") else { continue }
            items.append(LoginItem(
                name: file.replacingOccurrences(of: ".plist", with: ""),
                path: "\(daemonsPath)/\(file)",
                kind: .launchDaemon,
                isEnabled: true
            ))
        }

        return items
    }

    func purgeMemory(password: String) async throws {
        try ShellExecutor.shellWithSudo("purge", password: password)
    }

    func disableLoginItem(path: String) throws {
        try ShellExecutor.shell("launchctl unload \(ShellExecutor.quote(path))")
    }

    func enableLoginItem(path: String) throws {
        try ShellExecutor.shell("launchctl load \(ShellExecutor.quote(path))")
    }

    // MARK: - System Info Helpers

    private func getMemoryInfo() -> (total: UInt64, used: UInt64) {
        let total = ProcessInfo.processInfo.physicalMemory
        // Approximate used memory via vm_statistics
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let pageSize = UInt64(vm_kernel_page_size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return (total, 0) }

        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let used = active + wired + compressed

        // Ensure we don't report more used than total
        return (total, min(used, total))
    }

    private func getDiskInfo() -> (total: UInt64, used: UInt64) {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let total = attrs[.systemSize] as? UInt64,
              let free = attrs[.systemFreeSize] as? UInt64 else {
            return (0, 0)
        }
        return (total, total - free)
    }

    private func getCPUUsage() -> Double {
        var loadInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &loadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        let user = Double(loadInfo.cpu_ticks.0)
        let system = Double(loadInfo.cpu_ticks.1)
        let idle = Double(loadInfo.cpu_ticks.2)
        let nice = Double(loadInfo.cpu_ticks.3)
        let total = user + system + idle + nice
        guard total > 0 else { return 0 }

        return ((user + system + nice) / total) * 100
    }
}
