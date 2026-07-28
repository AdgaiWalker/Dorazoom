import XCTest
@testable import ZoomItMacCore

final class Phase4LiveZoomCommandPolicyTests: XCTestCase {
    func testDrawHotkeysToggleDrawingInsideLiveZoomWithoutLeavingLiveZoom() {
        XCTAssertEqual(
            LiveZoomCommandPolicy.effect(mode: .liveZoom, command: .activateDrawWithoutZoom),
            .toggleDrawingWithinLiveZoom
        )
        XCTAssertEqual(
            LiveZoomCommandPolicy.effect(mode: .liveZoom, command: .activateStaticZoom),
            .toggleDrawingWithinLiveZoom
        )
    }

    func testDrawHotkeyOutsideLiveZoomKeepsNormalCommandHandling() {
        XCTAssertEqual(
            LiveZoomCommandPolicy.effect(mode: .idle, command: .activateDrawWithoutZoom),
            .normalCommandHandling
        )
    }

    func testNonDrawCommandInsideLiveZoomKeepsNormalCommandHandling() {
        XCTAssertEqual(
            LiveZoomCommandPolicy.effect(mode: .liveZoom, command: .zoomIn),
            .normalCommandHandling
        )
    }
}
