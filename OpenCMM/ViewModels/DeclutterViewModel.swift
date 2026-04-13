import SwiftUI

@MainActor
class DeclutterViewModel: ObservableObject {
    @Published var duplicateGroups: [DuplicateGroup] = []
    @Published var largeFiles: [LargeFile] = []
    @Published var isScanning = false
    @Published var isRemoving = false
    @Published var scanComplete = false
    @Published var selectedTab: DeclutterTab = .duplicates

    private let service = DuplicateFinderService()

    var totalWastedSpace: Int64 {
        duplicateGroups.reduce(0) { $0 + $1.wastedSpace }
    }

    var totalLargeFilesSize: Int64 {
        largeFiles.filter(\.isSelected).reduce(0) { $0 + $1.size }
    }

    func scan() async {
        isScanning = true
        scanComplete = false
        async let dupes = service.findDuplicates()
        async let large = service.findLargeFiles()
        duplicateGroups = await dupes
        largeFiles = await large
        isScanning = false
        scanComplete = true
    }

    func removeDuplicates() async {
        isRemoving = true
        _ = await service.removeDuplicates(duplicateGroups)
        duplicateGroups.removeAll()
        isRemoving = false
    }

    func removeLargeFiles() async {
        isRemoving = true
        for file in largeFiles where file.isSelected {
            do { try FileUtils.moveToTrash(file.path) } catch {}
        }
        largeFiles.removeAll { $0.isSelected }
        isRemoving = false
    }

    func toggleLargeFile(_ id: UUID) {
        if let index = largeFiles.firstIndex(where: { $0.id == id }) {
            largeFiles[index].isSelected.toggle()
        }
    }
}

enum DeclutterTab: String, CaseIterable {
    case duplicates = "Duplicates"
    case largeFiles = "Large Files"
}
