import XCTest
@testable import ZoomItMacCore

final class Phase4StaticZoomLifecycleTests: XCTestCase {
    func testStaticZoomLifecycleClearsOverlayResourcesOnClose() {
        var lifecycle = OverlayInteractionLifecycle.active(
            mode: .staticZoom,
            isDrawingMode: false,
            isSelectingRegion: false,
            activeStrokeTool: nil,
            zoomFactor: 2,
            container: CGRect(x: 0, y: 0, width: 500, height: 300)
        )

        XCTAssertEqual(
            lifecycle.activeResources,
            [.overlayWindow, .hiddenSystemCursor, .zoomPointer, .zoomHUD]
        )

        lifecycle.close()

        XCTAssertTrue(lifecycle.activeResources.isEmpty)
    }
}
