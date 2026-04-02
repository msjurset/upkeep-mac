// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Upkeep",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.0"),
    ],
    targets: [
        .executableTarget(
            name: "Upkeep",
            dependencies: ["Sparkle"],
            path: "Sources/Upkeep"
        ),
        .testTarget(
            name: "UpkeepTests",
            dependencies: ["Upkeep"],
            path: "Tests/UpkeepTests"
        ),
    ]
)
