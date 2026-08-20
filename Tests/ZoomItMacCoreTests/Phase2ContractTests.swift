import XCTest
@testable import ZoomItMacCore

@MainActor
final class Phase2ContractTests: XCTestCase {
    func testSessionStateAllowsRecordingDrawingWhiteboardAndWebcamTogether() {
        let state = AppSessionState(
            interaction: .drawing(live: false),
            recording: .recording(target: .fullScreen(displayID: 1), elapsedSeconds: 12, includesSystemAudio: true, includesMicrophone: true, includesWebcam: true),
            annotation: .init(tool: .arrow, color: .red, isHighlighter: false),
            canvas: .whiteboard
        )

        XCTAssertTrue(state.isRecording)
        XCTAssertEqual(state.interaction, .drawing(live: false))
        XCTAssertEqual(state.canvas, .whiteboard)
        XCTAssertTrue(state.recording.includesWebcam)
    }

    func testPresentationSnapshotDerivesCursorAndRecordingFeedbackWithoutOwningState() {
        let state = AppSessionState(
            interaction: .regionSelection(.screenshotToClipboard),
            recording: .recording(target: .region(x: 10, y: 20, width: 300, height: 200), elapsedSeconds: 3, includesSystemAudio: false, includesMicrophone: true, includesWebcam: false),
            annotation: .init(tool: .pen, color: .blue, isHighlighter: false),
            canvas: .transparent
        )

        let snapshot = InteractionPresentationSnapshot.derive(from: state)

        XCTAssertEqual(snapshot.pointer, .crosshair(purpose: .screenshot))
        XCTAssertEqual(snapshot.recordingStatus, .visible(elapsedSeconds: 3))
        XCTAssertEqual(snapshot.palette, .hidden)
        XCTAssertEqual(snapshot.menuBar, .recording)
    }

    func testFeedbackLeasesDoNotClearOtherChannelsAndAreIdempotent() {
        let feedback = InteractionFeedback()

        let cursor = feedback.begin(channel: .cursor, content: .cursor(.crosshair(purpose: .screenshot)))
        let hud = feedback.begin(channel: .hud, content: .hud("Copied"))

        hud.end()
        hud.end()

        XCTAssertEqual(feedback.content(for: .cursor), .cursor(.crosshair(purpose: .screenshot)))
        XCTAssertNil(feedback.content(for: .hud))

        cursor.end()
        XCTAssertNil(feedback.content(for: .cursor))
    }

    func testNewLeaseOnSameChannelWinsOverLateEndFromOldLease() {
        let feedback = InteractionFeedback()

        let old = feedback.begin(channel: .hud, content: .hud("First"))
        let current = feedback.begin(channel: .hud, content: .hud("Second"))

        old.end()

        XCTAssertEqual(feedback.content(for: .hud), .hud("Second"))
        current.end()
        XCTAssertNil(feedback.content(for: .hud))
    }

    func testRecordingOutputStrategySeparatesMovieAndGifOutputs() {
        let mov = RecordingOutputStrategy.strategy(for: .mov)
        let mp4 = RecordingOutputStrategy.strategy(for: .mp4)
        let gif = RecordingOutputStrategy.strategy(for: .gif)

        XCTAssertEqual(mov, .movie(.init(container: .mov, fileExtension: "mov", videoCodec: .h264, audioCodec: .aac)))
        XCTAssertEqual(mp4, .movie(.init(container: .mp4, fileExtension: "mp4", videoCodec: .h264, audioCodec: .aac)))
        XCTAssertEqual(gif, .animatedImage(.zoomItDefault))
    }

    func testDrawingShortcutPolicyKeepsWhiteboardAndBlackboardOnWAndK() {
        let policy = DrawingShortcutPolicy.zoomItDefault

        XCTAssertEqual(policy.action(for: .init(key: "w")), .setCanvas(.whiteboard))
        XCTAssertEqual(policy.action(for: .init(key: "k")), .setCanvas(.blackboard))
        XCTAssertNil(policy.shortcut(for: .setColor(.white)))
        XCTAssertNil(policy.shortcut(for: .setColor(.black)))
    }

    func testPasteCompatibilityOnlyConvertsExactControlVWhenArmedAndAuthorized() {
        let service = PasteCompatibilityService(access: .init(canListen: true, canPost: true))

        service.screenshotCopied(changeCount: 10)

        XCTAssertEqual(service.handle(.keyDown(key: "v", modifiers: [.control])), .convertToCommandV)
        XCTAssertEqual(service.handle(.keyDown(key: "v", modifiers: [.control])), .convertToCommandV)
        XCTAssertEqual(service.handle(.keyDown(key: "v", modifiers: [.control, .shift])), .passThrough)
        XCTAssertEqual(service.handle(.keyDown(key: "v", modifiers: [.command])), .passThrough)
    }

    func testPasteCompatibilityDisarmsWhenPasteboardChangesOrPermissionIsMissing() {
        let unauthorized = PasteCompatibilityService(access: .init(canListen: true, canPost: false))
        unauthorized.screenshotCopied(changeCount: 1)
        XCTAssertEqual(unauthorized.handle(.keyDown(key: "v", modifiers: [.control])), .passThrough)

        let authorized = PasteCompatibilityService(access: .init(canListen: true, canPost: true))
        authorized.screenshotCopied(changeCount: 2)
        authorized.pasteboardDidChange(changeCount: 3)

        XCTAssertEqual(authorized.handle(.keyDown(key: "v", modifiers: [.control])), .passThrough)
    }

    func testPasteCompatibilityIgnoresSyntheticEventsToAvoidRecursion() {
        let service = PasteCompatibilityService(access: .init(canListen: true, canPost: true))

        service.screenshotCopied(changeCount: 5)

        XCTAssertEqual(service.handle(.keyDown(key: "v", modifiers: [.control], isSynthetic: true)), .passThrough)
    }

    func testPasteCoordinatorOpensPermissionCenterOnceThenArmsAfterAccessIsGranted() {
        let requester = FakeInputCompatibilityPermissionRequester(access: .init(canListen: false, canPost: false))
        let coordinator = PasteCompatibilityCoordinator(permissionRequester: requester)
        var permissionCenterRequestCount = 0
        var accessCompleteCount = 0
        coordinator.onInputPostingPermissionNeeded = {
            permissionCenterRequestCount += 1
        }
        coordinator.onAccessBecameComplete = {
            accessCompleteCount += 1
        }

        coordinator.screenshotCopied(changeCount: 20)

        XCTAssertEqual(permissionCenterRequestCount, 1)
        XCTAssertEqual(accessCompleteCount, 0)
        XCTAssertEqual(coordinator.handle(.keyDown(key: "v", modifiers: [.control])), .passThrough)

        requester.access = .init(canListen: true, canPost: true)
        coordinator.screenshotCopied(changeCount: 21)
        XCTAssertEqual(permissionCenterRequestCount, 1)
        XCTAssertEqual(accessCompleteCount, 1)
        XCTAssertEqual(coordinator.handle(.keyDown(key: "v", modifiers: [.control])), .convertToCommandV)
    }

    func testPasteCoordinatorDoesNotRepeatedlyOpenPermissionCenterWhenAccessRemainsPartial() {
        let requester = FakeInputCompatibilityPermissionRequester(access: .init(canListen: true, canPost: false))
        let coordinator = PasteCompatibilityCoordinator(permissionRequester: requester)
        var permissionCenterRequestCount = 0
        coordinator.onInputPostingPermissionNeeded = {
            permissionCenterRequestCount += 1
        }

        coordinator.screenshotCopied(changeCount: 30)
        coordinator.screenshotCopied(changeCount: 31)

        XCTAssertEqual(permissionCenterRequestCount, 1)
        XCTAssertEqual(coordinator.handle(.keyDown(key: "v", modifiers: [.control])), .passThrough)
    }
}

private final class FakeInputCompatibilityPermissionRequester: InputCompatibilityPermissionRequester {
    var access: KeyboardEventAccess

    init(access: KeyboardEventAccess) {
        self.access = access
    }

    func currentAccess() -> KeyboardEventAccess {
        access
    }
}
