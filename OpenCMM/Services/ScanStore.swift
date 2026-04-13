import SwiftUI

/// Central store for scan results across all modules.
/// Single source of truth: Overview and individual modules both read/write here.
@MainActor
class ScanStore: ObservableObject {
    // MARK: - Summaries (for Overview cards and menu bar)
    @Published private(set) var moduleSummaries: [Module: ModuleScanSummary] = [:]
    @Published private(set) var lastScanDate: Date?
    @Published private(set) var lastScanMode: ScanMode?
    @Published private(set) var healthScore: Int = 0

    // MARK: - Detailed results (shared across modules)
    @Published var cleanResults: [ScanResult] = []
    @Published var threats: [ThreatItem] = []
    @Published var systemInfo: SystemInfo?
    @Published var auditResult: AuditResult?
    @Published var updates: [AppUpdateInfo] = []
    @Published var duplicateGroups: [DuplicateGroup] = []
    @Published var largeFiles: [LargeFile] = []
    @Published var similarImages: [SimilarGroup] = []
    @Published var tempFiles: [TempFileResult] = []

    var hasScanResults: Bool { !moduleSummaries.isEmpty }

    var orderedSummaries: [ModuleScanSummary] {
        [Module.clean, .protect, .speed, .update, .declutter]
            .compactMap { moduleSummaries[$0] }
    }

    var totalIssues: Int {
        moduleSummaries.values.reduce(0) { $0 + $1.itemCount }
    }

    /// Update a single module's summary (called by individual module scans).
    func updateSummary(_ summary: ModuleScanSummary) {
        moduleSummaries[summary.module] = summary
        lastScanDate = Date()
    }

    /// Update all summaries at once (called by Overview full scan).
    func updateAll(_ summaries: [ModuleScanSummary], healthScore: Int, scanMode: ScanMode) {
        for s in summaries {
            moduleSummaries[s.module] = s
        }
        self.healthScore = healthScore
        self.lastScanMode = scanMode
        lastScanDate = Date()
    }

    /// Invalidate a module's results after cleanup actions.
    func invalidate(_ module: Module) {
        moduleSummaries.removeValue(forKey: module)
        switch module {
        case .clean: cleanResults = []
        case .protect: threats = []; auditResult = nil
        case .speed: systemInfo = nil
        case .update: updates = []
        case .declutter:
            duplicateGroups = []
            largeFiles = []
            similarImages = []
            tempFiles = []
        default: break
        }
    }
}
