import XCTest
@testable import ZoomItMacCore

final class ApplePointerPresentationTests: XCTestCase {
    func testDrawingPointersEncodeToolShapeAndColorWithoutPermanentToolbar() {
        let environment = FeedbackPresentationEnvironment.default

        XCTAssertEqual(
            OverlayPointerPresentation.visual(
                interactionMode: .drawOnly,
                isDrawingMode: true,
                isSelectingRegion: false,
                activeStrokeTool: nil,
                currentTool: .pen,
                style: .init(color: .red, rootWidth: 5, alpha: 1),
                canvas: .transparent,
                environment: environment
            ),
            .penRing(color: .red, diameter: 5, highContrast: false)
        )
        XCTAssertEqual(
            OverlayPointerPresentation.visual(
                interactionMode: .drawOnly,
                isDrawingMode: true,
                isSelectingRegion: false,
                activeStrokeTool: .rectangle,
                currentTool: .rectangle,
                style: .init(color: .blue, rootWidth: 5, alpha: 1),
                canvas: .transparent,
                environment: environment
            ),
            .toolCrosshair(tool: .rectangle, color: .blue, highContrast: false)
        )
        XCTAssertEqual(
            OverlayPointerPresentation.visual(
                interactionMode: .drawOnly,
                isDrawingMode: true,
                isSelectingRegion: false,
                activeStrokeTool: nil,
                currentTool: .highlighter,
                style: .init(color: .yellow, rootWidth: 8, alpha: 0.5),
                canvas: .transparent,
                environment: environment
            ),
            .highlighterNib(color: .yellow, width: 8, highContrast: false)
        )
    }

    func testPointerAccessibilityPlanUsesImmediateHighContrastSolidFallbacks() {
        let visual = OverlayPointerPresentation.visual(
            interactionMode: .drawOnly,
            isDrawingMode: true,
            isSelectingRegion: false,
            activeStrokeTool: nil,
            currentTool: .pen,
            style: .init(color: .black, rootWidth: 4, alpha: 1),
            canvas: .blackboard,
            environment: .init(reduceMotion: true, reduceTransparency: true, increaseContrast: true)
        )

        XCTAssertEqual(visual, .penRing(color: .white, diameter: 4, highContrast: true))
    }

    func testZoomPointerIsMagnifierOnFirstFrame() {
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
}
