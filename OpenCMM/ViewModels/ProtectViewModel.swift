import SwiftUI

@MainActor
class ProtectViewModel: ObservableObject {
    @Published var threats: [ThreatItem] = []
    @Published var isScanning = false
    @Published var isRemoving = false
    @Published var scanComplete = false
    @Published var isClamAVInstalled = false
    @Published var isInstallingClamAV = false
    @Published var installError: String?
    @Published var errorMessage: String?
    @Published var showConfirmation = false
    @Published var auditResult: AuditResult?
    @Published var isOsqueryInstalled = false

    var scanStore: ScanStore?

    private let service = MalwareScanService()
    private let osqueryService = OsqueryService()
    private let dependencyManager = DependencyManager.shared

    var threatCount: Int { threats.count }
    var criticalCount: Int { threats.filter { $0.severity == .critical }.count }
    var warningCount: Int { threats.filter { $0.severity == .warning }.count }

    var statusMessage: String {
        if !scanComplete { return "Run a scan to check for threats" }
        if threats.isEmpty { return "Your Mac is clean — no threats found" }
        if criticalCount > 0 { return "\(criticalCount) critical threat(s) found!" }
        return "\(threatCount) potential issue(s) found"
    }

    var statusColor: Color {
        if !scanComplete { return Theme.Colors.secondary }
        if threats.isEmpty { return Theme.Colors.success }
        if criticalCount > 0 { return Theme.Colors.destructive }
        return Theme.Colors.muted
    }

    func loadFromStore() {
        guard !scanComplete, let store = scanStore else { return }
        if store.moduleSummaries[.protect] != nil {
            threats = store.threats
            auditResult = store.auditResult
            scanComplete = true
        }
    }

    func checkDependencies() async {
        isClamAVInstalled = await dependencyManager.isInstalled(.clamav)
        isOsqueryInstalled = await dependencyManager.isInstalled(.osquery)
    }

    func installClamAV() async {
        isInstallingClamAV = true
        installError = nil
        do {
            try await dependencyManager.install(.clamav)
            isClamAVInstalled = true
        } catch {
            installError = error.localizedDescription
        }
        isInstallingClamAV = false
    }

    func scan() async {
        isScanning = true
        scanComplete = false
        errorMessage = nil
        threats = await service.scan()
        auditResult = await osqueryService.audit()
        isScanning = false
        scanComplete = true

        // Update global store
        scanStore?.threats = threats
        scanStore?.auditResult = auditResult
        let issues = threats.prefix(3).map { $0.name }
        scanStore?.updateSummary(ModuleScanSummary(
            module: .protect, itemCount: threats.count, totalSize: 0,
            issues: Array(issues), timestamp: Date()
        ))
    }

    func removeThreats() async {
        isRemoving = true
        errorMessage = nil
        let selected = threats.filter(\.isSelected)
        let removed = await service.remove(threats: selected)
        if removed < selected.count {
            errorMessage = "Some threats could not be removed."
        }
        threats.removeAll { $0.isSelected }
        isRemoving = false
        scanStore?.invalidate(.protect)
    }

    func toggleThreat(_ id: UUID) {
        if let index = threats.firstIndex(where: { $0.id == id }) {
            threats[index].isSelected.toggle()
        }
    }
}
