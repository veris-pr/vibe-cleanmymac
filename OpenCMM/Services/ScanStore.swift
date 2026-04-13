import SwiftUI

/// Central store for scan results across all modules.
/// Both Smart Care and individual modules read/write here,
/// ensuring the dashboard always reflects the latest state.
@MainActor
class ScanStore: ObservableObject {
    @Published private(set) var moduleSummaries: [Module: ModuleScanSummary] = [:]
    @Published private(set) var lastScanDate: Date?
    @Published private(set) var healthScore: Int = 0

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

    /// Update all summaries at once (called by Smart Care full scan).
    func updateAll(_ summaries: [ModuleScanSummary], healthScore: Int) {
        for s in summaries {
            moduleSummaries[s.module] = s
        }
        self.healthScore = healthScore
        lastScanDate = Date()
    }

    /// Invalidate a module's results after cleanup actions.
    func invalidate(_ module: Module) {
        moduleSummaries.removeValue(forKey: module)
    }
}
