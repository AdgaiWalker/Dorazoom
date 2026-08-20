import CoreGraphics
import Foundation

enum WebcamSnapMotion: Equatable, Sendable {
    case immediate
    case criticallyDamped(response: TimeInterval)
}

struct WebcamReleasePlan: Equatable, Sendable {
    var targetOrigin: CGPoint
    var motion: WebcamSnapMotion
    var allowsBounce: Bool
}

struct WebcamSnapMotionState: Equatable, Sendable {
    private(set) var origin: CGPoint
    let target: CGPoint
    private let angularFrequency: CGFloat
    private var velocity = CGVector.zero
    private var lastTimestamp: TimeInterval?
    private(set) var isComplete = false

    init(origin: CGPoint, target: CGPoint, response: TimeInterval) {
        self.origin = origin
        self.target = target
        angularFrequency = CGFloat(7.2 / max(response, 0.01))
        isComplete = origin == target
    }

    mutating func advance(to timestamp: TimeInterval) {
        guard !isComplete else { return }
        guard let previous = lastTimestamp else {
            lastTimestamp = timestamp
            return
        }
        let delta = max(0, min(timestamp - previous, 0.25))
        lastTimestamp = timestamp
        guard delta > 0 else { return }

        let x = advanceAxis(
            value: origin.x,
            velocity: velocity.dx,
            target: target.x,
            delta: delta
        )
        let y = advanceAxis(
            value: origin.y,
            velocity: velocity.dy,
            target: target.y,
            delta: delta
        )
        origin = CGPoint(x: x.value, y: y.value)
        velocity = CGVector(dx: x.velocity, dy: y.velocity)
        if hypot(origin.x - target.x, origin.y - target.y) < 0.1,
           hypot(velocity.dx, velocity.dy) < 1 {
            finish()
        }
    }

    mutating func finish() {
        origin = target
        velocity = .zero
        isComplete = true
        lastTimestamp = nil
    }

    private func advanceAxis(
        value: CGFloat,
        velocity: CGFloat,
        target: CGFloat,
        delta: TimeInterval
    ) -> (value: CGFloat, velocity: CGFloat) {
        let displacement = value - target
        let coefficient = velocity + angularFrequency * displacement
        let decay = CGFloat(exp(-Double(angularFrequency) * delta))
        let nextDisplacement = (displacement + coefficient * delta) * decay
        let nextVelocity = (coefficient - angularFrequency * (displacement + coefficient * delta)) * decay
        return (target + nextDisplacement, nextVelocity)
    }
}

enum WebcamDirectManipulationPolicy {
    private static let margin: CGFloat = 8
    private static let resistance: CGFloat = 0.22
    private static let projectionTime: CGFloat = 0.18

    static func draggedOrigin(
        mouseOnScreen: CGPoint,
        grabOffset: CGSize,
        windowSize: CGSize,
        area: CGRect
    ) -> CGPoint {
        let proposed = CGPoint(
            x: mouseOnScreen.x - grabOffset.width,
            y: mouseOnScreen.y - grabOffset.height
        )
        let limits = originLimits(windowSize: windowSize, area: area)
        return CGPoint(
            x: resisted(proposed.x, lower: limits.minX, upper: limits.maxX),
            y: resisted(proposed.y, lower: limits.minY, upper: limits.maxY)
        )
    }

    static func releasePlan(
        frame: CGRect,
        velocity: CGVector,
        area: CGRect,
        reduceMotion: Bool
    ) -> WebcamReleasePlan {
        let projected = CGPoint(
            x: frame.minX + velocity.dx * projectionTime,
            y: frame.minY + velocity.dy * projectionTime
        )
        let candidates = cornerOrigins(windowSize: frame.size, area: area)
        let target = candidates.min {
            distanceSquared($0, projected) < distanceSquared($1, projected)
        } ?? frame.origin
        return WebcamReleasePlan(
            targetOrigin: target,
            motion: reduceMotion ? .immediate : .criticallyDamped(response: 0.3),
            allowsBounce: false
        )
    }

    private static func originLimits(windowSize: CGSize, area: CGRect) -> CGRect {
        CGRect(
            x: area.minX + margin,
            y: area.minY + margin,
            width: max(0, area.width - windowSize.width - margin * 2),
            height: max(0, area.height - windowSize.height - margin * 2)
        )
    }

    private static func cornerOrigins(windowSize: CGSize, area: CGRect) -> [CGPoint] {
        let limits = originLimits(windowSize: windowSize, area: area)
        return [
            CGPoint(x: limits.minX, y: limits.minY),
            CGPoint(x: limits.maxX, y: limits.minY),
            CGPoint(x: limits.minX, y: limits.maxY),
            CGPoint(x: limits.maxX, y: limits.maxY)
        ]
    }

    private static func resisted(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        if value < lower {
            return lower + (value - lower) * resistance
        }
        if value > upper {
            return upper + (value - upper) * resistance
        }
        return value
    }

    private static func distanceSquared(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return dx * dx + dy * dy
    }
}
