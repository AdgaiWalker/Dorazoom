import CoreGraphics
import Foundation

enum ZoomScrollInputPolicy {
    private static let mouseWheelLogarithmicStep: CGFloat = 0.06
    private static let preciseLogarithmicSensitivity: CGFloat = 0.0035
    private static let maximumPreciseDeltaPerEvent: CGFloat = 8

    static func targetZoomFactor(
        current: CGFloat,
        scrollingDeltaY: CGFloat,
        isPrecise: Bool,
        minimum: CGFloat,
        maximum: CGFloat
    ) -> CGFloat {
        guard current.isFinite,
              scrollingDeltaY.isFinite,
              minimum.isFinite,
              maximum.isFinite,
              minimum > 0,
              maximum >= minimum,
              scrollingDeltaY != 0 else {
            return min(max(current, minimum), maximum)
        }

        let logarithmicDelta: CGFloat
        if isPrecise {
            let boundedDelta = min(
                max(scrollingDeltaY, -maximumPreciseDeltaPerEvent),
                maximumPreciseDeltaPerEvent
            )
            logarithmicDelta = boundedDelta * preciseLogarithmicSensitivity
        } else {
            logarithmicDelta = scrollingDeltaY > 0
                ? mouseWheelLogarithmicStep
                : -mouseWheelLogarithmicStep
        }

        let target = current * CGFloat(exp(Double(logarithmicDelta)))
        return min(max(target, minimum), maximum)
    }
}
