import XCTest
@testable import ZoomItMacCore

@MainActor
final class AppleLiveZoomScrollTests: XCTestCase {
    func testMouseWheelUsesSmallProportionalStepsInsteadOfDoubling() {
        let target = ZoomScrollInputPolicy.targetZoomFactor(
            current: 2,
            scrollingDeltaY: 1,
            isPrecise: false,
            minimum: 1,
            maximum: 32
        )

        XCTAssertGreaterThan(target, 2.08)
        XCTAssertLessThan(target, 2.16)
    }

    func testTrackpadInputIsContinuousBoundedAndDirectionallySymmetric() {
        let zoomedIn = ZoomScrollInputPolicy.targetZoomFactor(
            current: 2,
            scrollingDeltaY: 5,
            isPrecise: true,
            minimum: 1,
            maximum: 32
        )
        let zoomedBack = ZoomScrollInputPolicy.targetZoomFactor(
            current: zoomedIn,
            scrollingDeltaY: -5,
            isPrecise: true,
            minimum: 1,
            maximum: 32
        )

        XCTAssertGreaterThan(zoomedIn, 2.01)
        XCTAssertLessThan(zoomedIn, 2.06)
        XCTAssertEqual(zoomedBack, 2, accuracy: 0.001)
    }

    func testLargePreciseDeltaIsCappedPerEvent() {
        let ordinary = ZoomScrollInputPolicy.targetZoomFactor(
            current: 2,
            scrollingDeltaY: 8,
            isPrecise: true,
            minimum: 1,
            maximum: 32
        )
        let spike = ZoomScrollInputPolicy.targetZoomFactor(
            current: 2,
            scrollingDeltaY: 80,
            isPrecise: true,
            minimum: 1,
            maximum: 32
        )

        XCTAssertEqual(spike, ordinary, accuracy: 0.001)
    }

    func testZoomOutStopsAtOneHundredPercentWithoutRequestingExit() {
        let target = ZoomScrollInputPolicy.targetZoomFactor(
            current: 1,
            scrollingDeltaY: -80,
            isPrecise: true,
            minimum: 1,
            maximum: 32
        )

        XCTAssertEqual(target, 1)
        XCTAssertFalse(ModeCoordinator.exitsOnZoomOutFloor(mode: .liveZoom))
    }
}
