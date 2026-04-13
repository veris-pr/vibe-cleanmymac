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

    func scan(path: String? = nil) async {
        isScanning = true
        errorMessage = nil
        let scanPath = path ?? FileUtils.homeDirectory()
        rootNode = await service.analyze(path: scanPath)
        isScanning = false
    }
}
