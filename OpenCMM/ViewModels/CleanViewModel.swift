import SwiftUI

@MainActor
class CleanViewModel: ObservableObject {
    @Published var scanResults: [ScanResult] = []
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var scanComplete = false
    @Published var lastCleanedSize: Int64 = 0

    private let service = CleaningService()

    var totalSize: Int64 {
        scanResults.filter(\.isSelected).reduce(0) { $0 + $1.totalSize }
    }

    var totalItems: Int {
        scanResults.filter(\.isSelected).flatMap(\.items).count
    }

    func scan() async {
        isScanning = true
        scanComplete = false
        scanResults = await service.scan()
        isScanning = false
        scanComplete = true
    }

    func clean() async {
        isCleaning = true
        let selectedItems = scanResults.filter(\.isSelected).flatMap { $0.items.filter(\.isSelected) }
        let result = await service.clean(items: selectedItems)
        lastCleanedSize = result.freedBytes
        scanResults = []
        scanComplete = false
        isCleaning = false
    }

    func toggleCategory(_ index: Int) {
        guard scanResults.indices.contains(index) else { return }
        scanResults[index].isSelected.toggle()
    }
}
