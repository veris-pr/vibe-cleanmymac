import Foundation

/// Integrates gdu for disk usage analysis with JSON directory tree output.
actor SpaceLensService {
    private let deps = DependencyManager.shared

    struct DiskNode: Identifiable {
        let id = UUID()
        let name: String
        let path: String
        let size: Int64
        let isDirectory: Bool
        var children: [DiskNode]
        var isExpanded: Bool = false

        var formattedSize: String { Formatters.fileSize(size) }

        // Percentage of parent
        func percentage(of parentSize: Int64) -> Double {
            guard parentSize > 0 else { return 0 }
            return Double(size) / Double(parentSize) * 100
        }
    }

    var isAvailable: Bool {
        get async { await deps.isInstalled(.gdu) }
    }

    func analyze(path: String = FileUtils.homeDirectory()) async -> DiskNode? {
        guard let gdu = await deps.path(for: .gdu) else {
            return await analyzeFallback(path: path)
        }

        // gdu -o- outputs JSON to stdout
        guard let output = try? ShellExecutor.shell("\(gdu) -o- \"\(path)\" 2>/dev/null"),
              let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return await analyzeFallback(path: path)
        }

        return parseGduNode(json)
    }

    /// Quick top-level scan without gdu (native Swift fallback)
    func analyzeFallback(path: String) async -> DiskNode? {
        let url = URL(fileURLWithPath: path)
        var children: [DiskNode] = []

        for entry in FileUtils.contentsOfDirectory(path) {
            let fullPath = "\(path)/\(entry)"
            let isDir = FileUtils.isDirectory(fullPath)
            let size = isDir ? FileUtils.directorySize(at: fullPath) : FileUtils.fileSize(at: fullPath)
            guard size > 0 else { continue }
            children.append(DiskNode(
                name: entry, path: fullPath, size: size,
                isDirectory: isDir, children: []
            ))
        }

        children.sort { $0.size > $1.size }
        let totalSize = children.reduce(0) { $0 + $1.size }

        return DiskNode(
            name: url.lastPathComponent, path: path, size: totalSize,
            isDirectory: true, children: children
        )
    }

    // MARK: - Parsing

    private func parseGduNode(_ json: [String: Any]) -> DiskNode? {
        guard let name = json["name"] as? String else { return nil }

        let isDir = json["isDir"] as? Bool ?? false
        let size = json["size"] as? Int64 ?? 0
        var children: [DiskNode] = []

        if let childArray = json["children"] as? [[String: Any]] {
            children = childArray.compactMap { parseGduNode($0) }
            children.sort { $0.size > $1.size }
        }

        let path: String
        if let p = json["path"] as? String {
            path = p
        } else {
            path = name
        }

        return DiskNode(
            name: name, path: path, size: size,
            isDirectory: isDir, children: children
        )
    }
}
