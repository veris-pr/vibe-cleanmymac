import SwiftUI

@MainActor
class SpaceLensViewModel: ObservableObject {
    @Published var rootNode: DiskNode?
    @Published var isScanning = false
    @Published var isGduInstalled = false
    @Published var isInstallingGdu = false
    @Published var installError: String?
    @Published var errorMessage: String?

    private let service = SpaceLensService()
    private let dependencyManager = DependencyManager.shared
    private var scanTask: Task<Void, Never>?

    func checkDependencies() async {
        isGduInstalled = await dependencyManager.isInstalled(.gdu)
    }

    func installGdu() async {
        isInstallingGdu = true
        installError = nil
        do {
            try await dependencyManager.install(.gdu)
            isGduInstalled = true
        } catch {
            installError = error.localizedDescription
        }
        isInstallingGdu = false
    }

    func startScan(path: String? = nil) {
        scanTask?.cancel()
        scanTask = Task { await scan(path: path) }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }

    private func scan(path: String? = nil) async {
        isScanning = true
        errorMessage = nil
        let scanPath = path ?? FileUtils.homeDirectory()
        rootNode = await service.analyze(path: scanPath)
        guard !Task.isCancelled else { return }
        isScanning = false
    }
}
