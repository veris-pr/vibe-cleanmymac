import SwiftUI

@MainActor
class SmartCareViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var progress: Double = 0
    @Published var currentStep: String = ""
    @Published var errorMessage: String?

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
        scanTask = Task { await scan() }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        currentStep = ""
    }

    /// Result type for each concurrent scan task.
    private enum ScanOutput: Sendable {
        case clean([ScanResult], ModuleScanSummary)
        case protect([ThreatItem], ModuleScanSummary)
        case speed([LoginItem], ModuleScanSummary)
        case update([AppUpdateInfo], ModuleScanSummary)
        case declutter([DuplicateGroup], ModuleScanSummary)
    }

    private func scan() async {
        isScanning = true
        progress = 0
        currentStep = "Starting scan..."

        var collectedSummaries: [ModuleScanSummary] = []
        var outputs: [ScanOutput] = []

        await withTaskGroup(of: (Int, ScanOutput).self) { group in
            group.addTask { [cleanService] in
                let results = await cleanService.scan()
                let totalSize = results.reduce(0) { $0 + $1.totalSize }
                let itemCount = results.reduce(0) { $0 + $1.items.count }
                let issues = results.map { "\($0.category): \(Formatters.fileSize($0.totalSize))" }
                let summary = ModuleScanSummary(module: .clean, itemCount: itemCount, totalSize: totalSize, issues: issues, timestamp: Date())
                return (0, .clean(results, summary))
            }

            group.addTask { [protectService] in
                let threats = await protectService.scan()
                let issues = threats.prefix(3).map { $0.name }
                let summary = ModuleScanSummary(module: .protect, itemCount: threats.count, totalSize: 0, issues: Array(issues), timestamp: Date())
                return (1, .protect(threats, summary))
            }

            group.addTask { [performanceService] in
                let items = await performanceService.getLoginItems()
                let issues = items.isEmpty ? [String]() : ["\(items.count) startup item\(items.count == 1 ? "" : "s")"]
                let summary = ModuleScanSummary(module: .speed, itemCount: items.count, totalSize: 0, issues: issues, timestamp: Date())
                return (2, .speed(items, summary))
            }

            group.addTask { [updateService] in
                let updates = await updateService.checkForUpdates()
                let issues = updates.prefix(3).map { "\($0.name) → \($0.availableVersion)" }
                let summary = ModuleScanSummary(module: .update, itemCount: updates.count, totalSize: 0, issues: Array(issues), timestamp: Date())
                return (3, .update(updates, summary))
            }

            group.addTask { [duplicateService] in
                let groups = await duplicateService.findDuplicates(quickScan: true)
                let wastedSpace = groups.reduce(0) { $0 + $1.wastedSpace }
                let issues = groups.prefix(3).map { "\($0.files.count) copies · \(Formatters.fileSize($0.wastedSpace))" }
                let summary = ModuleScanSummary(module: .declutter, itemCount: groups.count, totalSize: wastedSpace, issues: Array(issues), timestamp: Date())
                return (4, .declutter(groups, summary))
            }

            var completed = 0
            var indexed: [(Int, ScanOutput)] = []

            for await result in group {
                guard !Task.isCancelled else { return }
                completed += 1
                indexed.append(result)

                let stepNames = ["Sweep", "Security", "Boost", "Updates", "Duplicates"]
                currentStep = "Completed \(stepNames[result.0])"
                progress = Double(completed) / 5.0
            }

            let sorted = indexed.sorted { $0.0 < $1.0 }
            outputs = sorted.map { $0.1 }
            collectedSummaries = sorted.map { pair -> ModuleScanSummary in
                switch pair.1 {
                case .clean(_, let s), .protect(_, let s), .speed(_, let s),
                     .update(_, let s), .declutter(_, let s):
                    return s
                }
            }
        }

        guard !Task.isCancelled else { return }

        let score = await systemInfoService.healthScore()

        // Persist full results and summaries to shared ScanStore
        if let store = scanStore {
            for output in outputs {
                switch output {
                case .clean(let results, _):    store.cleanResults = results
                case .protect(let items, _):    store.threats = items
                case .speed(_, _):              break  // login items stored via summary
                case .update(let apps, _):      store.updates = apps
                case .declutter(let groups, _): store.duplicateGroups = groups
                }
            }
            store.updateAll(collectedSummaries, healthScore: score, scanMode: .quick)
        }

        isScanning = false
        currentStep = ""
    }
}
