import XCTest
@testable import ZoomItMacCore

final class AppleRecordingPreflightTests: XCTestCase {
    func testAudioSelectionStartsFromSettingsAndAppliesExplicitPreflightChanges() {
        var settings = AppSettings.defaults
        settings.recordSystemAudio = false
        settings.recordMicrophone = false

        var selection = RecordingPreflightAudioSelection(settings: settings)
        XCTAssertFalse(selection.systemAudio)
        XCTAssertFalse(selection.microphone)

        selection.systemAudio = true
        selection.microphone = true
        selection.apply(to: &settings)

        XCTAssertTrue(settings.recordSystemAudio)
        XCTAssertTrue(settings.recordMicrophone)
    }

    func testNoAudioSourcesEnabledIsReadyAndDoesNotRequestOptionalPermissions() {
        let plan = RecordingPreflightPlanner.plan(input(
            systemAudio: .disabled,
            microphone: .disabled,
            camera: .disabled
        ))

        XCTAssertEqual(plan.decision, .ready)
        XCTAssertEqual(plan.issues, [])
        XCTAssertEqual(plan.row(for: .systemAudio)?.status, .disabled)
        XCTAssertEqual(plan.row(for: .microphone)?.status, .disabled)
        XCTAssertEqual(plan.row(for: .camera)?.status, .disabled)
        XCTAssertFalse(plan.requestsOptionalPermission)
    }

    func testEnabledSilentMicrophoneRequiresOneExplicitConfirmation() {
        let plan = RecordingPreflightPlanner.plan(input(
            microphone: .enabled(permission: .allowed, availability: .available, level: .silent)
        ))

        XCTAssertEqual(plan.decision, .requiresConfirmation)
        XCTAssertEqual(plan.issues, [.microphoneSilent])
        XCTAssertEqual(plan.row(for: .microphone)?.status, .warning)
    }

    func testEnabledOptionalInputWithoutPermissionBlocksButDisabledInputDoesNot() {
        let microphoneBlocked = RecordingPreflightPlanner.plan(input(
            microphone: .enabled(permission: .notRequested, availability: .available, level: .audible(0.4))
        ))
        let cameraBlocked = RecordingPreflightPlanner.plan(input(
            camera: .enabled(permission: .denied, availability: .available, level: .notApplicable)
        ))

        XCTAssertEqual(microphoneBlocked.decision, .blocked)
        XCTAssertEqual(microphoneBlocked.issues, [.microphonePermissionRequired])
        XCTAssertTrue(microphoneBlocked.requestsOptionalPermission)
        XCTAssertEqual(cameraBlocked.decision, .blocked)
        XCTAssertEqual(cameraBlocked.issues, [.cameraPermissionRequired])
    }

    func testInsufficientDiskAndMissingTargetBlockBeforeMediaInitialization() {
        let diskBlocked = RecordingPreflightPlanner.plan(input(
            availableDiskBytes: 400,
            requiredDiskBytes: 1_000
        ))
        let targetBlocked = RecordingPreflightPlanner.plan(input(targetAvailable: false))

        XCTAssertEqual(diskBlocked.decision, .blocked)
        XCTAssertEqual(diskBlocked.issues, [.insufficientDisk(requiredBytes: 1_000, availableBytes: 400)])
        XCTAssertEqual(targetBlocked.decision, .blocked)
        XCTAssertEqual(targetBlocked.issues, [.targetUnavailable])
    }

    func testEnabledAvailableSourcesAndHealthyDiskAreReady() {
        let plan = RecordingPreflightPlanner.plan(input(
            systemAudio: .enabled(permission: .allowed, availability: .available, level: .audible(0.6)),
            microphone: .enabled(permission: .allowed, availability: .available, level: .audible(0.3)),
            camera: .enabled(permission: .allowed, availability: .available, level: .notApplicable)
        ))

        XCTAssertEqual(plan.decision, .ready)
        XCTAssertEqual(plan.issues, [])
        XCTAssertEqual(plan.rows.map(\.kind), [.target, .disk, .systemAudio, .microphone, .camera])
        XCTAssertTrue(plan.rows.allSatisfy { $0.status == .ready })
        XCTAssertEqual(plan.platformBoundary, .simulatedOnly)
    }

    private func input(
        targetAvailable: Bool = true,
        availableDiskBytes: Int64 = 10_000,
        requiredDiskBytes: Int64 = 1_000,
        systemAudio: RecordingPreflightSource = .disabled,
        microphone: RecordingPreflightSource = .disabled,
        camera: RecordingPreflightSource = .disabled
    ) -> RecordingPreflightInput {
        RecordingPreflightInput(
            targetName: "显示器 1",
            targetAvailable: targetAvailable,
            availableDiskBytes: availableDiskBytes,
            requiredDiskBytes: requiredDiskBytes,
            systemAudio: systemAudio,
            microphone: microphone,
            camera: camera
        )
    }
}
