import Foundation

/// Integrates gdu for disk usage analysis with JSON directory tree output.
actor SpaceLensService {
    private let dependencyManager = DependencyManager.shared

    var isAvailable: Bool {
        get async { await dependencyManager.isInstalled(.gdu) }
    }

    func analyze(path: String = FileUtils.homeDirectory()) async -> DiskNode? {
        guard let gdu = await dependencyManager.path(for: .gdu) else {
            return await analyzeFallback(path: path)
        }

        // gdu -o- outputs JSON to stdout
        guard let output = try? ShellExecutor.shell("\(gdu) -o- \(ShellExecutor.quote(path)) 2>/dev/null"),
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
