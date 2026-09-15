import XCTest
@testable import ZoomItMacCore

final class Phase7ProductIdentityTests: XCTestCase {
    func testAppInfoUsesDoraZoomPersonalEditionIdentity() {
        XCTAssertEqual(AppInfo.productName, "DoraZoom")
        XCTAssertEqual(AppInfo.copyright, "Copyright © 2026 未然界域科技工作室")
    }

    @MainActor
    func testSingleInstanceNotificationUsesDoraZoomNamespace() {
        XCTAssertEqual(SingleInstance.showPrimaryEntryNotification.rawValue, "com.duola.dorazoom.showSettings")
    }

    func testLaunchAtLoginUnavailableMessageUsesDoraZoomAppName() {
        XCTAssertFalse(LaunchAtLogin.isAvailable)

        XCTAssertThrowsError(try LaunchAtLogin.setEnabled(true)) { error in
            let description = error.localizedDescription
            XCTAssertTrue(description.contains("DoraZoom.app"), description)
            XCTAssertFalse(description.contains("ZoomIt.app"), description)
        }
    }

    func testRuntimeUserFacingSourcesDoNotUseUpstreamZoomItName() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let checkedFiles = [
            "Sources/ZoomItMacCore/App/AppController.swift",
            "Sources/ZoomItMacCore/App/AppDelegate.swift",
            "Sources/ZoomItMacCore/App/LaunchAtLogin.swift",
            "Sources/ZoomItMacCore/Capture/ImageExporter.swift",
            "Sources/ZoomItMacCore/Capture/PanoramaController.swift",
            "Sources/ZoomItMacCore/Capture/VideoClipEditorController.swift",
            "Sources/ZoomItMacCore/Overlay/BreakTimerController.swift",
            "Sources/ZoomItMacCore/Settings/SettingsWindowController.swift"
        ]

        let offenders = try checkedFiles.flatMap { relativePath in
            let text = try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
            return text
                .split(separator: "\n", omittingEmptySubsequences: false)
                .enumerated()
                .compactMap { lineNumber, line -> String? in
                    let lineText = String(line)
                    let trimmed = lineText.trimmingCharacters(in: .whitespaces)
                    let isComment = trimmed.hasPrefix("//")
                    guard lineText.contains("ZoomIt"), !isComment else { return nil }
                    return "\(relativePath):\(lineNumber + 1): \(lineText)"
                }
        }

        XCTAssertEqual(offenders, [], offenders.joined(separator: "\n"))
    }

    func testRuntimeIconResourcesUseDoraZoomFilenames() throws {
        let resources = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources/ZoomItMacCore/Resources")
        let files = try FileManager.default.contentsOfDirectory(atPath: resources.path)

        XCTAssertTrue(files.contains("DoraZoomIcon.png"), files.joined(separator: "\n"))
        XCTAssertTrue(files.contains("DoraZoomColorIcon.png"), files.joined(separator: "\n"))
        XCTAssertFalse(files.contains { $0.hasPrefix("ZoomIt") && $0.hasSuffix(".png") }, files.joined(separator: "\n"))
    }
}
