import XCTest
@testable import ZoomItMacCore

final class ApplePermissionGateTests: XCTestCase {
    // MARK: - Screen Recording cannot report denial

    /// `CGPreflightScreenCaptureAccess()` only returns a boolean, so a failed
    /// check must never surface as "the user denied this".
    func testFailedScreenCaptureCheckIsNotReportedAsDenied() {
        let state = PermissionGate.state(for: PermissionGateSnapshot(
            kind: .screenCapture,
            systemReport: .screenCapture(isGranted: false)
        ))

        XCTAssertEqual(state, .needsUserAction)
        XCTAssertNotEqual(state, .denied)
        XCTAssertFalse(state.canProceed)
    }

    func testGrantedScreenCaptureIsAvailable() {
        let state = PermissionGate.state(for: PermissionGateSnapshot(
            kind: .screenCapture,
            systemReport: .screenCapture(isGranted: true)
        ))

        XCTAssertEqual(state, .available)
        XCTAssertTrue(state.canProceed)
    }

    /// After asking, the same inconclusive report has to read as "waiting",
    /// not as a second request.
    func testScreenCaptureWaitingForSettingsAfterBeingPrompted() {
        let state = PermissionGate.state(for: PermissionGateSnapshot(
            kind: .screenCapture,
            systemReport: .screenCapture(isGranted: false),
            isWaitingForSettings: true,
            hasUserBeenPrompted: true
        ))

        XCTAssertEqual(state, .waitingForSettings)
        XCTAssertFalse(state.canRequestAuthorization)
    }

    func testScreenCaptureRequiresRestartWhenAuthorizationCannotApplyYet() {
        let state = PermissionGate.state(for: PermissionGateSnapshot(
            kind: .screenCapture,
            systemReport: .screenCapture(isGranted: false),
            restartRequired: true,
            hasUserBeenPrompted: true
        ))

        XCTAssertEqual(state, .requiresRestart)
        XCTAssertFalse(state.canProceed)
    }

    /// Once macOS reports authorization the permission is in effect, so a
    /// stale "restart pending" flag must not hold the feature back.
    func testGrantedScreenCaptureIsAvailableEvenWithPendingRestartFlag() {
        let state = PermissionGate.state(for: PermissionGateSnapshot(
            kind: .screenCapture,
            systemReport: .screenCapture(isGranted: true),
            restartRequired: true
        ))

        XCTAssertEqual(state, .available)
        XCTAssertTrue(state.canProceed)
    }

    /// While authorization is still pending, a known restart requirement is
    /// what distinguishes "come back later" from "click again".
    func testInconclusiveScreenCaptureRequiresRestartWhileAuthorizationIsPending() {
        let state = PermissionGate.state(for: PermissionGateSnapshot(
            kind: .screenCapture,
            systemReport: .screenCapture(isGranted: false),
            restartRequired: true,
            hasUserBeenPrompted: true
        ))

        XCTAssertEqual(state, .requiresRestart)
        XCTAssertNotEqual(state, .waitingForSettings)
        XCTAssertFalse(state.canProceed)
    }

    // MARK: - Media permissions do report denial

    func testDeniedMicrophoneIsReportedAsDenied() {
        let state = PermissionGate.state(for: PermissionGateSnapshot(
            kind: .microphone,
            systemReport: .media(.denied)
        ))

        XCTAssertEqual(state, .denied)
        XCTAssertFalse(state.canRequestAuthorization)
    }

    func testUndeterminedMicrophoneNeedsUserAction() {
        let state = PermissionGate.state(for: PermissionGateSnapshot(
            kind: .microphone,
            systemReport: .media(.notDetermined)
        ))

        XCTAssertEqual(state, .needsUserAction)
        XCTAssertTrue(state.canRequestAuthorization)
    }

    func testGrantedCameraIsAvailable() {
        let state = PermissionGate.state(for: PermissionGateSnapshot(
            kind: .camera,
            systemReport: .media(.granted)
        ))

        XCTAssertEqual(state, .available)
    }

    // MARK: - In-flight and unavailable

    func testOutstandingRequestIsRequesting() {
        let state = PermissionGate.state(for: PermissionGateSnapshot(
            kind: .microphone,
            systemReport: .media(.notDetermined),
            isRequestInFlight: true
        ))

        XCTAssertEqual(state, .requesting)
        XCTAssertFalse(state.canRequestAuthorization)
    }

    /// A build that does not expose a capability must not ask for its
    /// corresponding permission. The Store build keeps the scoped Control+V
    /// fallback, while DemoType remains unavailable.
    func testCapabilityUnavailableInBuildNeverRequestsPermission() {
        let state = PermissionGate.state(for: PermissionGateSnapshot(
            kind: .screenCapture,
            systemReport: .screenCapture(isGranted: false),
            isAvailableInBuild: false
        ))

        XCTAssertEqual(state, .unavailable)
        XCTAssertFalse(state.canRequestAuthorization)
        XCTAssertFalse(state.canProceed)
    }

    // MARK: - Flow arbitration

    @MainActor
    func testConcurrentRequestsAreMergedIntoOneFlow() {
        let arbiter = PermissionFlowArbiter()

        XCTAssertTrue(arbiter.beginFlow(.screenCapture))
        XCTAssertFalse(arbiter.beginFlow(.screenCapture))
        XCTAssertFalse(arbiter.beginFlow(.camera))
        XCTAssertEqual(arbiter.inFlight, .screenCapture)
    }

    /// Cancelling ends the flow, and clicking the feature again still works.
    @MainActor
    func testCancelledFlowCanBeRetried() {
        let arbiter = PermissionFlowArbiter()

        XCTAssertTrue(arbiter.beginFlow(.screenCapture))
        arbiter.endFlow()
        XCTAssertNil(arbiter.inFlight)

        XCTAssertTrue(arbiter.beginFlow(.screenCapture))
        XCTAssertEqual(arbiter.inFlight, .screenCapture)
    }

    /// Handing off to System Settings frees the flow without clearing the
    /// "already asked" history that keeps the state machine honest.
    @MainActor
    func testHandoffToSettingsKeepsPromptHistoryButFreesTheFlow() {
        let arbiter = PermissionFlowArbiter()

        XCTAssertTrue(arbiter.beginFlow(.screenCapture))
        arbiter.waitForSettings(.screenCapture)

        XCTAssertNil(arbiter.inFlight)
        XCTAssertTrue(arbiter.hasPrompted(.screenCapture))
        XCTAssertFalse(arbiter.hasPrompted(.microphone))
    }

    /// Repeated clicks after a prompt must not raise another system prompt.
    @MainActor
    func testPromptHistoryPreventsRepeatPrompt() {
        let arbiter = PermissionFlowArbiter()
        XCTAssertTrue(arbiter.beginFlow(.screenCapture))
        arbiter.endFlow()

        let snapshot = PermissionGateSnapshot(
            kind: .screenCapture,
            systemReport: .screenCapture(isGranted: false),
            hasUserBeenPrompted: arbiter.hasPrompted(.screenCapture)
        )

        XCTAssertEqual(PermissionGate.state(for: snapshot), .waitingForSettings)
        XCTAssertFalse(PermissionGate.state(for: snapshot).canRequestAuthorization)
    }

    @MainActor
    func testResetClearsHistoryForARelaunch() {
        let arbiter = PermissionFlowArbiter()
        XCTAssertTrue(arbiter.beginFlow(.screenCapture))
        arbiter.reset()

        XCTAssertNil(arbiter.inFlight)
        XCTAssertFalse(arbiter.hasPrompted(.screenCapture))
    }

    /// A relaunch that macOS triggered must not make the app look like it has
    /// never asked, otherwise the user gets the same prompt twice.
    @MainActor
    func testPrepareForRelaunchKeepsPromptHistoryButFreesTheFlow() {
        let arbiter = PermissionFlowArbiter()
        XCTAssertTrue(arbiter.beginFlow(.screenCapture))
        arbiter.markRestartPending(.screenCapture)

        arbiter.prepareForRelaunch()

        XCTAssertNil(arbiter.inFlight)
        XCTAssertTrue(arbiter.hasPrompted(.screenCapture))
        XCTAssertTrue(arbiter.isRestartPending(.screenCapture))
    }

    @MainActor
    func testRestartPendingIsClearedOnceAuthorizationIsInEffect() {
        let arbiter = PermissionFlowArbiter()
        arbiter.markRestartPending(.screenCapture)
        XCTAssertTrue(arbiter.isRestartPending(.screenCapture))

        arbiter.clearRestartPending(.screenCapture)
        XCTAssertFalse(arbiter.isRestartPending(.screenCapture))
    }

    /// Media permissions stay independent: a denied microphone must not block
    /// screen capture.
    @MainActor
    func testDeniedMicrophoneDoesNotBlockScreenCaptureFlow() {
        let arbiter = PermissionFlowArbiter()
        arbiter.endFlow()

        let screen = PermissionGate.state(for: PermissionGateSnapshot(
            kind: .screenCapture,
            systemReport: .screenCapture(isGranted: true)
        ))
        let microphone = PermissionGate.state(for: PermissionGateSnapshot(
            kind: .microphone,
            systemReport: .media(.denied)
        ))

        XCTAssertEqual(screen, .available)
        XCTAssertEqual(microphone, .denied)
    }
}
