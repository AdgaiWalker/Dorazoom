import XCTest
@testable import ZoomItMacCore

final class ApplePermissionCenterTests: XCTestCase {
    func testPermissionCenterMapsRequiredAndOptionalRowsWithoutTreatingUnusedMediaAsErrors() {
        let plan = PermissionCenterModel.plan(for: .init(
            screenCapture: .denied,
            inputPosting: .granted,
            inputListeningFallback: .notDetermined,
            microphone: .notDetermined,
            camera: .granted,
            controlVPasteEnabled: true,
            inputListeningFallbackNeeded: false,
            microphoneEnabled: false,
            cameraEnabled: false
        ))

        XCTAssertEqual(plan.rows.map(\.kind), [
            .screenCapture,
            .inputPosting,
            .inputListeningFallback,
            .microphone,
            .camera
        ])
        XCTAssertEqual(plan.row(for: .screenCapture), .init(
            kind: .screenCapture,
            purpose: "用于缩放、圈画、截图和录制屏幕内容",
            state: .needsSettings,
            action: .openSystemSettings,
            isOptional: false
        ))
        XCTAssertEqual(plan.row(for: .inputPosting)?.state, .ready)
        XCTAssertEqual(plan.row(for: .inputPosting)?.action, PermissionCenterAction.none)
        XCTAssertEqual(plan.row(for: .inputListeningFallback)?.state, .optionalNotRequested)
        XCTAssertEqual(plan.row(for: .inputListeningFallback)?.action, PermissionCenterAction.none)
        XCTAssertEqual(plan.row(for: .microphone)?.state, .optionalNotRequested)
        XCTAssertEqual(plan.row(for: .microphone)?.action, PermissionCenterAction.none)
        XCTAssertEqual(plan.row(for: .camera)?.state, .ready)
        XCTAssertTrue(plan.row(for: .microphone)?.isOptional == true)
        XCTAssertTrue(plan.row(for: .camera)?.isOptional == true)
        XCTAssertEqual(plan.platformBoundary, .simulatedOnly)
    }

    func testReturningFromSystemSettingsOnlyRefreshesVisibleRows() {
        let opened = PermissionCenterModel.lifecyclePlan(for: .userOpenedPermissionCenter)
        XCTAssertEqual(opened, .init(
            presentsWindow: true,
            refreshesRows: true,
            requestsSystemPermission: false
        ))

        let returned = PermissionCenterModel.lifecyclePlan(for: .applicationBecameActive)
        XCTAssertEqual(returned, .init(
            presentsWindow: false,
            refreshesRows: true,
            requestsSystemPermission: false
        ))
    }

    func testEnabledOptionalPermissionsAndRelaunchStateExposeOneExplicitActionEach() {
        let plan = PermissionCenterModel.plan(for: .init(
            screenCapture: .requiresRelaunch,
            inputPosting: .notDetermined,
            inputListeningFallback: .denied,
            microphone: .notDetermined,
            camera: .denied,
            controlVPasteEnabled: true,
            inputListeningFallbackNeeded: true,
            microphoneEnabled: true,
            cameraEnabled: true
        ))

        XCTAssertEqual(plan.row(for: .screenCapture)?.state, .restartRequired)
        XCTAssertEqual(plan.row(for: .screenCapture)?.action, .restartApp)
        XCTAssertEqual(plan.row(for: .inputPosting)?.state, .notRequested)
        XCTAssertEqual(plan.row(for: .inputPosting)?.action, .requestPermission)
        XCTAssertEqual(plan.row(for: .inputListeningFallback)?.state, .needsSettings)
        XCTAssertEqual(plan.row(for: .inputListeningFallback)?.action, .openSystemSettings)
        XCTAssertEqual(plan.row(for: .microphone)?.state, .notRequested)
        XCTAssertEqual(plan.row(for: .microphone)?.action, .requestPermission)
        XCTAssertEqual(plan.row(for: .camera)?.state, .needsSettings)
        XCTAssertEqual(plan.row(for: .camera)?.action, .openSystemSettings)
    }

    func testDisabledControlVPasteDoesNotDemandInputPostingPermission() {
        let plan = PermissionCenterModel.plan(for: .init(
            screenCapture: .granted,
            inputPosting: .denied,
            inputListeningFallback: .denied,
            microphone: .denied,
            camera: .denied,
            controlVPasteEnabled: false,
            inputListeningFallbackNeeded: false,
            microphoneEnabled: false,
            cameraEnabled: false
        ))

        XCTAssertEqual(plan.row(for: .inputPosting)?.state, .optionalNotRequested)
        XCTAssertEqual(plan.row(for: .inputPosting)?.action, PermissionCenterAction.none)
        XCTAssertTrue(plan.row(for: .inputPosting)?.isOptional == true)
    }

    @MainActor
    func testPermissionCoordinatorPresentsOnlyOnUserActionAndRefreshesWhenAppBecomesActive() {
        var input = PermissionCenterInput(
            screenCapture: .denied,
            inputPosting: .granted,
            inputListeningFallback: .notDetermined,
            microphone: .notDetermined,
            camera: .notDetermined,
            controlVPasteEnabled: true,
            inputListeningFallbackNeeded: false,
            microphoneEnabled: false,
            cameraEnabled: false
        )
        let presenter = PermissionCenterPresenterSpy()
        var performedActions: [(PermissionCenterKind, PermissionCenterAction)] = []
        let coordinator = PermissionCenterCoordinator(
            planProvider: { PermissionCenterModel.plan(for: input) },
            presenter: presenter,
            actionHandler: { performedActions.append(($0, $1)) }
        )

        coordinator.show()
        XCTAssertEqual(presenter.presentedPlans.count, 1)
        XCTAssertEqual(presenter.refreshedPlans.count, 0)

        input.screenCapture = .requiresRelaunch
        coordinator.applicationBecameActive()
        XCTAssertEqual(presenter.presentedPlans.count, 1)
        XCTAssertEqual(presenter.refreshedPlans.count, 1)
        XCTAssertEqual(presenter.refreshedPlans.last?.row(for: .screenCapture)?.state, .restartRequired)

        coordinator.performAction(for: .screenCapture)
        XCTAssertEqual(performedActions.map(\.0), [.screenCapture])
        XCTAssertEqual(performedActions.map(\.1), [.restartApp])

        coordinator.close()
        XCTAssertFalse(presenter.isVisible)
    }

    @MainActor
    func testPermissionWindowUsesNormalNonModalWindowAndRefreshesInPlace() {
        var selectedKinds: [PermissionCenterKind] = []
        let presenter = PermissionCenterWindowController(onSelectRowAction: { selectedKinds.append($0) })
        let initial = PermissionCenterModel.plan(for: .init(
            screenCapture: .denied,
            inputPosting: .granted,
            inputListeningFallback: .notDetermined,
            microphone: .notDetermined,
            camera: .notDetermined,
            controlVPasteEnabled: true,
            inputListeningFallbackNeeded: false,
            microphoneEnabled: false,
            cameraEnabled: false
        ))

        presenter.present(initial)
        defer { presenter.close() }

        XCTAssertTrue(presenter.isVisible)
        XCTAssertEqual(presenter.window?.title, "DoraZoom 权限")
        XCTAssertEqual(presenter.window?.level, .normal)
        XCTAssertEqual(presenter.renderedPlan, initial)
        XCTAssertEqual(presenter.renderedRowKinds, initial.rows.map(\.kind))

        var refreshed = initial
        refreshed.rows[0].state = .restartRequired
        refreshed.rows[0].action = .restartApp
        presenter.refresh(refreshed)

        XCTAssertTrue(presenter.isVisible)
        XCTAssertEqual(presenter.renderedPlan, refreshed)
        XCTAssertEqual(selectedKinds, [])
    }

    @MainActor
    func testSystemAdapterBuildsPlanFromPlatformStateWithoutTouchingRealPermissions() {
        let platform = PermissionCenterPlatformAccessFake()
        platform.screenCaptureGranted = false
        platform.inputAccess = .init(canListen: false, canPost: true)
        platform.microphone = .notDetermined
        platform.camera = .denied
        let restarter = PermissionCenterRestarterSpy()
        let adapter = PermissionCenterSystemAdapter(
            platformAccess: platform,
            restarter: restarter,
            settingsProvider: {
                var settings = AppSettings.defaults
                settings.recordMicrophone = false
                settings.webcamEnabled = true
                return settings
            },
            inputListeningFallbackNeeded: { false }
        )

        let plan = adapter.plan()

        XCTAssertEqual(plan.row(for: .screenCapture)?.state, .notRequested)
        XCTAssertEqual(plan.row(for: .inputPosting)?.state, .ready)
        XCTAssertEqual(plan.row(for: .inputListeningFallback)?.state, .optionalNotRequested)
        XCTAssertEqual(plan.row(for: .microphone)?.state, .optionalNotRequested)
        XCTAssertEqual(plan.row(for: .camera)?.state, .needsSettings)
        XCTAssertEqual(platform.actionLog, [])
        XCTAssertEqual(restarter.restartCount, 0)
    }

    @MainActor
    func testSystemAdapterRoutesOneExplicitActionAndRefreshesAfterCompletion() {
        let platform = PermissionCenterPlatformAccessFake()
        let restarter = PermissionCenterRestarterSpy()
        var refreshCount = 0
        let adapter = PermissionCenterSystemAdapter(
            platformAccess: platform,
            restarter: restarter,
            settingsProvider: { AppSettings.defaults },
            inputListeningFallbackNeeded: { true },
            onStateChanged: { refreshCount += 1 }
        )

        adapter.perform(.screenCapture, action: .requestPermission)
        XCTAssertEqual(platform.actionLog, [.requestScreenCapture])
        XCTAssertEqual(adapter.plan().row(for: .screenCapture)?.state, .restartRequired)
        XCTAssertEqual(refreshCount, 1)

        adapter.perform(.inputListeningFallback, action: .openSystemSettings)
        XCTAssertEqual(platform.actionLog, [.requestScreenCapture, .openSettings(.inputListeningFallback)])
        XCTAssertEqual(refreshCount, 1)

        adapter.perform(.microphone, action: .requestPermission)
        XCTAssertEqual(platform.actionLog, [
            .requestScreenCapture,
            .openSettings(.inputListeningFallback),
            .requestMicrophone
        ])
        XCTAssertEqual(refreshCount, 2)

        adapter.perform(.screenCapture, action: .restartApp)
        XCTAssertEqual(restarter.restartCount, 1)
        XCTAssertEqual(platform.actionLog.count, 3)
    }

    @MainActor
    func testRestartIntentOnlyTerminatesAfterExplicitActionAndConsumesOnce() {
        var terminationCount = 0
        let intent = PermissionCenterRestartIntent(terminate: { terminationCount += 1 })

        XCTAssertFalse(intent.consume())
        XCTAssertEqual(terminationCount, 0)

        intent.restart()

        XCTAssertEqual(terminationCount, 1)
        XCTAssertTrue(intent.consume())
        XCTAssertFalse(intent.consume())
    }
}

@MainActor
private final class PermissionCenterPresenterSpy: PermissionCenterPresenting {
    var isVisible = false
    var presentedPlans: [PermissionCenterPlan] = []
    var refreshedPlans: [PermissionCenterPlan] = []

    func present(_ plan: PermissionCenterPlan) {
        isVisible = true
        presentedPlans.append(plan)
    }

    func refresh(_ plan: PermissionCenterPlan) {
        refreshedPlans.append(plan)
    }

    func close() {
        isVisible = false
    }
}

@MainActor
private final class PermissionCenterPlatformAccessFake: PermissionCenterPlatformAccess {
    var screenCaptureGranted = false
    var inputAccess = KeyboardEventAccess(canListen: false, canPost: false)
    var microphone = MicrophonePermission.notDetermined
    var camera = MicrophonePermission.notDetermined
    var screenRequestResult = true
    var inputPostRequestResult = true
    var inputListenRequestResult = true
    private(set) var actionLog: [PermissionCenterPlatformAction] = []

    func isScreenCaptureGranted() -> Bool { screenCaptureGranted }
    func currentInputAccess() -> KeyboardEventAccess { inputAccess }
    func microphoneStatus() -> MicrophonePermission { microphone }
    func cameraStatus() -> MicrophonePermission { camera }

    func requestScreenCapture() -> Bool {
        actionLog.append(.requestScreenCapture)
        return screenRequestResult
    }

    func requestInputPosting() -> Bool {
        actionLog.append(.requestInputPosting)
        return inputPostRequestResult
    }

    func requestInputListening() -> Bool {
        actionLog.append(.requestInputListening)
        return inputListenRequestResult
    }

    func requestMicrophone(completion: @escaping @MainActor @Sendable () -> Void) {
        actionLog.append(.requestMicrophone)
        completion()
    }

    func requestCamera(completion: @escaping @MainActor @Sendable () -> Void) {
        actionLog.append(.requestCamera)
        completion()
    }

    func openSystemSettings(for kind: PermissionCenterKind) {
        actionLog.append(.openSettings(kind))
    }
}

@MainActor
private final class PermissionCenterRestarterSpy: PermissionCenterRestarting {
    private(set) var restartCount = 0

    func restart() {
        restartCount += 1
    }
}
