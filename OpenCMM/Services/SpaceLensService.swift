import Foundation

/// Analyzes disk usage with lazy directory expansion.
actor SpaceLensService {

    /// Scan a single directory level (non-recursive) — fast.
    func scanDirectory(path: String) async -> [DiskNode] {
        var children: [DiskNode] = []

        for entry in FileUtils.contentsOfDirectory(path) {
            let fullPath = "\(path)/\(entry)"
            let isDir = FileUtils.isDirectory(fullPath)
            let size: Int64

            if isDir {
                size = shallowDirectorySize(fullPath)
            } else {
                size = FileUtils.fileSize(at: fullPath)
            }

            guard size > 0 else { continue }
            children.append(DiskNode(
                name: entry, path: fullPath, size: size,
                isDirectory: isDir, children: []
            ))
        }

        children.sort { $0.size > $1.size }
        return children
    }

    /// Build root node for a path with its immediate children.
    func analyze(path: String = FileUtils.homeDirectory()) async -> DiskNode? {
        let children = await scanDirectory(path: path)
        let totalSize = children.reduce(0) { $0 + $1.size }
        let url = URL(fileURLWithPath: path)
        return DiskNode(
            name: url.lastPathComponent, path: path, size: totalSize,
            isDirectory: true, children: children
        )
    }

    /// Sum sizes of immediate children only (fast, no deep recursion).
    private func shallowDirectorySize(_ path: String) -> Int64 {
        var total: Int64 = 0
        for entry in FileUtils.contentsOfDirectory(path) {
            let fullPath = "\(path)/\(entry)"
            total += FileUtils.fileSize(at: fullPath)
        }
        return total
    }
}
