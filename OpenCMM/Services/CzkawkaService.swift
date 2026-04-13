import Foundation

/// Integrates czkawka-cli for similar image/video/music detection and temp file cleanup.
actor CzkawkaService {
    private let dependencyManager = DependencyManager.shared
    private let home = FileUtils.homeDirectory()

    var isAvailable: Bool {
        get async { await dependencyManager.isInstalled(.czkawka) }
    }

    func findSimilarImages(in paths: [String]? = nil) async -> [SimilarGroup] {
        guard let cli = await dependencyManager.path(for: .czkawka) else { return [] }
        let searchPaths = paths ?? ["\(home)/Pictures", "\(home)/Photos", "\(home)/Desktop", "\(home)/Downloads"]
        let existingPaths = searchPaths.filter { FileUtils.exists($0) }
        guard !existingPaths.isEmpty else { return [] }

        let dirArgs = existingPaths.map { "-d \(ShellExecutor.quote($0))" }.joined(separator: " ")
        guard let output = try? await ShellExecutor.shellAsync("\(cli) similar-images \(dirArgs) --json-compact 2>/dev/null") else { return [] }
        return parseSimilarGroups(output)
    }

    func findTempFiles(in paths: [String]? = nil) async -> [TempFileResult] {
        guard let cli = await dependencyManager.path(for: .czkawka) else { return [] }
        let searchPaths = paths ?? ["\(home)/Downloads", "\(home)/Desktop", "\(home)/Documents", "/tmp"]
        let existingPaths = searchPaths.filter { FileUtils.exists($0) }
        guard !existingPaths.isEmpty else { return [] }

        let dirArgs = existingPaths.map { "-d \(ShellExecutor.quote($0))" }.joined(separator: " ")
        guard let output = try? await ShellExecutor.shellAsync("\(cli) temporary \(dirArgs) --json-compact 2>/dev/null") else { return [] }
        return parseTempFiles(output)
    }

    // MARK: - Parsing

    private func parseSimilarGroups(_ output: String) -> [SimilarGroup] {
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return json.compactMap { group in
            guard let files = group["files"] as? [[String: Any]], files.count > 1 else { return nil }
            let similarity = group["similarity"] as? Double ?? 0

            var similarFiles = files.map { fileDict -> SimilarFile in
                let path = fileDict["path"] as? String ?? ""
                let size = fileDict["size"] as? Int64 ?? FileUtils.fileSize(at: path)
                let modDate = FileUtils.modificationDate(at: path) ?? Date.distantPast
                return SimilarFile(
                    path: path,
                    name: URL(fileURLWithPath: path).lastPathComponent,
                    size: size,
                    modifiedDate: modDate
                )
            }

            // Mark newest as keep
            if let newestIdx = similarFiles.indices.max(by: { similarFiles[$0].modifiedDate < similarFiles[$1].modifiedDate }) {
                similarFiles[newestIdx].keepThis = true
            }

            return SimilarGroup(files: similarFiles, similarity: similarity)
        }
    }

    private func parseTempFiles(_ output: String) -> [TempFileResult] {
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return json.compactMap { item in
            guard let path = item["path"] as? String else { return nil }
            let size = item["size"] as? Int64 ?? FileUtils.fileSize(at: path)
            return TempFileResult(
                path: path,
                name: URL(fileURLWithPath: path).lastPathComponent,
                size: size
            )
        }
    }
}
