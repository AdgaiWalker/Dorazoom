// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ZoomItMac",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "PasteTapBridge", targets: ["PasteTapBridge"]),
        .library(name: "ZoomItMacCore", targets: ["ZoomItMacCore"]),
        .executable(name: "ZoomIt", targets: ["ZoomIt"]),
        .executable(name: "ZoomItMacSelfTest", targets: ["ZoomItMacSelfTest"])
    ],
    targets: [
        .target(
            name: "PasteTapBridge",
            path: "Sources/PasteTapBridge",
            publicHeadersPath: "include"
        ),
        .target(
            name: "ZoomItMacCore",
            dependencies: ["PasteTapBridge"],
            path: "Sources/ZoomItMacCore",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "ZoomIt",
            dependencies: ["ZoomItMacCore"],
            path: "Sources/ZoomItMacApp",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ],
            linkerSettings: [
                // Embed an Info.plist into the executable so privacy usage
                // descriptions (e.g. microphone) are present even when run as a
                // bare SwiftPM binary, allowing permission prompts without
                // crashing.
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "ZoomItInfo.plist"
                ])
            ]
        ),
        .executableTarget(
            name: "ZoomItMacSelfTest",
            dependencies: ["ZoomItMacCore"],
            path: "Sources/ZoomItMacSelfTest",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "ZoomItMacCoreTests",
            dependencies: ["ZoomItMacCore"],
            path: "Tests/ZoomItMacCoreTests",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        )
    ]
)
