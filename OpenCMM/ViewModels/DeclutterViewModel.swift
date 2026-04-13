import SwiftUI

@MainActor
class DeclutterViewModel: ObservableObject {
    @Published var duplicateGroups: [DuplicateGroup] = []
    @Published var largeFiles: [LargeFile] = []
    @Published var similarImages: [CzkawkaService.SimilarGroup] = []
    @Published var tempFiles: [CzkawkaService.TempFileResult] = []
    @Published var isScanning = false
    @Published var isRemoving = false
    @Published var scanComplete = false
    @Published var selectedTab: DeclutterTab = .duplicates
    @Published var isFclonesInstalled = false
    @Published var isCzkawkaInstalled = false
    @Published var isInstallingFclones = false
    @Published var installError: String?
    @Published var errorMessage: String?
    @Published var showConfirmation = false
    @Published var largeSortOrder: LargeSortOrder = .size

    var scanStore: ScanStore?

    private let service = DuplicateFinderService()
    private let czkawkaService = CzkawkaService()
    private let deps = DependencyManager.shared

    var totalWastedSpace: Int64 {
        duplicateGroups.reduce(0) { $0 + $1.wastedSpace }
    }

    var totalLargeFilesSize: Int64 {
        largeFiles.filter(\.isSelected).reduce(0) { $0 + $1.size }
    }

    var totalTempFilesSize: Int64 {
        tempFiles.reduce(0) { $0 + $1.size }
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
        isFclonesInstalled = await deps.isInstalled(.fclones)
        isCzkawkaInstalled = await deps.isInstalled(.czkawka)
    }

    func installFclones() async {
        isInstallingFclones = true
        installError = nil
        do {
            try await deps.install(.fclones)
            isFclonesInstalled = true
        } catch {
            installError = error.localizedDescription
        }
        isInstallingFclones = false
    }

    func scan() async {
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
        isScanning = false
        scanComplete = true

        // Update dashboard
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
        do {
            _ = await service.removeDuplicates(duplicateGroups)
            duplicateGroups.removeAll()
        }
        isRemoving = false
        scanStore?.invalidate(.declutter)
    }

    func removeLargeFiles() async {
        isRemoving = true
        errorMessage = nil
        for file in largeFiles where file.isSelected {
            do {
                try FileUtils.moveToTrash(file.path)
            } catch {
                errorMessage = "Failed to remove \(file.name): \(error.localizedDescription)"
            }
        }
        largeFiles.removeAll { $0.isSelected }
        isRemoving = false
        scanStore?.invalidate(.declutter)
    }

    func removeSimilarImages() async {
        isRemoving = true
        errorMessage = nil
        for group in similarImages {
            for file in group.files where !file.keepThis {
                do {
                    try FileUtils.moveToTrash(file.path)
                } catch {
                    errorMessage = "Failed to remove \(file.name): \(error.localizedDescription)"
                }
            }
        }
        similarImages.removeAll()
        isRemoving = false
        scanStore?.invalidate(.declutter)
    }

    func removeTempFiles() async {
        isRemoving = true
        errorMessage = nil
        for file in tempFiles {
            do {
                try FileUtils.moveToTrash(file.path)
            } catch {
                errorMessage = "Failed to remove \(file.name): \(error.localizedDescription)"
            }
        }
        tempFiles.removeAll()
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
