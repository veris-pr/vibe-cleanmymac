import SwiftUI

@MainActor
class SmartCareViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var scanComplete = false
    @Published var currentStep: String = ""
    @Published var progress: Double = 0
    @Published var healthScore: Int = 0

    @Published var cleanSummary: ModuleScanSummary?
    @Published var protectSummary: ModuleScanSummary?
    @Published var speedSummary: ModuleScanSummary?
    @Published var updateSummary: ModuleScanSummary?
    @Published var declutterSummary: ModuleScanSummary?

    private let cleaningService = CleaningService()
    private let malwareService = MalwareScanService()
    private let performanceService = PerformanceService()
    private let updateService = UpdateService()
    private let duplicateService = DuplicateFinderService()
    private let systemInfoService = SystemInfoService()

    var totalIssues: Int {
        [cleanSummary, protectSummary, speedSummary, updateSummary, declutterSummary]
            .compactMap { $0?.itemCount }
            .reduce(0, +)
    }

    func runSmartCare() async {
        isScanning = true
        scanComplete = false
        progress = 0

        // Step 1: Clean scan
        currentStep = "Scanning for junk files..."
        let cleanResults = await cleaningService.scan()
        let cleanSize = cleanResults.reduce(0) { $0 + $1.totalSize }
        cleanSummary = ModuleScanSummary(
            module: .clean,
            itemCount: cleanResults.flatMap(\.items).count,
            totalSize: cleanSize,
            issues: cleanResults.map { "\($0.category): \(Formatters.fileSize($0.totalSize))" },
            timestamp: Date()
        )
        progress = 0.2

        // Step 2: Protect scan
        currentStep = "Checking for threats..."
        let threats = await malwareService.scan()
        protectSummary = ModuleScanSummary(
            module: .protect,
            itemCount: threats.count,
            totalSize: 0,
            issues: threats.map { "\($0.threatType.rawValue): \($0.name)" },
            timestamp: Date()
        )
        progress = 0.4

        // Step 3: Speed check
        currentStep = "Analyzing performance..."
        let sysInfo = await performanceService.getSystemInfo()
        let loginItems = await performanceService.getLoginItems()
        var speedIssues: [String] = []
        if sysInfo.memoryUsedPercent > 75 { speedIssues.append("High memory usage: \(Formatters.percentage(sysInfo.memoryUsedPercent))") }
        if loginItems.count > 10 { speedIssues.append("\(loginItems.count) startup items") }
        speedSummary = ModuleScanSummary(
            module: .speed,
            itemCount: speedIssues.count,
            totalSize: 0,
            issues: speedIssues,
            timestamp: Date()
        )
        progress = 0.6

        // Step 4: Update check
        currentStep = "Checking for updates..."
        let updates = await updateService.checkForUpdates()
        updateSummary = ModuleScanSummary(
            module: .update,
            itemCount: updates.count,
            totalSize: 0,
            issues: updates.map { "\($0.name): \($0.currentVersion) → \($0.availableVersion)" },
            timestamp: Date()
        )
        progress = 0.8

        // Step 5: Declutter scan
        currentStep = "Finding duplicates and clutter..."
        let dupes = await duplicateService.findDuplicates()
        let largeFiles = await duplicateService.findLargeFiles()
        let wastedSpace = dupes.reduce(0) { $0 + $1.wastedSpace }
        declutterSummary = ModuleScanSummary(
            module: .declutter,
            itemCount: dupes.count + largeFiles.count,
            totalSize: wastedSpace,
            issues: [
                "\(dupes.count) duplicate groups",
                "\(largeFiles.count) large files found",
            ],
            timestamp: Date()
        )
        progress = 1.0

        // Calculate health score
        healthScore = await systemInfoService.healthScore()

        currentStep = "Scan complete"
        isScanning = false
        scanComplete = true
    }
}
