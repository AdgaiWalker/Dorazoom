import XCTest
@testable import ZoomItMacCore

final class Phase5RecordingTargetRequestPlanTests: XCTestCase {
    private let display = DisplayDescriptor(
        id: 42,
        frame: CGRect(x: 100, y: 200, width: 800, height: 600),
        scaleFactor: 2
    )

    func testFullScreenTargetPlansDisplayCaptureRequest() throws {
        let plan = try RecordingCaptureRequestPlanner.plan(
            target: .fullScreen(displayID: 42),
            displays: [display],
            windows: []
        )

        XCTAssertEqual(plan.filter, .display(displayID: 42, excludingWindowIDs: []))
        XCTAssertEqual(plan.sourceRect, CGRect(x: 0, y: 0, width: 800, height: 600))
        XCTAssertEqual(plan.pixelWidth, 1600)
        XCTAssertEqual(plan.pixelHeight, 1200)
        XCTAssertTrue(plan.showsCursor)
    }

    func testRegionTargetPlansDisplaySourceRectAndPixels() throws {
        let plan = try RecordingCaptureRequestPlanner.plan(
            target: .region(x: 10, y: 20, width: 300, height: 180),
            displays: [display],
            windows: []
        )

        XCTAssertEqual(plan.filter, .display(displayID: 42, excludingWindowIDs: []))
        XCTAssertEqual(plan.sourceRect, CGRect(x: 10, y: 20, width: 300, height: 180))
        XCTAssertEqual(plan.pixelWidth, 600)
        XCTAssertEqual(plan.pixelHeight, 360)
    }

    func testWindowTargetPlansWindowCaptureRequestByWindowID() throws {
        let window = RecordingWindowDescriptor(
            windowID: 9001,
            displayID: 42,
            frameInDisplay: CGRect(x: 50, y: 70, width: 320, height: 240)
        )

        let plan = try RecordingCaptureRequestPlanner.plan(
            target: .window(windowID: 9001),
            displays: [display],
            windows: [window]
        )

        XCTAssertEqual(plan.filter, .window(windowID: 9001))
        XCTAssertEqual(plan.sourceRect, nil)
        XCTAssertEqual(plan.pixelWidth, 640)
        XCTAssertEqual(plan.pixelHeight, 480)
    }

    func testMissingWindowTargetFailsWithoutFallingBackToFullScreen() {
        XCTAssertThrowsError(
            try RecordingCaptureRequestPlanner.plan(
                target: .window(windowID: 404),
                displays: [display],
                windows: []
            )
        ) { error in
            XCTAssertEqual(error as? RecordingCaptureRequestPlanError, .windowNotFound(404))
            XCTAssertTrue(error.localizedDescription.contains("404"))
        }
    }
}
