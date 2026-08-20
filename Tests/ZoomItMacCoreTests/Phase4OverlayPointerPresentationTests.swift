import XCTest
@testable import ZoomItMacCore

final class Phase4OverlayPointerPresentationTests: XCTestCase {
    func testStaticZoomShowsZoomPointerOnFirstFrame() {
        let visual = OverlayPointerPresentation.visual(
            interactionMode: .staticZoom,
            isDrawingMode: false,
            isSelectingRegion: false,
            activeStrokeTool: nil,
            currentTool: .pen,
            style: .default,
            canvas: .transparent,
            environment: .default
        )

        XCTAssertEqual(visual, .magnifier)
    }

    func testDrawOnlyShowsPenPointerBeforeFirstStroke() {
        let visual = OverlayPointerPresentation.visual(
            interactionMode: .drawOnly,
            isDrawingMode: true,
            isSelectingRegion: false,
            activeStrokeTool: nil,
            currentTool: .pen,
            style: .default,
            canvas: .transparent,
            environment: .default
        )

        XCTAssertEqual(visual, .penRing(color: .red, diameter: 5, highContrast: false))
    }

    func testShapeStrokeUsesToolSpecificCrosshairWhilePreviewIsActive() {
        let visual = OverlayPointerPresentation.visual(
            interactionMode: .drawOnly,
            isDrawingMode: true,
            isSelectingRegion: false,
            activeStrokeTool: .rectangle,
            currentTool: .pen,
            style: .default,
            canvas: .transparent,
            environment: .default
        )

        XCTAssertEqual(visual, .toolCrosshair(tool: .rectangle, color: .red, highContrast: false))
    }
}
