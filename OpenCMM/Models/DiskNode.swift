import Foundation

/// Tree node for disk usage visualization (gdu integration).
struct DiskNode: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    let isDirectory: Bool
    var children: [DiskNode]
    var isExpanded: Bool = false

    var formattedSize: String { Formatters.fileSize(size) }

    func percentage(of parentSize: Int64) -> Double {
        guard parentSize > 0 else { return 0 }
        return Double(size) / Double(parentSize) * 100
    }
}
