import Foundation

enum FileUtils {
    static let fileManager = FileManager.default

    static func directorySize(at path: String) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else { return 0 }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  resourceValues.isRegularFile == true,
                  let fileSize = resourceValues.fileSize else { continue }
            totalSize += Int64(fileSize)
        }
        return totalSize
    }

    static func fileSize(at path: String) -> Int64 {
        guard let attrs = try? fileManager.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64 else { return 0 }
        return size
    }

    static func exists(_ path: String) -> Bool {
        fileManager.fileExists(atPath: path)
    }

    static func isDirectory(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        return fileManager.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    static func moveToTrash(_ path: String) throws {
        var resultingURL: NSURL?
        try fileManager.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: &resultingURL)
    }

    static func removeItem(_ path: String) throws {
        try fileManager.removeItem(atPath: path)
    }

    static func contentsOfDirectory(_ path: String) -> [String] {
        (try? fileManager.contentsOfDirectory(atPath: path)) ?? []
    }

    static func homeDirectory() -> String {
        fileManager.homeDirectoryForCurrentUser.path
    }

    static func modificationDate(at path: String) -> Date? {
        guard let attrs = try? fileManager.attributesOfItem(atPath: path),
              let date = attrs[.modificationDate] as? Date else { return nil }
        return date
    }
}
