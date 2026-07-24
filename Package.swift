// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "InkLayer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "InkLayer", path: "Sources/InkLayer"),
        .testTarget(name: "InkLayerTests", dependencies: ["InkLayer"])
    ]
)
