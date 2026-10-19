// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PortWatch",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "PortWatchCore"),
        .executableTarget(name: "PortWatch", dependencies: ["PortWatchCore"]),
        .testTarget(name: "PortWatchCoreTests", dependencies: ["PortWatchCore"]),
    ]
)
