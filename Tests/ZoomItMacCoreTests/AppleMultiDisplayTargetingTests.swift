import XCTest
@testable import ZoomItMacCore

final class AppleMultiDisplayTargetingTests: XCTestCase {
    func testPointerTargetsDisplayWithNegativeAndStackedOrigins() throws {
        let displays = fixtures()

        XCTAssertEqual(
            try XCTUnwrap(MultiDisplayTargetingPolicy.targetDisplay(
                forAppKitPoint: CGPoint(x: -1600, y: 800),
                displays: displays
            )).id,
            2
        )
        XCTAssertEqual(
            try XCTUnwrap(MultiDisplayTargetingPolicy.targetDisplay(
                forAppKitPoint: CGPoint(x: 400, y: 1600),
                displays: displays
            )).id,
            3
        )
        XCTAssertEqual(MultiDisplayTargetingPolicy.display(id: 1, in: displays)?.id, 1)
    }

    func testGlobalPointerAndSelectionConvertToTargetLocalTopLeftPixels() throws {
        let display = try XCTUnwrap(fixtures().first { $0.id == 2 })

        XCTAssertEqual(
            MultiDisplayTargetingPolicy.localTopLeftPoint(
                fromAppKitPoint: CGPoint(x: -1800, y: 1000),
                in: display
            ),
            CGPoint(x: 120, y: 80)
        )
        XCTAssertEqual(
            MultiDisplayTargetingPolicy.pixelRect(
                forLocalTopLeftSelection: CGRect(x: 10.25, y: 20.25, width: 100.5, height: 50.5),
                in: display
            ),
            CGRect(x: 20, y: 40, width: 202, height: 102)
        )
        XCTAssertEqual(
            MultiDisplayTargetingPolicy.pixelRect(
                forLocalTopLeftSelection: CGRect(x: -20, y: -10, width: 2000, height: 1200),
                in: display
            ),
            CGRect(x: 0, y: 0, width: 3840, height: 2160)
        )
    }

    func testAppKitAndScreenCaptureCoordinatesRoundTripAcrossStackedDisplays() {
        let frames = fixtures().map(\.frame)
        let appKitPoint = CGPoint(x: 400, y: 1600)
        let screenCapturePoint = MultiDisplayTargetingPolicy.screenCapturePoint(
            fromAppKitPoint: appKitPoint,
            displayFrames: frames
        )

        XCTAssertEqual(screenCapturePoint, CGPoint(x: 400, y: 560))
        XCTAssertEqual(
            MultiDisplayTargetingPolicy.appKitPoint(
                fromScreenCapturePoint: screenCapturePoint,
                displayFrames: frames
            ),
            appKitPoint
        )
    }

    func testFeedbackOriginStaysInsideThePointerDisplayVisibleFrame() {
        let visibleFrame = CGRect(x: -1920, y: 0, width: 1920, height: 1055)
        let origin = MultiDisplayTargetingPolicy.feedbackOrigin(
            nearAppKitPointer: CGPoint(x: -5, y: 10),
            contentSize: CGSize(width: 280, height: 72),
            visibleFrame: visibleFrame,
            margin: 12
        )

        XCTAssertEqual(origin, CGPoint(x: -297, y: 22))
        XCTAssertTrue(visibleFrame.insetBy(dx: 12, dy: 12).contains(CGPoint(x: origin.x, y: origin.y)))
        XCTAssertLessThanOrEqual(origin.x + 280, visibleFrame.maxX - 12)
        XCTAssertLessThanOrEqual(origin.y + 72, visibleFrame.maxY - 12)
    }

    func testControlPresentationPlanTargetsOneDisplayAndStaysCaptureExcluded() throws {
        let display = try XCTUnwrap(fixtures().first { $0.id == 3 })
        let plan = MultiDisplayTargetingPolicy.controlPresentationPlan(for: display)

        XCTAssertEqual(plan.displayID, 3)
        XCTAssertEqual(plan.windowFrame, display.frame)
        XCTAssertTrue(plan.excludesControlLayersFromCapture)
    }

    private func fixtures() -> [DisplayDescriptor] {
        [
            DisplayDescriptor(id: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), scaleFactor: 1),
            DisplayDescriptor(id: 2, frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080), scaleFactor: 2),
            DisplayDescriptor(id: 3, frame: CGRect(x: 0, y: 1080, width: 1440, height: 1080), scaleFactor: 2)
        ]
    }
}
