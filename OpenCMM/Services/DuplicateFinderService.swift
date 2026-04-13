import Foundation
import CryptoKit
import os

private let logger = Logger(subsystem: "com.opencmm.app", category: "DuplicateFinderService")

actor DuplicateFinderService {
    private let home = FileUtils.homeDirectory()
    private let deps = DependencyManager.shared

    var isFclonesAvailable: Bool {
        get async { await deps.isInstalled(.fclones) }
    }

    func findDuplicates(in paths: [String]? = nil, quickScan: Bool = false) async -> [DuplicateGroup] {
        let searchPaths = paths ?? [
            "\(home)/Documents",
            "\(home)/Downloads",
            "\(home)/Desktop",
        ]

        // Use fclones if available (much faster and more accurate)
        if !quickScan, let fclones = await deps.path(for: .fclones) {
            return await findDuplicatesWithFclones(fclones, paths: searchPaths)
        }

        // Native implementation (quick mode uses partial hash)
        return await findDuplicatesNative(paths: searchPaths, quickScan: quickScan)
    }

    func findLargeFiles(minSize: Int64 = AppConstants.FileSize.minLargeFile) async -> [LargeFile] {
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
                    logger.error("Failed to remove \(file.path): \(error.localizedDescription)")
                }
            }
        }
        return (removed, freed)
    }

    // MARK: - fclones Integration

    private func findDuplicatesWithFclones(_ fclones: String, paths: [String]) async -> [DuplicateGroup] {
        let existingPaths = paths.filter { FileUtils.exists($0) }
        guard !existingPaths.isEmpty else { return [] }

        let pathArgs = existingPaths.map { "\"\($0)\"" }.joined(separator: " ")

        guard let output = try? ShellExecutor.shell(
            "\(fclones) group \(pathArgs) --format json 2>/dev/null"
        ), !output.isEmpty else {
            // Fall back to native if fclones fails
            return await findDuplicatesNative(paths: paths)
        }

        return parseFclonesOutput(output)
    }

    private func parseFclonesOutput(_ output: String) -> [DuplicateGroup] {
        // fclones JSON output: array of groups, each with "files" array and "file_len"
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            // Try line-based format as fallback
            return parseFclonesLineOutput(output)
        }

        return json.compactMap { group -> DuplicateGroup? in
            guard let files = group["files"] as? [String],
                  let fileLen = group["file_len"] as? Int64,
                  files.count > 1 else { return nil }

            var dupeFiles = files.map { path -> DuplicateFile in
                let name = URL(fileURLWithPath: path).lastPathComponent
                let modDate = FileUtils.modificationDate(at: path) ?? Date.distantPast
                return DuplicateFile(path: path, name: name, size: fileLen, modifiedDate: modDate)
            }

            // Mark newest as keep
            if let newestIdx = dupeFiles.indices.max(by: { dupeFiles[$0].modifiedDate < dupeFiles[$1].modifiedDate }) {
                dupeFiles[newestIdx].keepThis = true
            }

            return DuplicateGroup(hash: UUID().uuidString, fileSize: fileLen, files: dupeFiles)
        }.sorted { $0.wastedSpace > $1.wastedSpace }
    }

    private func parseFclonesLineOutput(_ output: String) -> [DuplicateGroup] {
        // fclones default output groups duplicates separated by blank lines
        var groups: [DuplicateGroup] = []
        var currentFiles: [String] = []

        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if currentFiles.count > 1 {
                    let group = buildGroupFromPaths(currentFiles)
                    if let group { groups.append(group) }
                }
                currentFiles = []
            } else {
                currentFiles.append(trimmed)
            }
        }
        // Handle last group
        if currentFiles.count > 1, let group = buildGroupFromPaths(currentFiles) {
            groups.append(group)
        }

        return groups.sorted { $0.wastedSpace > $1.wastedSpace }
    }

    private func buildGroupFromPaths(_ paths: [String]) -> DuplicateGroup? {
        var files: [DuplicateFile] = []
        for path in paths {
            let size = FileUtils.fileSize(at: path)
            guard size > 0 else { continue }
            let name = URL(fileURLWithPath: path).lastPathComponent
            let modDate = FileUtils.modificationDate(at: path) ?? Date.distantPast
            files.append(DuplicateFile(path: path, name: name, size: size, modifiedDate: modDate))
        }
        guard files.count > 1 else { return nil }

        if let newestIdx = files.indices.max(by: { files[$0].modifiedDate < files[$1].modifiedDate }) {
            files[newestIdx].keepThis = true
        }
        return DuplicateGroup(hash: UUID().uuidString, fileSize: files[0].size, files: files)
    }

    // MARK: - Native Swift Fallback

    private func findDuplicatesNative(paths: [String], quickScan: Bool = false) async -> [DuplicateGroup] {
        var sizeMap: [Int64: [String]] = [:]

        // Phase 1: Group by file size (skip tiny files in quick mode)
        let minFileSize: Int64 = quickScan ? AppConstants.FileSize.minDuplicateSizeQuick : AppConstants.FileSize.minDuplicateSize
        for basePath in paths {
            guard FileUtils.exists(basePath) else { continue }
            collectFiles(at: basePath, minSize: minFileSize, into: &sizeMap)
        }

        // Phase 2: Hash files with matching sizes
        var hashMap: [String: [DuplicateFile]] = [:]
        for (size, filePaths) in sizeMap where filePaths.count > 1 {
            for path in filePaths {
                guard let hash = quickScan ? hashFilePartial(at: path) : hashFile(at: path) else { continue }
                let name = URL(fileURLWithPath: path).lastPathComponent
                let modDate = FileUtils.modificationDate(at: path) ?? Date.distantPast
                let file = DuplicateFile(path: path, name: name, size: size, modifiedDate: modDate)
                hashMap[hash, default: []].append(file)
            }
        }

        // Phase 3: Build groups
        return hashMap.compactMap { (hash, files) -> DuplicateGroup? in
            guard files.count > 1 else { return nil }
            var group = DuplicateGroup(hash: hash, fileSize: files[0].size, files: files)
            if let newestIndex = group.files.indices.max(by: { group.files[$0].modifiedDate < group.files[$1].modifiedDate }) {
                group.files[newestIndex].keepThis = true
            }
            return group
        }.sorted { $0.wastedSpace > $1.wastedSpace }
    }

    private func collectFiles(at path: String, minSize: Int64 = 1024, into sizeMap: inout [Int64: [String]]) {
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let fileSize = values.fileSize,
                  Int64(fileSize) >= minSize else { continue }
            sizeMap[Int64(fileSize), default: []].append(fileURL.path)
        }
    }

    private func hashFile(at path: String) -> String? {
        guard let fileHandle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { fileHandle.closeFile() }

        var hasher = SHA256()
        while true {
            let chunk = fileHandle.readData(ofLength: 65536)
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Hash only the first 4KB — fast approximation for quick scans.
    private func hashFilePartial(at path: String) -> String? {
        guard let fileHandle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { fileHandle.closeFile() }

        let chunk = fileHandle.readData(ofLength: 4096)
        guard !chunk.isEmpty else { return nil }
        return SHA256.hash(data: chunk).map { String(format: "%02x", $0) }.joined()
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
                path: fileURL.path, name: fileURL.lastPathComponent,
                size: Int64(fileSize), lastAccessed: values.contentAccessDate ?? Date.distantPast
            ))
        }
    }
}
