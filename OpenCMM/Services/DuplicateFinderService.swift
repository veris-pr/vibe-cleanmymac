import Foundation
import CryptoKit

actor DuplicateFinderService {
    private let home = FileUtils.homeDirectory()

    func findDuplicates(in paths: [String]? = nil) async -> [DuplicateGroup] {
        let searchPaths = paths ?? [
            "\(home)/Documents",
            "\(home)/Downloads",
            "\(home)/Desktop",
        ]

        var hashMap: [String: [DuplicateFile]] = [:]
        var sizeMap: [Int64: [String]] = [:]

        // Phase 1: Group by file size (fast filter)
        for basePath in searchPaths {
            guard FileUtils.exists(basePath) else { continue }
            collectFiles(at: basePath, into: &sizeMap)
        }

        // Phase 2: Hash only files with matching sizes
        for (size, paths) in sizeMap where paths.count > 1 {
            for path in paths {
                guard let hash = hashFile(at: path) else { continue }
                let name = URL(fileURLWithPath: path).lastPathComponent
                let modDate = FileUtils.modificationDate(at: path) ?? Date.distantPast
                let file = DuplicateFile(path: path, name: name, size: size, modifiedDate: modDate)
                hashMap[hash, default: []].append(file)
            }
        }

        // Phase 3: Build groups (only actual duplicates)
        return hashMap.compactMap { (hash, files) -> DuplicateGroup? in
            guard files.count > 1 else { return nil }
            var group = DuplicateGroup(hash: hash, fileSize: files[0].size, files: files)
            // Auto-mark the newest file as "keep"
            if let newestIndex = group.files.indices.max(by: { group.files[$0].modifiedDate < group.files[$1].modifiedDate }) {
                group.files[newestIndex].keepThis = true
            }
            return group
        }.sorted { $0.wastedSpace > $1.wastedSpace }
    }

    func findLargeFiles(minSize: Int64 = 100_000_000) async -> [LargeFile] {
        let searchPaths = [
            "\(home)/Documents",
            "\(home)/Downloads",
            "\(home)/Desktop",
            "\(home)/Movies",
        ]

        var largeFiles: [LargeFile] = []
        for basePath in searchPaths {
            guard FileUtils.exists(basePath) else { continue }
            findLargeFilesRecursive(at: basePath, minSize: minSize, into: &largeFiles)
        }
        return largeFiles.sorted { $0.size > $1.size }
    }

    func removeDuplicates(_ groups: [DuplicateGroup]) async -> (removed: Int, freed: Int64) {
        var removed = 0
        var freed: Int64 = 0
        for group in groups {
            for file in group.files where !file.keepThis {
                do {
                    try FileUtils.moveToTrash(file.path)
                    removed += 1
                    freed += file.size
                } catch {
                    print("Failed to remove \(file.path): \(error.localizedDescription)")
                }
            }
        }
        return (removed, freed)
    }

    // MARK: - Helpers

    private func collectFiles(at path: String, into sizeMap: inout [Int64: [String]], maxDepth: Int = 5) {
        guard maxDepth > 0 else { return }
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  resourceValues.isRegularFile == true,
                  let fileSize = resourceValues.fileSize,
                  fileSize > 1024 else { continue } // Skip tiny files
            sizeMap[Int64(fileSize), default: []].append(fileURL.path)
        }
    }

    private func hashFile(at path: String) -> String? {
        guard let fileHandle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { fileHandle.closeFile() }

        var hasher = SHA256()
        // Hash first 64KB for speed, full hash for small files
        let chunkSize = 65536
        if let data = try? fileHandle.read(upToCount: chunkSize) {
            hasher.update(data: data)
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func findLargeFilesRecursive(at path: String, minSize: Int64, into results: inout [LargeFile]) {
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .contentAccessDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .contentAccessDateKey]),
                  values.isRegularFile == true,
                  let fileSize = values.fileSize,
                  Int64(fileSize) >= minSize else { continue }

            results.append(LargeFile(
                path: fileURL.path,
                name: fileURL.lastPathComponent,
                size: Int64(fileSize),
                lastAccessed: values.contentAccessDate ?? Date.distantPast
            ))
        }
    }
}
