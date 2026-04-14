import Foundation
import AppKit

/// Represents a macOS application that can be uninstalled.
struct InstalledApp: Identifiable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String
    let path: String
    let icon: NSImage?
    let size: Int64
    let isSelected: Bool = false

    /// Known locations where apps leave behind data.
    var relatedPaths: [AppLeftover] = []

    var totalSize: Int64 {
        size + relatedPaths.reduce(0) { $0 + $1.size }
    }

    var leftoverSize: Int64 {
        relatedPaths.reduce(0) { $0 + $1.size }
    }
}

/// A leftover file/directory associated with an app.
struct AppLeftover: Identifiable {
    let id = UUID()
    let path: String
    let category: LeftoverCategory
    let size: Int64

    var name: String {
        (path as NSString).lastPathComponent
    }

    enum LeftoverCategory: String, CaseIterable {
        case appSupport = "Application Support"
        case caches = "Caches"
        case preferences = "Preferences"
        case logs = "Logs"
        case containers = "Containers"
        case crashReports = "Crash Reports"
        case savedState = "Saved State"
        case launchItems = "Launch Items"
        case other = "Other"
    }
}
