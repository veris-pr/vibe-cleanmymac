import Foundation

actor CleaningService {
    private let home = FileUtils.homeDirectory()

    func scan() async -> [ScanResult] {
        var results: [ScanResult] = []

        results.append(scanSystemCaches())
        results.append(scanUserCaches())
        results.append(scanBrowserCaches())
        results.append(scanSystemLogs())
        results.append(scanUserLogs())
        results.append(scanXcodeData())
        results.append(scanTrash())

        return results.filter { !$0.items.isEmpty }
    }

    func clean(items: [CleanableItem]) async -> (cleaned: Int, freedBytes: Int64) {
        var cleaned = 0
        var freed: Int64 = 0
        for item in items where item.isSelected {
            do {
                try FileUtils.moveToTrash(item.path)
                cleaned += 1
                freed += item.size
            } catch {
                // Log but continue with other items
                print("Failed to clean \(item.path): \(error.localizedDescription)")
            }
        }
        return (cleaned, freed)
    }

    // MARK: - Scan Helpers

    private func scanSystemCaches() -> ScanResult {
        let paths = [
            "/Library/Caches",
        ]
        let items = scanPaths(paths, category: .systemCache)
        return ScanResult(category: "System Cache", items: items)
    }

    private func scanUserCaches() -> ScanResult {
        let paths = [
            "\(home)/Library/Caches",
        ]
        var items: [CleanableItem] = []
        for basePath in paths {
            for entry in FileUtils.contentsOfDirectory(basePath) {
                let fullPath = "\(basePath)/\(entry)"
                guard FileUtils.isDirectory(fullPath) else { continue }
                let size = FileUtils.directorySize(at: fullPath)
                if size > 1_000_000 { // Only show items > 1MB
                    items.append(CleanableItem(
                        name: entry,
                        path: fullPath,
                        size: size,
                        category: .userCache
                    ))
                }
            }
        }
        return ScanResult(category: "User Cache", items: items.sorted { $0.size > $1.size })
    }

    private func scanBrowserCaches() -> ScanResult {
        let browserPaths: [(String, String)] = [
            ("Safari", "\(home)/Library/Caches/com.apple.Safari"),
            ("Chrome", "\(home)/Library/Caches/Google/Chrome"),
            ("Firefox", "\(home)/Library/Caches/Firefox/Profiles"),
            ("Edge", "\(home)/Library/Caches/Microsoft Edge"),
            ("Brave", "\(home)/Library/Caches/BraveSoftware"),
            ("Arc", "\(home)/Library/Caches/company.thebrowser.Browser"),
        ]
        var items: [CleanableItem] = []
        for (name, path) in browserPaths {
            guard FileUtils.exists(path) else { continue }
            let size = FileUtils.directorySize(at: path)
            if size > 0 {
                items.append(CleanableItem(name: "\(name) Cache", path: path, size: size, category: .browserCache))
            }
        }
        return ScanResult(category: "Browser Cache", items: items)
    }

    private func scanSystemLogs() -> ScanResult {
        let paths = [
            "/Library/Logs",
            "/var/log",
        ]
        let items = scanPaths(paths, category: .systemLogs)
        return ScanResult(category: "System Logs", items: items)
    }

    private func scanUserLogs() -> ScanResult {
        let path = "\(home)/Library/Logs"
        var items: [CleanableItem] = []
        for entry in FileUtils.contentsOfDirectory(path) {
            let fullPath = "\(path)/\(entry)"
            let size = FileUtils.isDirectory(fullPath)
                ? FileUtils.directorySize(at: fullPath)
                : FileUtils.fileSize(at: fullPath)
            if size > 100_000 {
                items.append(CleanableItem(name: entry, path: fullPath, size: size, category: .userLogs))
            }
        }
        return ScanResult(category: "User Logs", items: items.sorted { $0.size > $1.size })
    }

    private func scanXcodeData() -> ScanResult {
        let xcodePaths: [(String, String)] = [
            ("Derived Data", "\(home)/Library/Developer/Xcode/DerivedData"),
            ("iOS Device Support", "\(home)/Library/Developer/Xcode/iOS DeviceSupport"),
            ("watchOS Device Support", "\(home)/Library/Developer/Xcode/watchOS DeviceSupport"),
            ("Archives", "\(home)/Library/Developer/Xcode/Archives"),
            ("CoreSimulator Caches", "\(home)/Library/Developer/CoreSimulator/Caches"),
        ]
        var items: [CleanableItem] = []
        for (name, path) in xcodePaths {
            guard FileUtils.exists(path) else { continue }
            let size = FileUtils.directorySize(at: path)
            if size > 0 {
                items.append(CleanableItem(name: name, path: path, size: size, category: .xcodeData))
            }
        }
        return ScanResult(category: "Xcode Data", items: items)
    }

    private func scanTrash() -> ScanResult {
        let trashPath = "\(home)/.Trash"
        guard FileUtils.exists(trashPath) else { return ScanResult(category: "Trash", items: []) }
        let size = FileUtils.directorySize(at: trashPath)
        var items: [CleanableItem] = []
        if size > 0 {
            items.append(CleanableItem(name: "Trash", path: trashPath, size: size, category: .trash))
        }
        return ScanResult(category: "Trash", items: items)
    }

    private func scanPaths(_ paths: [String], category: CleanCategory) -> [CleanableItem] {
        var items: [CleanableItem] = []
        for path in paths {
            guard FileUtils.exists(path) else { continue }
            let size = FileUtils.directorySize(at: path)
            if size > 0 {
                let name = URL(fileURLWithPath: path).lastPathComponent
                items.append(CleanableItem(name: name, path: path, size: size, category: category))
            }
        }
        return items
    }
}
