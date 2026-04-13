import SwiftUI

@MainActor
class CleanViewModel: ObservableObject {
    @Published var scanResults: [ScanResult] = []
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var scanComplete = false
    @Published var lastCleanedSize: Int64 = 0
    @Published var errorMessage: String?
    @Published var showConfirmation = false
    @Published var expandedSections: Set<UUID> = []

    var scanStore: ScanStore?

    private let service = CleaningService()

    var totalSize: Int64 {
        scanResults.filter(\.isSelected).reduce(0) { total, result in
            total + result.items.filter(\.isSelected).reduce(0) { $0 + $1.size }
        }
    }

    var totalItems: Int {
        scanResults.filter(\.isSelected).flatMap { $0.items.filter(\.isSelected) }.count
    }

    func scan() async {
        isScanning = true
        scanComplete = false
        errorMessage = nil
        scanResults = await service.scan()
        // Expand all sections by default
        expandedSections = Set(scanResults.map(\.id))
        isScanning = false
        scanComplete = true

        // Update dashboard
        let totalSz = scanResults.reduce(0) { $0 + $1.totalSize }
        let count = scanResults.reduce(0) { $0 + $1.items.count }
        let issues = scanResults.map { "\($0.category): \(Formatters.fileSize($0.totalSize))" }
        scanStore?.updateSummary(ModuleScanSummary(
            module: .clean, itemCount: count, totalSize: totalSz,
            issues: issues, timestamp: Date()
        ))
    }

    func clean() async {
        isCleaning = true
        errorMessage = nil
        let selectedItems = scanResults.filter(\.isSelected).flatMap { $0.items.filter(\.isSelected) }
        let result = await service.clean(items: selectedItems)
        lastCleanedSize = result.freedBytes
        scanResults = []
        scanComplete = false
        isCleaning = false
        scanStore?.invalidate(.clean)
    }

    func toggleCategory(_ index: Int) {
        guard scanResults.indices.contains(index) else { return }
        scanResults[index].isSelected.toggle()
        // Sync all items in category
        let newState = scanResults[index].isSelected
        for i in scanResults[index].items.indices {
            scanResults[index].items[i].isSelected = newState
        }
    }

    func toggleItem(_ id: UUID) {
        for sectionIdx in scanResults.indices {
            if let itemIdx = scanResults[sectionIdx].items.firstIndex(where: { $0.id == id }) {
                scanResults[sectionIdx].items[itemIdx].isSelected.toggle()
                // Update section toggle if all items are deselected
                let anySelected = scanResults[sectionIdx].items.contains(where: \.isSelected)
                scanResults[sectionIdx].isSelected = anySelected
                return
            }
        }
    }

    func toggleSection(_ id: UUID) {
        if expandedSections.contains(id) {
            expandedSections.remove(id)
        } else {
            expandedSections.insert(id)
        }
    }
}
