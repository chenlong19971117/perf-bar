// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PerfBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PerfBar",
            path: "Sources/PerfBar"
        )
    ]
)
