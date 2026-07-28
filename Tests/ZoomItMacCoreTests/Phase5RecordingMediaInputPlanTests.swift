import XCTest
@testable import ZoomItMacCore

final class Phase5RecordingMediaInputPlanTests: XCTestCase {
    func testRecordingMediaInputsAreDisabledByDefault() {
        let plan = RecordingMediaInputPlanner.plan(
            settings: .defaults,
            permissions: .init(microphone: .granted, camera: .granted),
            samples: []
        )

        XCTAssertFalse(plan.includesSystemAudio)
        XCTAssertFalse(plan.includesMicrophone)
        XCTAssertFalse(plan.includesWebcam)
        XCTAssertEqual(plan.permissionRequests, [])
        XCTAssertEqual(plan.timeline, [])
        XCTAssertEqual(plan.platformBoundary, .simulatedOnly)
    }

    func testEnabledInputsRequestOnlyUndecidedFeaturePermissionsAndStayTimelineSynchronized() {
        var settings = AppSettings.defaults
        settings.recordSystemAudio = true
        settings.recordMicrophone = true
        settings.webcamEnabled = true

        let samples = [
            RecordingMediaSample(source: .video, sourceTimestampSeconds: 10.0, durationSeconds: 0.10),
            RecordingMediaSample(source: .systemAudio, sourceTimestampSeconds: 10.02, durationSeconds: 0.10),
            RecordingMediaSample(source: .microphone, sourceTimestampSeconds: 10.05, durationSeconds: 0.10),
            RecordingMediaSample(source: .webcam, sourceTimestampSeconds: 10.08, durationSeconds: 0.10)
        ]

        let plan = RecordingMediaInputPlanner.plan(
            settings: settings,
            permissions: .init(microphone: .notDetermined, camera: .granted),
            samples: samples
        )

        XCTAssertTrue(plan.includesSystemAudio)
        XCTAssertFalse(plan.includesMicrophone)
        XCTAssertTrue(plan.includesWebcam)
        XCTAssertEqual(plan.permissionRequests, [.microphone])
        XCTAssertEqual(plan.timeline, [
            .init(source: .video, presentationSeconds: 0.00, durationSeconds: 0.10),
            .init(source: .systemAudio, presentationSeconds: 0.02, durationSeconds: 0.10),
            .init(source: .webcam, presentationSeconds: 0.08, durationSeconds: 0.10)
        ])
    }

    func testGrantedMicrophoneAndCameraJoinTheSameRecordingTimeline() {
        var settings = AppSettings.defaults
        settings.recordSystemAudio = true
        settings.recordMicrophone = true
        settings.webcamEnabled = true

        let plan = RecordingMediaInputPlanner.plan(
            settings: settings,
            permissions: .init(microphone: .granted, camera: .granted),
            samples: [
                .init(source: .video, sourceTimestampSeconds: 20.0, durationSeconds: 0.10),
                .init(source: .microphone, sourceTimestampSeconds: 20.04, durationSeconds: 0.10),
                .init(source: .webcam, sourceTimestampSeconds: 20.04, durationSeconds: 0.10),
                .init(source: .systemAudio, sourceTimestampSeconds: 20.06, durationSeconds: 0.10)
            ]
        )

        XCTAssertEqual(plan.permissionRequests, [])
        XCTAssertEqual(plan.timeline, [
            .init(source: .video, presentationSeconds: 0.00, durationSeconds: 0.10),
            .init(source: .microphone, presentationSeconds: 0.04, durationSeconds: 0.10),
            .init(source: .webcam, presentationSeconds: 0.04, durationSeconds: 0.10),
            .init(source: .systemAudio, presentationSeconds: 0.06, durationSeconds: 0.10)
        ])
    }

    func testWebcamPictureInPicturePlacementAndDraggedSnapStayInsideRecordingArea() {
        let recordedArea = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let initial = RecordingWebcamPictureInPicturePlanner.initialFrame(
            area: recordedArea,
            position: .bottomRight,
            size: .medium,
            shape: .rectangle,
            cameraAspectRatio: 16.0 / 9.0
        )

        XCTAssertEqual(initial, CGRect(x: 1432, y: 8, width: 480, height: 270))

        let dragged = RecordingWebcamPictureInPicturePlanner.draggedFrame(
            mouseOnScreen: CGPoint(x: 1910, y: 1070),
            grabOffset: CGSize(width: 20, height: 20),
            currentSize: initial.size,
            area: recordedArea
        )

        XCTAssertEqual(dragged, CGRect(x: 1432, y: 802, width: 480, height: 270))
    }
}
