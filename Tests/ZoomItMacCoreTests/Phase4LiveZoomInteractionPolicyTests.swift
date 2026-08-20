import XCTest
@testable import ZoomItMacCore

final class Phase4LiveZoomInteractionPolicyTests: XCTestCase {
    func testLiveZoomPassesMouseThroughToUnderlyingAppsWhenNotDrawingOrSelecting() {
        let presentation = LiveZoomInteractionPolicy.presentation(
            interactionMode: .liveZoom,
            isDrawingMode: false,
            isSelectingRegion: false
        )

        XCTAssertEqual(presentation.mouseRouting, .passThroughToUnderlyingApp)
        XCTAssertEqual(presentation.systemCursor, .visible)
        XCTAssertEqual(presentation.mouseTracking, .global)
        XCTAssertEqual(
            presentation.globalTrackingEvents,
            [.pointerMovement, .scrollWheel]
        )
    }

    func testLiveZoomCapturesInputWhenDrawing() {
        let presentation = LiveZoomInteractionPolicy.presentation(
            interactionMode: .liveZoom,
            isDrawingMode: true,
            isSelectingRegion: false
        )

        XCTAssertEqual(presentation.mouseRouting, .captureInOverlay)
        XCTAssertEqual(presentation.systemCursor, .hidden)
        XCTAssertEqual(presentation.mouseTracking, .none)
        XCTAssertTrue(presentation.globalTrackingEvents.isEmpty)
    }

    func testLiveZoomCapturesInputWhenSelectingRegion() {
        let presentation = LiveZoomInteractionPolicy.presentation(
            interactionMode: .liveZoom,
            isDrawingMode: false,
            isSelectingRegion: true
        )

        XCTAssertEqual(presentation.mouseRouting, .captureInOverlay)
        XCTAssertEqual(presentation.systemCursor, .hidden)
        XCTAssertEqual(presentation.mouseTracking, .none)
        XCTAssertTrue(presentation.globalTrackingEvents.isEmpty)
    }

    func testStaticZoomAlwaysCapturesInput() {
        let presentation = LiveZoomInteractionPolicy.presentation(
            interactionMode: .staticZoom,
            isDrawingMode: false,
            isSelectingRegion: false
        )

        XCTAssertEqual(presentation.mouseRouting, .captureInOverlay)
        XCTAssertEqual(presentation.systemCursor, .hidden)
        XCTAssertEqual(presentation.mouseTracking, .none)
        XCTAssertTrue(presentation.globalTrackingEvents.isEmpty)
    }
}
