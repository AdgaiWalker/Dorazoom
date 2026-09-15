import XCTest
@testable import ZoomItMacCore

final class Phase7PermissionRelaunchSimulationTests: XCTestCase {
    @MainActor
    func testPermissionFlowTemporarilySchedulesOneRelaunchAfterSystemQuit() {
        let coordinator = PermissionRelaunchCoordinator(relaunchWindowSeconds: 30)
        let now = Date(timeIntervalSince1970: 100)

        XCTAssertFalse(coordinator.consumeRelaunchRequest(now: now))

        coordinator.notePermissionFlowMayRequireRelaunch(now: now)

        XCTAssertTrue(coordinator.consumeRelaunchRequest(now: now.addingTimeInterval(5)))
        XCTAssertFalse(coordinator.consumeRelaunchRequest(now: now.addingTimeInterval(6)))
    }

    @MainActor
    func testExpiredPermissionFlowAndExplicitQuitDoNotRelaunch() {
        let coordinator = PermissionRelaunchCoordinator(relaunchWindowSeconds: 30)
        let now = Date(timeIntervalSince1970: 100)

        coordinator.notePermissionFlowMayRequireRelaunch(now: now)
        XCTAssertFalse(coordinator.consumeRelaunchRequest(now: now.addingTimeInterval(31)))

        coordinator.notePermissionFlowMayRequireRelaunch(now: now)
        coordinator.noteExplicitQuit()

        XCTAssertFalse(coordinator.consumeRelaunchRequest(now: now.addingTimeInterval(5)))
    }

    @MainActor
    func testScreenRecordingHotkeyPermissionPromptArmsRelaunchBeforeRequestingAccess() {
        let coordinator = PermissionRelaunchCoordinator(relaunchWindowSeconds: 30)
        let permissionService = RelaunchScreenRecordingPermissionService(isGranted: false)
        let prompter = RelaunchScreenRecordingPrompter(choice: .continueToSystemPrompt)

        XCTAssertFalse(ScreenRecordingPrompt.ensureGranted(
            permissionService,
            permissionRelaunchCoordinator: coordinator,
            prompter: prompter,
            now: Date(timeIntervalSince1970: 100)
        ))

        XCTAssertEqual(prompter.promptCount, 1)
        XCTAssertEqual(permissionService.requestCount, 1)
        XCTAssertEqual(permissionService.settingsOpenCount, 0,
                       "A pending system prompt must not open Settings a second time")
        XCTAssertTrue(coordinator.consumeRelaunchRequest(now: Date(timeIntervalSince1970: 101)))
    }

    @MainActor
    func testScreenRecordingHotkeysDoNotRepeatPermissionPromptWhileWaitingForRelaunch() {
        let arbiter = PermissionFlowArbiter()
        let permissionService = RelaunchScreenRecordingPermissionService(isGranted: false)
        let prompter = RelaunchScreenRecordingPrompter(choice: .continueToSystemPrompt)

        XCTAssertFalse(ScreenRecordingPrompt.ensureGranted(
            permissionService,
            permissionArbiter: arbiter,
            prompter: prompter
        ))
        XCTAssertFalse(ScreenRecordingPrompt.ensureGranted(
            permissionService,
            permissionArbiter: arbiter,
            prompter: prompter
        ))

        XCTAssertEqual(prompter.promptCount, 1)
        XCTAssertEqual(permissionService.requestCount, 1)

        permissionService.isGranted = true
        XCTAssertTrue(ScreenRecordingPrompt.ensureGranted(
            permissionService,
            permissionArbiter: arbiter,
            prompter: prompter
        ))
    }
}

private final class RelaunchScreenRecordingPermissionService: PermissionService {
    var isGranted: Bool
    var requestCount = 0
    var settingsOpenCount = 0

    init(isGranted: Bool) {
        self.isGranted = isGranted
    }

    func currentState() -> PermissionState {
        PermissionState(screenCapture: PermissionStatus(isGranted: isGranted))
    }

    func requestScreenCaptureAccess() -> Bool {
        requestCount += 1
        return isGranted
    }

    func openSystemSettings() { settingsOpenCount += 1 }
    func microphoneStatus() -> MicrophonePermission { .granted }
    func requestMicrophoneAccess(completion: (@MainActor @Sendable () -> Void)?) {}
    func openMicrophoneSettings() {}
    func cameraStatus() -> MicrophonePermission { .granted }
    func requestCameraAccess(completion: (@MainActor @Sendable () -> Void)?) {}
    func openCameraSettings() {}
}

@MainActor
private final class RelaunchScreenRecordingPrompter: ScreenRecordingPermissionPrompting {
    let choice: ScreenRecordingPermissionPromptChoice
    var promptCount = 0

    init(choice: ScreenRecordingPermissionPromptChoice) {
        self.choice = choice
    }

    func promptForScreenRecordingAccess() -> ScreenRecordingPermissionPromptChoice {
        promptCount += 1
        return choice
    }
}
