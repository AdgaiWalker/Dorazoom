import XCTest
@testable import ZoomItMacCore

final class Phase3RegionSelectionLifecycleTests: XCTestCase {
    func testCancelClearsSelectionResourcesWithoutReturningASelection() {
        var lifecycle = RegionSelectionLifecycle.active()

        XCTAssertEqual(lifecycle.activeResources, [.selectionWindow, .crosshairCursor])

        lifecycle.beginSelection(at: CGPoint(x: 20, y: 30))
        lifecycle.updateSelection(to: CGPoint(x: 140, y: 90), scale: 2, container: CGRect(x: 0, y: 0, width: 300, height: 200))

        XCTAssertTrue(lifecycle.activeResources.contains(.sizeHUD))

        let result = lifecycle.cancel()

        XCTAssertNil(result)
        XCTAssertEqual(lifecycle.currentSelection, .zero)
        XCTAssertTrue(lifecycle.activeResources.isEmpty)
    }

    func testFinishClearsSelectionResourcesAndReturnsOnlyValidSelection() {
        var lifecycle = RegionSelectionLifecycle.active()

        lifecycle.beginSelection(at: CGPoint(x: 10, y: 10))
        lifecycle.updateSelection(to: CGPoint(x: 90, y: 60), scale: 2, container: CGRect(x: 0, y: 0, width: 300, height: 200))

        let result = lifecycle.finish()

        XCTAssertEqual(result, CGRect(x: 10, y: 10, width: 80, height: 50))
        XCTAssertTrue(lifecycle.activeResources.isEmpty)
    }
}
