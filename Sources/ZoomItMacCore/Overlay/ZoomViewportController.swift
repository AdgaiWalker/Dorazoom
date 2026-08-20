import CoreGraphics
import Foundation

@MainActor
final class ZoomViewportController {
    private(set) var zoomFactor: CGFloat = 1
    private(set) var targetZoomFactor: CGFloat = 2
    private var zoomVelocity: CGFloat = 0
    private var lastAnimationTimestamp: TimeInterval?
    private var animationActive = false
    private(set) var capturedFrame: CapturedFrame?

    /// Critically damped response tuned to settle in roughly 0.3 seconds.
    private static let zoomAngularFrequency: CGFloat = 24

    func configure(for frame: CapturedFrame, initialZoom: CGFloat) {
        capturedFrame = frame
        targetZoomFactor = Self.clampZoom(initialZoom)
        zoomFactor = targetZoomFactor
        resetAnimationState()
    }

    func setZoomFactor(_ factor: CGFloat) {
        zoomFactor = Self.clampZoom(factor)
        targetZoomFactor = zoomFactor
        resetAnimationState()
    }

    /// Restarts the displayed zoom at 1x so it can telescope back in to the
    /// configured target, matching ZoomIt's zoom-in animation on activation.
    func beginZoomInAnimation(reduceMotion: Bool) {
        if reduceMotion {
            resetAnimationState()
            return
        }
        zoomFactor = 1
        zoomVelocity = 0
        lastAnimationTimestamp = nil
        animationActive = targetZoomFactor > 1
    }

    /// Redirects the current presentation toward a new target while preserving
    /// its current velocity. Reduced-motion environments commit immediately.
    func animateZoom(to factor: CGFloat, reduceMotion: Bool) {
        targetZoomFactor = Self.clampZoom(factor)
        if reduceMotion || abs(targetZoomFactor - zoomFactor) < 0.0001 {
            zoomFactor = targetZoomFactor
            resetAnimationState()
            return
        }
        if !animationActive {
            zoomVelocity = 0
            lastAnimationTimestamp = nil
        }
        animationActive = true
    }

    var isAnimatingZoom: Bool { animationActive }

    /// Advances the critically damped presentation using display timestamps.
    /// The closed-form update is cadence independent, so 60 Hz and 120 Hz
    /// event sequences converge to the same presentation.
    @discardableResult
    func advanceZoomAnimation(at timestamp: TimeInterval) -> Bool {
        guard animationActive else { return false }
        guard let previousTimestamp = lastAnimationTimestamp else {
            lastAnimationTimestamp = timestamp
            return true
        }

        let delta = max(0, min(timestamp - previousTimestamp, 0.25))
        lastAnimationTimestamp = timestamp
        guard delta > 0 else { return true }

        let omega = Self.zoomAngularFrequency
        let displacement = zoomFactor - targetZoomFactor
        let coefficient = zoomVelocity + omega * displacement
        let decay = CGFloat(exp(-Double(omega) * delta))
        let nextDisplacement = (displacement + coefficient * delta) * decay
        let nextVelocity = (coefficient - omega * (displacement + coefficient * delta)) * decay
        zoomFactor = Self.clampZoom(targetZoomFactor + nextDisplacement)
        zoomVelocity = nextVelocity

        if abs(zoomFactor - targetZoomFactor) < 0.001 && abs(zoomVelocity) < 0.01 {
            zoomFactor = targetZoomFactor
            resetAnimationState()
            return false
        }
        return true
    }

    private func resetAnimationState() {
        zoomVelocity = 0
        lastAnimationTimestamp = nil
        animationActive = false
    }

    private static func clampZoom(_ factor: CGFloat) -> CGFloat {
        min(max(factor, 1), 32)
    }

    // Matches ZoomIt's LIVEZOOM_MOVE_REGIONS so panning reaches the screen edges.
    private static let moveRegions: CGFloat = 8

    func sourceRect(for destinationBounds: CGRect, cursorLocation: CGPoint?) -> CGRect {
        guard let frame = capturedFrame else { return destinationBounds }

        let width = destinationBounds.width
        let height = destinationBounds.height
        let sourceWidth = width / zoomFactor
        let sourceHeight = height / zoomFactor
        let localCursor = cursorLocation.map { point in
            CGPoint(x: point.x - frame.display.frame.minX, y: frame.display.frame.maxY - point.y)
        } ?? CGPoint(x: width / 2, y: height / 2)

        // Position the zoom box so the content under the cursor stays anchored
        // under the cursor (ZoomIt's GetZoomedTopLeftCoordinates), which avoids
        // the view jumping when the mouse first moves after activation.
        var originX = min(max(localCursor.x - (localCursor.x / width) * sourceWidth, 0), max(width - sourceWidth, 0))
        originX = adjustToMoveBoundary(coordinate: originX, cursor: localCursor.x, size: sourceWidth, max: width)
        var originY = min(max(localCursor.y - (localCursor.y / height) * sourceHeight, 0), max(height - sourceHeight, 0))
        originY = adjustToMoveBoundary(coordinate: originY, cursor: localCursor.y, size: sourceHeight, max: height)

        return CGRect(x: originX, y: originY, width: sourceWidth, height: sourceHeight)
    }

    private func adjustToMoveBoundary(coordinate: CGFloat, cursor: CGFloat, size: CGFloat, max maxValue: CGFloat) -> CGFloat {
        let diff = size / ZoomViewportController.moveRegions
        if cursor - coordinate < diff {
            return Swift.max(0, cursor - diff)
        } else if (coordinate + size) - cursor < diff {
            return Swift.min(cursor + diff - size, maxValue - size)
        }
        return coordinate
    }

    func contentPoint(for viewPoint: CGPoint, destinationBounds: CGRect, cursorLocation: CGPoint?) -> CGPoint {
        let source = sourceRect(for: destinationBounds, cursorLocation: cursorLocation)
        return CGPoint(
            x: source.minX + (viewPoint.x / destinationBounds.width) * source.width,
            y: source.minY + (viewPoint.y / destinationBounds.height) * source.height
        )
    }

    func contentToDestinationTransform(source: CGRect, destinationBounds: CGRect) -> CGAffineTransform {
        let scaleX = destinationBounds.width / source.width
        let scaleY = destinationBounds.height / source.height

        return CGAffineTransform(
            a: scaleX,
            b: 0,
            c: 0,
            d: scaleY,
            tx: destinationBounds.minX - source.minX * scaleX,
            ty: destinationBounds.minY - source.minY * scaleY
        )
    }
}
