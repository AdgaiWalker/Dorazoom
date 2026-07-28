import CoreGraphics
import Foundation

struct RecordingWebcamCompositionSource: Equatable, Sendable {
    var frame: CGRect
    var cornerRadius: CGFloat
}

enum RecordingFrameCompositionLayer: Equatable, Sendable {
    case capturedVideo
    case canvasBackground(CanvasBackgroundRenderFill)
    case annotations(operationCount: Int)
    case webcam(frame: CGRect, cornerRadius: CGFloat)
}

struct RecordingFrameCompositionPlan: Equatable, Sendable {
    var layers: [RecordingFrameCompositionLayer]
    var includesFeedbackHUD: Bool
    var includesRecordingStatusCapsule: Bool
    var platformBoundary: AutomationPlatformBoundary

    static func make(
        state: AppSessionState,
        annotationOperations: [AnnotationRenderOperation],
        webcam: RecordingWebcamCompositionSource?
    ) -> RecordingFrameCompositionPlan {
        var layers: [RecordingFrameCompositionLayer] = [.capturedVideo]

        if state.canvas.isCompositedIntoExports {
            layers.append(.canvasBackground(state.canvas.renderFill))
        }
        if !annotationOperations.isEmpty {
            layers.append(.annotations(operationCount: annotationOperations.count))
        }
        if state.recording.includesWebcam, let webcam {
            layers.append(.webcam(frame: webcam.frame, cornerRadius: webcam.cornerRadius))
        }

        return RecordingFrameCompositionPlan(
            layers: layers,
            includesFeedbackHUD: false,
            includesRecordingStatusCapsule: false,
            platformBoundary: .simulatedOnly
        )
    }
}
