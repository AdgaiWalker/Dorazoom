import XCTest
@testable import ZoomItMacCore

final class Phase4DrawingHUDPresentationTests: XCTestCase {
    func testDrawOnlyShowsCurrentToolColorAndWidthHUD() {
        let hud = DrawingHUDPresentation.presentation(
            isDrawingMode: true,
            tool: .pen,
            style: .init(color: .red, rootWidth: 5, alpha: 1),
            container: CGRect(x: 0, y: 0, width: 420, height: 240)
        )

        XCTAssertEqual(hud?.text, "Draw Pen · Red · 5px")
    }

    func testHighlighterHUDUsesHighlighterToolName() {
        let hud = DrawingHUDPresentation.presentation(
            isDrawingMode: true,
            tool: .highlighter,
            style: .init(color: .yellow, rootWidth: 12, alpha: 0.5),
            container: CGRect(x: 0, y: 0, width: 420, height: 240)
        )

        XCTAssertEqual(hud?.text, "Draw Highlighter · Yellow · 12px")
    }

    func testDrawingHUDStaysInsideContainer() {
        let hud = DrawingHUDPresentation.presentation(
            isDrawingMode: true,
            tool: .rectangle,
            style: .init(color: .orange, rootWidth: 8, alpha: 1),
            container: CGRect(x: 0, y: 0, width: 90, height: 24)
        )

        XCTAssertNotNil(hud)
        XCTAssertGreaterThanOrEqual(hud!.frame.minX, 0)
        XCTAssertGreaterThanOrEqual(hud!.frame.minY, 0)
        XCTAssertLessThanOrEqual(hud!.frame.maxX, 90)
        XCTAssertLessThanOrEqual(hud!.frame.maxY, 24)
    }

    func testDrawingHUDIsHiddenWhenNotDrawing() {
        let hud = DrawingHUDPresentation.presentation(
            isDrawingMode: false,
            tool: .pen,
            style: .default,
            container: CGRect(x: 0, y: 0, width: 420, height: 240)
        )

        XCTAssertNil(hud)
    }
}
