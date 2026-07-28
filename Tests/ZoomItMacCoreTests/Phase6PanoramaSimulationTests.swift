import XCTest
@testable import ZoomItMacCore

final class Phase6PanoramaSimulationTests: XCTestCase {
    func testPanoramaClipboardAndFileOutputsUseFixedFrameProgressAndSyntheticDestinations() {
        let frames = [
            PanoramaSimulationFrame(id: "top", topRow: 0, width: 320, height: 240),
            PanoramaSimulationFrame(id: "middle", topRow: 180, width: 320, height: 240),
            PanoramaSimulationFrame(id: "bottom", topRow: 360, width: 320, height: 240)
        ]

        let copied = PanoramaSimulation.run(
            frames: frames,
            output: .clipboard,
            events: [.appendFrame("top"), .appendFrame("middle"), .appendFrame("bottom"), .finish],
            clock: .fixed(filename: "DoraZoom Panorama 2026-07-27 101000.png")
        )

        XCTAssertEqual(copied.platformBoundary, .simulatedOnly)
        XCTAssertEqual(copied.progress, [.capturing(frameCount: 1), .capturing(frameCount: 2), .capturing(frameCount: 3), .stitching(percent: 33), .stitching(percent: 66), .stitching(percent: 100)])
        XCTAssertEqual(copied.outputActions, [.copyToPasteboard(imageID: "panorama[top+middle+bottom]", changeCount: 1)])
        XCTAssertEqual(copied.outcome, .completed(message: "Panorama copied to clipboard"))
        XCTAssertTrue(copied.virtualWindowsReleased)
        XCTAssertFalse(copied.touchesRealScreenCapture)
        XCTAssertFalse(copied.touchesRealPasteboard)
        XCTAssertFalse(copied.touchesRealFilesystem)

        let saved = PanoramaSimulation.run(
            frames: frames,
            output: .file(path: "/Users/dora/Pictures/panorama.png"),
            events: [.appendFrame("top"), .appendFrame("middle"), .appendFrame("bottom"), .finish],
            clock: .fixed(filename: "ignored.png")
        )

        XCTAssertEqual(saved.outputActions, [.writeFile(path: "/Users/dora/Pictures/panorama.png", imageID: "panorama[top+middle+bottom]")])
        XCTAssertEqual(saved.outcome, .completed(message: "Panorama ready to save"))
    }

    func testPanoramaCancellationAndStaleCallbacksLeaveNoVirtualWindowResidue() {
        let frames = [
            PanoramaSimulationFrame(id: "first", topRow: 0, width: 320, height: 240),
            PanoramaSimulationFrame(id: "second", topRow: 180, width: 320, height: 240)
        ]

        let cancelled = PanoramaSimulation.run(
            frames: frames,
            output: .clipboard,
            events: [.appendFrame("first"), .cancel, .appendFrame("second"), .finish],
            clock: .fixed(filename: "unused.png")
        )

        XCTAssertEqual(cancelled.progress, [.capturing(frameCount: 1), .cancelled])
        XCTAssertEqual(cancelled.outputActions, [])
        XCTAssertEqual(cancelled.outcome, .cancelled(message: "Panorama cancelled"))
        XCTAssertEqual(cancelled.ignoredCallbacks, [.appendFrameAfterCancellation("second"), .finishAfterCancellation])
        XCTAssertTrue(cancelled.virtualWindowsReleased)
    }

    func testPanoramaCoverageMapMarksFeatureAcceptedByLocalSimulation() throws {
        let map = ZoomItFeatureCoverageMap.phase6Default
        let entry = try XCTUnwrap(map.entry(for: .panoramaClipboardOrFile))

        XCTAssertEqual(entry.status, .localSimulationAccepted)
        XCTAssertTrue(entry.simulatedTestRefs.contains("Tests/ZoomItMacCoreTests/Phase6PanoramaSimulationTests.swift"))
        XCTAssertTrue(entry.phase7Refs.contains(.localSimulationAcceptance))
    }
}
