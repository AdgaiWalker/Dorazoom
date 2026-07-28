import XCTest
@testable import ZoomItMacCore

final class Phase5RecordingCompositionIsolationTests: XCTestCase {
    func testRecordingDrawingWhiteboardAndWebcamProduceCompositedFramePlan() {
        let state = AppSessionState(
            interaction: .drawing(live: false),
            recording: .recording(
                target: .region(x: 10, y: 20, width: 640, height: 360),
                elapsedSeconds: 7,
                includesSystemAudio: true,
                includesMicrophone: true,
                includesWebcam: true
            ),
            annotation: .init(tool: .arrow, color: .red, isHighlighter: false),
            canvas: .whiteboard
        )

        let plan = RecordingFrameCompositionPlan.make(
            state: state,
            annotationOperations: [
                .init(
                    kind: .arrow,
                    points: [CGPoint(x: 12, y: 14), CGPoint(x: 120, y: 140)],
                    style: .init(color: .red, rootWidth: 5, alpha: 1),
                    text: "",
                    fontSize: 0,
                    fontName: "",
                    rightAligned: false
                )
            ],
            webcam: .init(frame: CGRect(x: 500, y: 250, width: 120, height: 90), cornerRadius: 12)
        )

        XCTAssertEqual(plan.layers, [
            .capturedVideo,
            .canvasBackground(.white),
            .annotations(operationCount: 1),
            .webcam(frame: CGRect(x: 500, y: 250, width: 120, height: 90), cornerRadius: 12)
        ])
        XCTAssertFalse(plan.includesFeedbackHUD)
        XCTAssertFalse(plan.includesRecordingStatusCapsule)
        XCTAssertEqual(plan.platformBoundary, .simulatedOnly)
    }

    func testRecordingBlackboardWithoutWebcamStillComposesAnnotationsAndCanvas() {
        let state = AppSessionState(
            interaction: .drawing(live: false),
            recording: .recording(
                target: .fullScreen(displayID: 1),
                elapsedSeconds: 3,
                includesSystemAudio: false,
                includesMicrophone: false,
                includesWebcam: false
            ),
            annotation: .init(tool: .pen, color: .green, isHighlighter: false),
            canvas: .blackboard
        )

        let plan = RecordingFrameCompositionPlan.make(
            state: state,
            annotationOperations: [
                .init(
                    kind: .freehand,
                    points: [CGPoint(x: 1, y: 2), CGPoint(x: 3, y: 4)],
                    style: .init(color: .green, rootWidth: 5, alpha: 1),
                    text: "",
                    fontSize: 0,
                    fontName: "",
                    rightAligned: false
                )
            ],
            webcam: nil
        )

        XCTAssertEqual(plan.layers, [
            .capturedVideo,
            .canvasBackground(.black),
            .annotations(operationCount: 1)
        ])
    }

    func testEndingPointerLeaseDoesNotClearRecordingStateOrRecordingFeedback() {
        let feedback = InteractionFeedback()
        let cursor = feedback.begin(channel: .cursor, content: .cursor(.pen))
        let recordingStatus = feedback.begin(
            channel: .recordingStatus,
            content: .recordingStatus(.visible(elapsedSeconds: 12))
        )
        let state = AppSessionState(
            interaction: .drawing(live: false),
            recording: .recording(
                target: .fullScreen(displayID: 1),
                elapsedSeconds: 12,
                includesSystemAudio: false,
                includesMicrophone: false,
                includesWebcam: false
            ),
            annotation: .init(tool: .pen, color: .blue, isHighlighter: false),
            canvas: .transparent
        )

        cursor.end()

        XCTAssertNil(feedback.content(for: .cursor))
        XCTAssertEqual(feedback.content(for: .recordingStatus), .recordingStatus(.visible(elapsedSeconds: 12)))
        XCTAssertTrue(state.isRecording)

        recordingStatus.end()
        XCTAssertTrue(state.isRecording)
    }
}
