import SwiftUI

@MainActor
class DeclutterViewModel: ObservableObject {
    @Published var duplicateGroups: [DuplicateGroup] = []
    @Published var largeFiles: [LargeFile] = []
    @Published var similarImages: [SimilarGroup] = []
    @Published var tempFiles: [TempFileResult] = []
    @Published var isScanning = false
    @Published var isRemoving = false
    @Published var scanComplete = false
    @Published var selectedTab: DeclutterTab = .duplicates
    @Published var isFclonesInstalled = false
    @Published var isCzkawkaInstalled = false
    @Published var isInstallingFclones = false
    @Published var isInstallingCzkawka = false
    @Published var installError: String?
    @Published var errorMessage: String?
    @Published var showConfirmation = false
    @Published var largeSortOrder: LargeSortOrder = .size

    var scanStore: ScanStore?

    private let service = DuplicateFinderService()
    private let czkawkaService = CzkawkaService()
    private let dependencyManager = DependencyManager.shared
    private var scanTask: Task<Void, Never>?

    var totalWastedSpace: Int64 {
        duplicateGroups.reduce(0) { $0 + $1.wastedSpace }
    }

    func loadFromStore() {
        guard !scanComplete, let store = scanStore, !store.duplicateGroups.isEmpty else { return }
        duplicateGroups = store.duplicateGroups
        largeFiles = store.largeFiles
        similarImages = store.similarImages
        tempFiles = store.tempFiles
        scanComplete = true
    }

    var totalLargeFilesSize: Int64 {
        largeFiles.filter(\.isSelected).reduce(0) { $0 + $1.size }
    }

    var totalTempFilesSize: Int64 {
        tempFiles.filter(\.isSelected).reduce(0) { $0 + $1.size }
    }

    func toggleTempFile(_ id: UUID) {
        if let idx = tempFiles.firstIndex(where: { $0.id == id }) {
            tempFiles[idx].isSelected.toggle()
        }
    }

    var sortedLargeFiles: [LargeFile] {
        switch largeSortOrder {
        case .size:
            return largeFiles.sorted { $0.size > $1.size }
        case .date:
            return largeFiles.sorted { $0.lastAccessed > $1.lastAccessed }
        }
    }

    func checkDependencies() async {
        isFclonesInstalled = await dependencyManager.isInstalled(.fclones)
        isCzkawkaInstalled = await dependencyManager.isInstalled(.czkawka)
    }

    func installFclones() async {
        isInstallingFclones = true
        installError = nil
        do {
            try await dependencyManager.install(.fclones)
            isFclonesInstalled = true
        } catch {
            installError = error.localizedDescription
        }
        isInstallingFclones = false
    }

    func installCzkawka() async {
        isInstallingCzkawka = true
        installError = nil
        do {
            try await dependencyManager.install(.czkawka)
            isCzkawkaInstalled = true
        } catch {
            installError = error.localizedDescription
        }
        isInstallingCzkawka = false
    }

    func startScan() {
        scanTask?.cancel()
        scanTask = Task { await scan() }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }

    private func scan() async {
        isScanning = true
        scanComplete = false
        errorMessage = nil
        async let dupes = service.findDuplicates(quickScan: false)
        async let large = service.findLargeFiles()
        async let similar = czkawkaService.findSimilarImages()
        async let temp = czkawkaService.findTempFiles()
        duplicateGroups = await dupes
        largeFiles = await large
        similarImages = await similar
        tempFiles = await temp
        guard !Task.isCancelled else { return }
        isScanning = false
        scanComplete = true

        // Update global store
        scanStore?.duplicateGroups = duplicateGroups
        scanStore?.largeFiles = largeFiles
        scanStore?.similarImages = similarImages
        scanStore?.tempFiles = tempFiles
        let wastedSpace = duplicateGroups.reduce(0) { $0 + $1.wastedSpace }
        let issues = duplicateGroups.prefix(3).map { "\($0.files.count) copies · \(Formatters.fileSize($0.wastedSpace))" }
        scanStore?.updateSummary(ModuleScanSummary(
            module: .declutter, itemCount: duplicateGroups.count, totalSize: wastedSpace,
            issues: Array(issues), timestamp: Date()
        ))
    }

    func removeDuplicates() async {
        isRemoving = true
        errorMessage = nil
        _ = await service.removeDuplicates(duplicateGroups)
        duplicateGroups.removeAll()
        isRemoving = false
        scanStore?.invalidate(.declutter)
    }

    func removeLargeFiles() async {
        await removeFiles(
            largeFiles.filter(\.isSelected).map { (path: $0.path, name: $0.name) }
        ) { largeFiles.removeAll { $0.isSelected } }
    }

    func removeSimilarImages() async {
        let toRemove = similarImages.flatMap { group in
            group.files.filter { !$0.keepThis }.map { (path: $0.path, name: $0.name) }
        }
        await removeFiles(toRemove) { similarImages.removeAll() }
    }

    func removeTempFiles() async {
        await removeFiles(
            tempFiles.filter(\.isSelected).map { (path: $0.path, name: $0.name) }
        ) { tempFiles.removeAll { $0.isSelected } }
    }

    private func removeFiles(_ files: [(path: String, name: String)], clear: () -> Void) async {
        isRemoving = true
        errorMessage = nil
        for file in files {
            do {
                try FileUtils.moveToTrash(file.path)
            } catch {
                errorMessage = "Failed to remove \(file.name): \(error.localizedDescription)"
            }
        }
        clear()
        isRemoving = false
        scanStore?.invalidate(.declutter)
    }

    func toggleLargeFile(_ id: UUID) {
        if let index = largeFiles.firstIndex(where: { $0.id == id }) {
            largeFiles[index].isSelected.toggle()
        }
    }

    func toggleKeep(groupId: UUID, fileId: UUID) {
        if let gIdx = similarImages.firstIndex(where: { $0.id == groupId }) {
            if let fIdx = similarImages[gIdx].files.firstIndex(where: { $0.id == fileId }) {
                similarImages[gIdx].files[fIdx].keepThis.toggle()
            }
        }
    }
}

enum DeclutterTab: String, CaseIterable {
    case duplicates = "Duplicates"
    case similarImages = "Similar Images"
    case largeFiles = "Large Files"
    case tempFiles = "Temp Files"
}

enum LargeSortOrder: String, CaseIterable {
    case size = "Size"
    case date = "Date"
}
