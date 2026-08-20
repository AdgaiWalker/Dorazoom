import XCTest
@testable import ZoomItMacCore

final class Phase4StaticZoomLifecycleTests: XCTestCase {
    func testStaticZoomLifecycleClearsOverlayResourcesOnClose() {
        var lifecycle = OverlayInteractionLifecycle.active(
            mode: .staticZoom,
            isDrawingMode: false,
            isSelectingRegion: false,
            activeStrokeTool: nil,
            currentTool: .pen,
            style: .default,
            canvas: .transparent,
            environment: .default
        )

        XCTAssertEqual(
            lifecycle.activeResources,
            [.overlayWindow, .hiddenSystemCursor, .zoomPointer]
        )

        lifecycle.close()

        XCTAssertTrue(lifecycle.activeResources.isEmpty)
    }
}
