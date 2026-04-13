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

    private let service = MalwareScanService()
    private let deps = DependencyManager.shared

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

    func checkDependencies() async {
        isClamAVInstalled = await deps.clamavStatus().isInstalled
    }

    func installClamAV() async {
        isInstallingClamAV = true
        installError = nil
        do {
            try await deps.installClamAV()
            isClamAVInstalled = true
        } catch {
            installError = error.localizedDescription
        }
        isInstallingClamAV = false
    }

    func scan() async {
        isScanning = true
        scanComplete = false
        threats = await service.scan()
        isScanning = false
        scanComplete = true
    }

    func removeThreats() async {
        isRemoving = true
        let selected = threats.filter(\.isSelected)
        _ = await service.remove(threats: selected)
        threats.removeAll { $0.isSelected }
        isRemoving = false
    }

    func toggleThreat(_ id: UUID) {
        if let index = threats.firstIndex(where: { $0.id == id }) {
            threats[index].isSelected.toggle()
        }
    }
}
