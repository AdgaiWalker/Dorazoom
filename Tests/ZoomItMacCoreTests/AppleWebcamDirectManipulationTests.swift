import XCTest
@testable import ZoomItMacCore

final class AppleWebcamDirectManipulationTests: XCTestCase {
    func testDragKeepsGrabOffsetAndTracksPointerOneToOneInsideBounds() {
        let area = CGRect(x: 0, y: 0, width: 1000, height: 700)
        let result = WebcamDirectManipulationPolicy.draggedOrigin(
            mouseOnScreen: CGPoint(x: 640, y: 420),
            grabOffset: CGSize(width: 80, height: 40),
            windowSize: CGSize(width: 240, height: 135),
            area: area
        )

        XCTAssertEqual(result, CGPoint(x: 560, y: 380))
    }

    func testDragUsesProgressiveResistanceBeyondRecordingBounds() {
        let area = CGRect(x: 0, y: 0, width: 1000, height: 700)
        let result = WebcamDirectManipulationPolicy.draggedOrigin(
            mouseOnScreen: CGPoint(x: 1_160, y: 760),
            grabOffset: .zero,
            windowSize: CGSize(width: 240, height: 135),
            area: area
        )

        XCTAssertGreaterThan(result.x, 760)
        XCTAssertLessThan(result.x, 1_160)
        XCTAssertGreaterThan(result.y, 565)
        XCTAssertLessThan(result.y, 760)
    }

    func testReleaseProjectsVelocityThenSelectsNearestCornerWithoutBounce() {
        let area = CGRect(x: 0, y: 0, width: 1000, height: 700)
        let frame = CGRect(x: 420, y: 280, width: 240, height: 135)

        let plan = WebcamDirectManipulationPolicy.releasePlan(
            frame: frame,
            velocity: CGVector(dx: 1_800, dy: 900),
            area: area,
            reduceMotion: false
        )

        XCTAssertEqual(plan.targetOrigin, CGPoint(x: 752, y: 557))
        XCTAssertEqual(plan.motion, .criticallyDamped(response: 0.3))
        XCTAssertFalse(plan.allowsBounce)
    }

    func testReduceMotionCommitsWebcamSnapImmediately() {
        let plan = WebcamDirectManipulationPolicy.releasePlan(
            frame: CGRect(x: 300, y: 200, width: 240, height: 135),
            velocity: .zero,
            area: CGRect(x: 0, y: 0, width: 1000, height: 700),
            reduceMotion: true
        )

        XCTAssertEqual(plan.motion, .immediate)
    }

    func testCriticallyDampedSnapIsCadenceIndependentAndNeverOvershoots() {
        let start = CGPoint(x: 300, y: 200)
        let target = CGPoint(x: 752, y: 557)
        let sixty = replaySnap(start: start, target: target, hertz: 60)
        let oneTwenty = replaySnap(start: start, target: target, hertz: 120)

        XCTAssertEqual(sixty.last, target)
        XCTAssertEqual(oneTwenty.last, target)
        XCTAssertEqual(sixty.last?.x ?? 0, oneTwenty.last?.x ?? 0, accuracy: 0.001)
        XCTAssertTrue(sixty.allSatisfy { $0.x >= start.x && $0.x <= target.x })
        XCTAssertTrue(sixty.allSatisfy { $0.y >= start.y && $0.y <= target.y })
    }

    private func replaySnap(start: CGPoint, target: CGPoint, hertz: Double) -> [CGPoint] {
        var motion = WebcamSnapMotionState(origin: start, target: target, response: 0.3)
        var values: [CGPoint] = []
        var timestamp: TimeInterval = 0
        while timestamp <= 0.8, !motion.isComplete {
            motion.advance(to: timestamp)
            values.append(motion.origin)
            timestamp += 1.0 / hertz
        }
        if values.last != target {
            motion.finish()
            values.append(motion.origin)
        }
        return values
    }
}
