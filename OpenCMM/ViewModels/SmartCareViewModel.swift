import SwiftUI

@MainActor
class SmartCareViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var progress: Double = 0
    @Published var currentStep: String = ""
    @Published var errorMessage: String?
    @Published var scanMode: ScanMode = .quick

    var scanStore: ScanStore?

    private var scanTask: Task<Void, Never>?

    private let cleanService = CleaningService()
    private let protectService = MalwareScanService()
    private let performanceService = PerformanceService()
    private let updateService = UpdateService()
    private let duplicateService = DuplicateFinderService()
    private let systemInfoService = SystemInfoService()

    func startScan() {
        scanTask?.cancel()
        let mode = scanMode
        scanTask = Task { await scan(mode: mode) }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        currentStep = ""
    }

    private func scan(mode: ScanMode) async {
        isScanning = true
        progress = 0
        currentStep = "Starting \(mode.rawValue.lowercased()) scan..."

        let isQuick = mode == .quick

        // Run all 5 scans concurrently using structured concurrency
        var collectedSummaries: [ModuleScanSummary] = []

        await withTaskGroup(of: (Int, ModuleScanSummary).self) { group in
            group.addTask { [cleanService] in
                let results = await cleanService.scan()
                let totalSize = results.reduce(0) { $0 + $1.totalSize }
                let itemCount = results.reduce(0) { $0 + $1.items.count }
                let issues = results.map { "\($0.category): \(Formatters.fileSize($0.totalSize))" }
                return (0, ModuleScanSummary(module: .clean, itemCount: itemCount, totalSize: totalSize, issues: issues, timestamp: Date()))
            }

            group.addTask { [protectService] in
                let threats = await protectService.scan()
                let issues = threats.prefix(3).map { $0.name }
                return (1, ModuleScanSummary(module: .protect, itemCount: threats.count, totalSize: 0, issues: Array(issues), timestamp: Date()))
            }

            group.addTask { [performanceService] in
                let info = await performanceService.getSystemInfo()
                var issues: [String] = []
                if info.memoryUsedPercent > 80 { issues.append("High memory usage: \(Int(info.memoryUsedPercent))%") }
                if info.diskUsedPercent > 80 { issues.append("Low disk space: \(Formatters.fileSize(Int64(info.diskFree))) free") }
                if info.cpuUsage > 70 { issues.append("High CPU: \(Int(info.cpuUsage))%") }
                return (2, ModuleScanSummary(module: .speed, itemCount: issues.count, totalSize: 0, issues: issues, timestamp: Date()))
            }

            group.addTask { [updateService] in
                let updates = await updateService.checkForUpdates()
                let issues = updates.prefix(3).map { "\($0.name) → \($0.availableVersion)" }
                return (3, ModuleScanSummary(module: .update, itemCount: updates.count, totalSize: 0, issues: Array(issues), timestamp: Date()))
            }

            group.addTask { [duplicateService] in
                let groups = await duplicateService.findDuplicates(quickScan: isQuick)
                let wastedSpace = groups.reduce(0) { $0 + $1.wastedSpace }
                let issues = groups.prefix(3).map { "\($0.files.count) copies · \(Formatters.fileSize($0.wastedSpace))" }
                return (4, ModuleScanSummary(module: .declutter, itemCount: groups.count, totalSize: wastedSpace, issues: Array(issues), timestamp: Date()))
            }

            var completed = 0
            var results: [(Int, ModuleScanSummary)] = []

            for await result in group {
                guard !Task.isCancelled else { return }
                completed += 1
                results.append(result)

                let stepNames = ["Sweep", "Security", "Boost", "Updates", "Duplicates"]
                currentStep = "Completed \(stepNames[result.0])"
                progress = Double(completed) / 5.0
            }

            // Sort by module order
            collectedSummaries = results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }

        guard !Task.isCancelled else { return }

        let score = await systemInfoService.healthScore()

        // Persist to shared ScanStore
        scanStore?.updateAll(collectedSummaries, healthScore: score, scanMode: mode)

        isScanning = false
        currentStep = ""
    }
}
