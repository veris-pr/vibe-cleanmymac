// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenCMM",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "OpenCMM", targets: ["OpenCMM"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "OpenCMM",
            path: "OpenCMM",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "OpenCMMTests",
            dependencies: ["OpenCMM"],
            path: "OpenCMMTests"
        )
    ]
)
