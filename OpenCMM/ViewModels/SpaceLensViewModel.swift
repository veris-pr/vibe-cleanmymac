import SwiftUI

@MainActor
class SpaceLensViewModel: ObservableObject {
    @Published var rootNode: DiskNode?
    @Published var isScanning = false
    @Published var errorMessage: String?
    @Published var navigationPath: [DiskNode] = []

    private let service = SpaceLensService()
    private var scanTask: Task<Void, Never>?

    /// Current directory being viewed (root or a subdirectory).
    var currentNode: DiskNode? {
        navigationPath.last ?? rootNode
    }

    var breadcrumbs: [DiskNode] {
        if let root = rootNode {
            return [root] + navigationPath
        }
        return []
    }

    func startScan(path: String? = nil) {
        scanTask?.cancel()
        navigationPath = []
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

    /// Navigate into a subdirectory (lazy-load its children).
    func expandDirectory(_ node: DiskNode) {
        guard node.isDirectory else { return }
        isScanning = true
        scanTask = Task {
            let children = await service.scanDirectory(path: node.path)
            guard !Task.isCancelled else { return }
            let totalSize = children.reduce(0) { $0 + $1.size }
            let expanded = DiskNode(
                name: node.name, path: node.path, size: totalSize,
                isDirectory: true, children: children
            )
            navigationPath.append(expanded)
            isScanning = false
        }
    }

    /// Go back to a breadcrumb level.
    func navigateTo(index: Int) {
        if index == 0 {
            navigationPath = []
        } else if index <= navigationPath.count {
            navigationPath = Array(navigationPath.prefix(index))
        }
    }
}
