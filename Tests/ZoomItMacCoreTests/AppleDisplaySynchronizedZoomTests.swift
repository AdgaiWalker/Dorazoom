import XCTest
@testable import ZoomItMacCore

@MainActor
final class AppleDisplaySynchronizedZoomTests: XCTestCase {
    func testTimeBasedZoomReachesSameTargetAt60And120Hertz() {
        let sixty = simulateZoom(frameInterval: 1.0 / 60.0, target: 4, duration: 0.8)
        let oneTwenty = simulateZoom(frameInterval: 1.0 / 120.0, target: 4, duration: 0.8)

        XCTAssertEqual(sixty, 4, accuracy: 0.001)
        XCTAssertEqual(oneTwenty, 4, accuracy: 0.001)
        XCTAssertEqual(sixty, oneTwenty, accuracy: 0.001)
    }

    func testRedirectedZoomContinuesFromCurrentPresentationValueAndVelocity() {
        let controller = ZoomViewportController()
        controller.setZoomFactor(1)
        controller.animateZoom(to: 4, reduceMotion: false)
        replay(controller, from: 0, through: 0.15, interval: 1.0 / 120.0)
        let beforeRedirect = controller.zoomFactor

        controller.animateZoom(to: 1.5, reduceMotion: false)
        _ = controller.advanceZoomAnimation(at: 0.15 + 1.0 / 120.0)

        XCTAssertGreaterThan(beforeRedirect, 1)
        XCTAssertLessThan(abs(controller.zoomFactor - beforeRedirect), 0.25)
        replay(controller, from: 0.16, through: 1.0, interval: 1.0 / 120.0)
        XCTAssertEqual(controller.zoomFactor, 1.5, accuracy: 0.001)
    }

    func testReduceMotionCommitsZoomImmediatelyWithoutStartingClock() {
        let controller = ZoomViewportController()
        controller.setZoomFactor(1)

        controller.animateZoom(to: 3, reduceMotion: true)

        XCTAssertEqual(controller.zoomFactor, 3)
        XCTAssertFalse(controller.isAnimatingZoom)
    }

    func testReduceMotionSkipsInitialTelescopeAnimation() {
        let controller = ZoomViewportController()
        controller.setZoomFactor(3)

        controller.beginZoomInAnimation(reduceMotion: true)

        XCTAssertEqual(controller.zoomFactor, 3)
        XCTAssertFalse(controller.isAnimatingZoom)
    }

    func testZoomDriverUsesInjectedDisplayClockAndCompletesExactlyOnce() {
        let controller = ZoomViewportController()
        controller.setZoomFactor(1)
        controller.animateZoom(to: 2, reduceMotion: false)
        let clock = VirtualDisplaySynchronizedMotionClock()
        var redrawCount = 0
        var completionCount = 0
        let driver = DisplaySynchronizedZoomDriver(
            viewportController: controller,
            clock: clock,
            redraw: { redrawCount += 1 }
        )

        driver.start { completionCount += 1 }
        clock.replay(hertz: 120, duration: 0.8)
        driver.stop()
        driver.stop()

        XCTAssertGreaterThan(redrawCount, 0)
        XCTAssertEqual(controller.zoomFactor, 2, accuracy: 0.001)
        XCTAssertEqual(completionCount, 1)
        XCTAssertEqual(clock.startCount, 1)
        XCTAssertEqual(clock.stopCount, 1)
    }

    private func simulateZoom(frameInterval: TimeInterval, target: CGFloat, duration: TimeInterval) -> CGFloat {
        let controller = ZoomViewportController()
        controller.setZoomFactor(1)
        controller.animateZoom(to: target, reduceMotion: false)
        replay(controller, from: 0, through: duration, interval: frameInterval)
        return controller.zoomFactor
    }

    private func replay(
        _ controller: ZoomViewportController,
        from start: TimeInterval,
        through end: TimeInterval,
        interval: TimeInterval
    ) {
        var timestamp = start
        while timestamp <= end {
            _ = controller.advanceZoomAnimation(at: timestamp)
            timestamp += interval
        }
    }
}

@MainActor
private final class VirtualDisplaySynchronizedMotionClock: DisplaySynchronizedMotionClock {
    private var tick: ((TimeInterval) -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start(_ tick: @escaping (TimeInterval) -> Void) {
        startCount += 1
        self.tick = tick
    }

    func stop() {
        stopCount += 1
        tick = nil
    }

    func replay(hertz: Double, duration: TimeInterval) {
        let interval = 1.0 / hertz
        var timestamp: TimeInterval = 0
        while timestamp <= duration, tick != nil {
            tick?(timestamp)
            timestamp += interval
        }
    }
}
