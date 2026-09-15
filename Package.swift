// swift-tools-version: 6.0
import Foundation
import PackageDescription

// Xcode does *not* forward the host app target's
// `SWIFT_ACTIVE_COMPILATION_CONDITIONS` to SwiftPM package targets, so the
// store build condition is still defined here for the features that remain
// store-specific (currently DemoType and its menu/settings routes).
let isStoreBuild = ProcessInfo.processInfo.environment["DORAZOOM_APP_STORE"] == "1"

let coreSwiftSettings: [SwiftSetting] = isStoreBuild
    ? [.enableUpcomingFeature("StrictConcurrency"), .define("DORAZOOM_APP_STORE")]
    : [.enableUpcomingFeature("StrictConcurrency")]

// `PasteTapBridge` is the C event-tap primitive behind the Control+V
// compatibility path. It is part of both distribution flavors.
let coreDependencies: [Target.Dependency] = ["PasteTapBridge"]

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
            dependencies: coreDependencies,
            path: "Sources/ZoomItMacCore",
            resources: [
                .process("Resources")
            ],
            swiftSettings: coreSwiftSettings
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
