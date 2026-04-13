import Foundation

/// Czkawka similar file group.
struct SimilarGroup: Identifiable {
    let id = UUID()
    var files: [SimilarFile]
    let similarity: Double  // 0-100
}

struct SimilarFile: Identifiable {
    let id = UUID()
    let path: String
    let name: String
    let size: Int64
    let modifiedDate: Date
    var keepThis: Bool = false
}

/// Czkawka temporary file result.
struct TempFileResult: Identifiable {
    let id = UUID()
    let path: String
    let name: String
    let size: Int64
}
