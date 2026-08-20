import AppKit
import QuartzCore

@MainActor
protocol DisplaySynchronizedMotionClock: AnyObject {
    func start(_ tick: @escaping (_ timestamp: TimeInterval) -> Void)
    func stop()
}

@MainActor
final class DisplaySynchronizedZoomDriver {
    private let viewportController: ZoomViewportController
    private let clock: DisplaySynchronizedMotionClock
    private let redraw: () -> Void
    private var completion: (() -> Void)?
    private var isRunning = false

    init(
        viewportController: ZoomViewportController,
        clock: DisplaySynchronizedMotionClock,
        redraw: @escaping () -> Void
    ) {
        self.viewportController = viewportController
        self.clock = clock
        self.redraw = redraw
    }

    func start(completion: (() -> Void)? = nil) {
        if isRunning {
            clock.stop()
        }
        guard viewportController.isAnimatingZoom else {
            completion?()
            return
        }
        self.completion = completion
        isRunning = true
        clock.start { [weak self] timestamp in
            self?.tick(timestamp)
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        clock.stop()
        completion = nil
    }

    private func tick(_ timestamp: TimeInterval) {
        guard isRunning else { return }
        let continuing = viewportController.advanceZoomAnimation(at: timestamp)
        redraw()
        guard !continuing else { return }

        isRunning = false
        clock.stop()
        let completion = self.completion
        self.completion = nil
        completion?()
    }
}

@MainActor
final class ViewDisplaySynchronizedMotionClock: NSObject, DisplaySynchronizedMotionClock {
    private weak var view: NSView?
    private var displayLink: CADisplayLink?
    private var tick: ((TimeInterval) -> Void)?

    init(view: NSView) {
        self.view = view
    }

    func start(_ tick: @escaping (TimeInterval) -> Void) {
        stop()
        guard let view else { return }
        self.tick = tick
        let link = view.displayLink(target: self, selector: #selector(displayLinkDidFire(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        tick = nil
    }

    @objc private func displayLinkDidFire(_ link: CADisplayLink) {
        tick?(link.targetTimestamp)
    }
}
