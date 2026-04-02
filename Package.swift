// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Upkeep",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "Upkeep",
            path: "Sources/Upkeep"
        ),
        .testTarget(
            name: "UpkeepTests",
            dependencies: ["Upkeep"],
            path: "Tests/UpkeepTests"
        ),
    ]
)
