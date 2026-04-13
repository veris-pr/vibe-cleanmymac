import Foundation

/// Centralized configuration constants. Adjust thresholds here instead of hunting through code.
enum AppConstants {
    // MARK: - Health Score Thresholds
    enum Health {
        static let memoryWarning: Double = 75
        static let memoryCritical: Double = 90
        static let diskWarning: Double = 75
        static let diskCritical: Double = 90
        static let cpuWarning: Double = 70
        static let cpuCritical: Double = 90

        // Penalty points
        static let memoryCriticalPenalty = 30
        static let memoryWarningPenalty = 15
        static let memoryMildPenalty = 5
        static let diskCriticalPenalty = 30
        static let diskWarningPenalty = 15
        static let diskMildPenalty = 5
        static let cpuCriticalPenalty = 20
        static let cpuWarningPenalty = 10
    }

    // MARK: - Summary Thresholds (displayed in module cards)
    enum Summary {
        static let highMemoryPercent: Double = 80
        static let lowDiskPercent: Double = 80
        static let highCpuPercent: Double = 70
    }

    // MARK: - File Size Thresholds
    enum FileSize {
        static let minCacheSize: Int64 = 1_000_000         // 1 MB
        static let minLogSize: Int64 = 100_000              // 100 KB
        static let minLargeFile: Int64 = 100_000_000        // 100 MB
        static let minDuplicateSize: Int64 = 1024           // 1 KB (deep scan)
        static let minDuplicateSizeQuick: Int64 = 4096      // 4 KB (quick scan)
    }

    // MARK: - ClamAV Scan Limits
    enum ClamAV {
        static let maxFileSize = "50M"
        static let maxScanSize = "200M"
    }

    // MARK: - Timing
    enum Timing {
        static let autoRefreshInterval: UInt64 = 5_000_000_000  // 5 seconds
        static let statusMessageDelay: UInt64 = 2_000_000_000   // 2 seconds
        static let completionDelay: UInt64 = 800_000_000        // 0.8 seconds
    }

    // MARK: - UI
    enum UI {
        static let maxPreviewIssues = 3
        static let menuBarWidth: CGFloat = 260
    }

    // MARK: - App Info
    static let version = "0.2.0"
    static let bundleId = "com.opencmm.app"
}
