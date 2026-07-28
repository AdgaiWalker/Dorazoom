import XCTest
@testable import ZoomItMacCore

final class Phase4OverlayPointerPresentationTests: XCTestCase {
    func testStaticZoomShowsZoomPointerOnFirstFrame() {
        let visual = OverlayPointerPresentation.visual(
            interactionMode: .staticZoom,
            isDrawingMode: false,
            isSelectingRegion: false,
            activeStrokeTool: nil
        )

        XCTAssertEqual(visual, .zoomCrosshair)
    }

    func testDrawOnlyShowsPenPointerBeforeFirstStroke() {
        let visual = OverlayPointerPresentation.visual(
            interactionMode: .drawOnly,
            isDrawingMode: true,
            isSelectingRegion: false,
            activeStrokeTool: nil
        )

        XCTAssertEqual(visual, .penDot)
    }

    func testShapeStrokeHidesPenPointerWhilePreviewOwnsTheCursor() {
        let visual = OverlayPointerPresentation.visual(
            interactionMode: .drawOnly,
            isDrawingMode: true,
            isSelectingRegion: false,
            activeStrokeTool: .rectangle
        )

        XCTAssertEqual(visual, .hidden)
    }
}
