import Foundation

/// Wraps the Mole CLI (`mo`) for system optimization and analysis.
/// Falls back gracefully when mole is not installed.
actor MoleService {

    private let dependencyManager = DependencyManager.shared

    var isInstalled: Bool {
        get async { await dependencyManager.isInstalled(.mole) }
    }

    // MARK: - System Status

    struct MoleStatus: Decodable {
        let host: String?
        let uptime: String?
        let healthScore: Int?
        let healthScoreMsg: String?
        let cpu: CPUInfo?
        let memory: MemoryInfo?
        let disks: [DiskInfo]?
        let hardware: HardwareInfo?

        enum CodingKeys: String, CodingKey {
            case host, uptime, cpu, memory, disks, hardware
            case healthScore = "health_score"
            case healthScoreMsg = "health_score_msg"
        }

        struct CPUInfo: Decodable {
            let usage: Double?
            let load1: Double?
            let load5: Double?
            let load15: Double?
            let coreCount: Int?
            let logicalCpu: Int?

            enum CodingKeys: String, CodingKey {
                case usage, load1, load5, load15
                case coreCount = "core_count"
                case logicalCpu = "logical_cpu"
            }
        }

        struct MemoryInfo: Decodable {
            let used: Int64?
            let total: Int64?
            let usedPercent: Double?
            let swapUsed: Int64?
            let swapTotal: Int64?

            enum CodingKeys: String, CodingKey {
                case used, total
                case usedPercent = "used_percent"
                case swapUsed = "swap_used"
                case swapTotal = "swap_total"
            }
        }

        struct DiskInfo: Decodable {
            let mount: String?
            let used: Int64?
            let total: Int64?
            let usedPercent: Double?

            enum CodingKeys: String, CodingKey {
                case mount, used, total
                case usedPercent = "used_percent"
            }
        }

        struct HardwareInfo: Decodable {
            let model: String?
            let cpuModel: String?
            let totalRam: String?
            let diskSize: String?
            let osVersion: String?

            enum CodingKeys: String, CodingKey {
                case model
                case cpuModel = "cpu_model"
                case totalRam = "total_ram"
                case diskSize = "disk_size"
                case osVersion = "os_version"
            }
        }
    }

    /// Get system status as structured data via `mo status --json`.
    func status() async -> MoleStatus? {
        guard await isInstalled else { return nil }
        guard let output = try? await ShellExecutor.shellAsync("mo status --json") else { return nil }
        guard let data = output.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(MoleStatus.self, from: data)
    }

    // MARK: - Optimize

    struct OptimizeResult {
        let output: String
        let optimizationCount: Int
    }

    /// Run `mo optimize` to apply system optimizations.
    /// Returns the output text and number of optimizations applied.
    func optimize() async throws -> OptimizeResult {
        guard await isInstalled else {
            throw MoleError.notInstalled
        }
        let output = try await ShellExecutor.shellAsync("mo optimize")
        let count = parseOptimizationCount(output)
        return OptimizeResult(output: output, optimizationCount: count)
    }

    /// Run `mo optimize --dry-run` to preview optimizations without applying.
    func optimizeDryRun() async -> OptimizeResult? {
        guard await isInstalled else { return nil }
        guard let output = try? await ShellExecutor.shellAsync("mo optimize --dry-run") else { return nil }
        let count = parseOptimizationCount(output)
        return OptimizeResult(output: output, optimizationCount: count)
    }

    // MARK: - Disk Analysis

    struct AnalyzeResult: Decodable {
        let path: String?
        let totalSize: Int64?
        let totalFiles: Int?
        let entries: [Entry]?

        enum CodingKeys: String, CodingKey {
            case path, entries
            case totalSize = "total_size"
            case totalFiles = "total_files"
        }

        struct Entry: Decodable {
            let name: String?
            let path: String?
            let size: Int64?
            let isDir: Bool?

            enum CodingKeys: String, CodingKey {
                case name, path, size
                case isDir = "is_dir"
            }
        }
    }

    /// Run `mo analyze --json` on a path to get disk breakdown.
    func analyze(path: String) async -> AnalyzeResult? {
        guard await isInstalled else { return nil }
        guard let output = try? await ShellExecutor.shellAsync("mo analyze --json \(ShellExecutor.quote(path))") else { return nil }
        guard let data = output.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AnalyzeResult.self, from: data)
    }

    // MARK: - Helpers

    private func parseOptimizationCount(_ output: String) -> Int {
        // Look for "Would apply N optimizations" or "Applied N optimizations"
        let patterns = [
            "Would apply (\\d+) optimization",
            "Applied (\\d+) optimization",
            "(\\d+) optimization"
        ]
        for pattern in patterns {
            if let match = output.range(of: pattern, options: .regularExpression) {
                let text = String(output[match])
                let digits = text.filter(\.isNumber)
                if let n = Int(digits) { return n }
            }
        }
        return 0
    }
}

enum MoleError: LocalizedError {
    case notInstalled

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "Mole is not installed. Install via Settings to use system optimization."
        }
    }
}
