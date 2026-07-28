import XCTest
@testable import ZoomItMacCore

final class Phase4OverlayHUDPresentationTests: XCTestCase {
    func testStaticZoomShowsCurrentZoomFactorHUD() {
        let hud = OverlayHUDPresentation.presentation(
            interactionMode: .staticZoom,
            zoomFactor: 2,
            container: CGRect(x: 0, y: 0, width: 320, height: 200)
        )

        XCTAssertEqual(hud?.text, "Zoom 2×")
    }

    func testStaticZoomFormatsFractionalZoomFactorWithoutNoise() {
        let hud = OverlayHUDPresentation.presentation(
            interactionMode: .staticZoom,
            zoomFactor: 1.5,
            container: CGRect(x: 0, y: 0, width: 320, height: 200)
        )

        XCTAssertEqual(hud?.text, "Zoom 1.5×")
    }

    func testZoomHUDStaysInsideContainer() {
        let hud = OverlayHUDPresentation.presentation(
            interactionMode: .staticZoom,
            zoomFactor: 32,
            container: CGRect(x: 0, y: 0, width: 80, height: 28)
        )

        XCTAssertNotNil(hud)
        XCTAssertGreaterThanOrEqual(hud!.frame.minX, 0)
        XCTAssertGreaterThanOrEqual(hud!.frame.minY, 0)
        XCTAssertLessThanOrEqual(hud!.frame.maxX, 80)
        XCTAssertLessThanOrEqual(hud!.frame.maxY, 28)
    }

    func testDrawOnlyDoesNotShowZoomHUD() {
        let hud = OverlayHUDPresentation.presentation(
            interactionMode: .drawOnly,
            zoomFactor: 1,
            container: CGRect(x: 0, y: 0, width: 320, height: 200)
        )

        XCTAssertNil(hud)
    }
}
