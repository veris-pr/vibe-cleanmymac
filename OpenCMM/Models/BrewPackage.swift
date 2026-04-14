import Foundation

/// A Homebrew formula installed on the system.
struct BrewPackage: Identifiable {
    let id: String
    let name: String
    let version: String
    let description: String
    let size: Int64
    let dependencies: [String]
    let isLeaf: Bool
    let installedOnRequest: Bool
}
