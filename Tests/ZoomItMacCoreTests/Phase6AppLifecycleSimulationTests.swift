import XCTest
@testable import ZoomItMacCore

final class Phase6AppLifecycleSimulationTests: XCTestCase {
    func testSingleInstanceUsesVirtualLockAndActivatesExistingSettingsWindowForDuplicateLaunch() {
        var lock = AppLifecycleSimulationLock()

        let first = AppLifecycleManagementSimulation.claimSingleInstance(lock: &lock)
        let duplicate = AppLifecycleManagementSimulation.claimSingleInstance(lock: &lock)
        let release = AppLifecycleManagementSimulation.releaseSingleInstance(lock: &lock)

        XCTAssertEqual(first, .init(decision: .continueLaunch, postedNotifications: [], platformBoundary: .simulatedOnly))
        XCTAssertEqual(duplicate, .init(decision: .activateExistingAndTerminate, postedNotifications: [.showSettings], platformBoundary: .simulatedOnly))
        XCTAssertEqual(release, .init(decision: .released, postedNotifications: [], platformBoundary: .simulatedOnly))
        XCTAssertFalse(lock.isClaimed)
        XCTAssertFalse(lock.touchesFilesystem)
        XCTAssertFalse(lock.postsDistributedNotifications)
    }

    func testMenuBarPlanMapsSessionStateWithoutCreatingStatusItem() {
        let readyPermissions = PermissionCenterModel.plan(for: .init(
            screenCapture: .granted,
            inputPosting: .granted,
            inputListeningFallback: .notDetermined,
            microphone: .notDetermined,
            camera: .notDetermined,
            controlVPasteEnabled: true,
            inputListeningFallbackNeeded: false,
            microphoneEnabled: false,
            cameraEnabled: false
        ))
        let idle = AppLifecycleManagementSimulation.menuBarPlan(for: .init(
            interaction: .idle,
            recording: .idle,
            annotation: .init(tool: .pen, color: .red, isHighlighter: false),
            canvas: .transparent
        ), permissions: readyPermissions, settings: .defaults)
        let drawing = AppLifecycleManagementSimulation.menuBarPlan(for: .init(
            interaction: .drawing(live: false),
            recording: .idle,
            annotation: .init(tool: .arrow, color: .blue, isHighlighter: false),
            canvas: .whiteboard
        ), permissions: readyPermissions, settings: .defaults)
        let recording = AppLifecycleManagementSimulation.menuBarPlan(for: .init(
            interaction: .drawing(live: true),
            recording: .recording(target: .fullScreen(displayID: 1), elapsedSeconds: 9, includesSystemAudio: true, includesMicrophone: false, includesWebcam: true),
            annotation: .init(tool: .pen, color: .yellow, isHighlighter: true),
            canvas: .blackboard
        ), permissions: readyPermissions, settings: .defaults)

        XCTAssertEqual(idle.feedback, .idle)
        XCTAssertEqual(idle.icon, .templateIdle)
        XCTAssertEqual(drawing.feedback, .active)
        XCTAssertEqual(drawing.icon, .templateActive)
        XCTAssertEqual(recording.feedback, .recording)
        XCTAssertEqual(recording.icon, .recordingRed)
        XCTAssertEqual(idle.menu.topLevelItems.map(\.id), [
            .status,
            .draw,
            .staticZoom,
            .liveZoom,
            .screenshot,
            .recordScreen,
            .toggleRecordingPause,
            .coreSeparator,
            .moreFeatures,
            .managementSeparator,
            .permissions,
            .settings,
            .quitSeparator,
            .quit
        ])
        XCTAssertEqual(idle.menu.item(.status)?.title, "Ready")
        XCTAssertEqual(drawing.menu.item(.status)?.title, "Drawing")
        XCTAssertEqual(recording.menu.item(.status)?.title, "Recording")
        XCTAssertEqual(idle.menu.item(.permissions)?.title, "Permissions")
        XCTAssertEqual(idle.menu.item(.moreFeatures)?.children.map(\.id), [
            .panorama,
            .demoType,
            .breakTimer,
            .advancedEditor
        ])
        XCTAssertEqual(idle.menu.item(.screenshot)?.children.map(\.id), [
            .snipRegion,
            .snipOCR,
            .snipPreviousRegion,
            .snipWindow
        ])
        XCTAssertEqual(idle.menu.item(.draw)?.shortcut, .init(key: "2", modifiers: [.control]))
        XCTAssertEqual(idle.menu.item(.recordScreen)?.shortcut, .init(key: "5", modifiers: [.control]))
        XCTAssertEqual(recording.platformBoundary, .simulatedOnly)
        XCTAssertFalse(recording.createsRealStatusItem)
    }

    func testMenuPermissionTitleOnlyMarksActionableMissingPermission() {
        let permissions = PermissionCenterModel.plan(for: .init(
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
        let plan = StatusMenuPlan.make(
            status: .idle,
            permissions: permissions,
            settings: .defaults
        )

        XCTAssertEqual(plan.item(.permissions)?.title, "Permissions · Action Required")
        XCTAssertTrue(plan.item(.permissions)?.needsAttention == true)
        XCTAssertFalse(plan.item(.moreFeatures)?.needsAttention == true)
    }

    func testMenuUsesCurrentCustomizedShortcutsInsteadOfCopiedDefaults() {
        var settings = AppSettings.defaults
        settings.drawHotKeyCode = 40
        settings.drawHotKeyModifiers = (1 << 19) | (1 << 20)

        let plan = StatusMenuPlan.make(
            status: .idle,
            permissions: .init(rows: [], platformBoundary: .simulatedOnly),
            settings: settings
        )

        XCTAssertEqual(
            plan.item(.draw)?.shortcut,
            .init(key: "k", modifiers: [.option, .command])
        )
    }

    func testLaunchAtLoginUsesSimulatedServiceAndSeparatesPreferenceFromSystemStatus() {
        var service = AppLifecycleSimulationLoginItemService(status: .notRegistered, isAppBundle: true)

        let enable = AppLifecycleManagementSimulation.setLaunchAtLoginPreference(true, service: &service)
        XCTAssertEqual(enable, .init(
            preference: true,
            projectedStatus: .enabled,
            operations: [.register],
            alert: nil,
            platformBoundary: .simulatedOnly
        ))

        let disable = AppLifecycleManagementSimulation.setLaunchAtLoginPreference(false, service: &service)
        XCTAssertEqual(disable, .init(
            preference: false,
            projectedStatus: .notRegistered,
            operations: [.unregister],
            alert: nil,
            platformBoundary: .simulatedOnly
        ))

        let pendingApproval = AppLifecycleSimulationLoginItemService(status: .requiresApproval, isAppBundle: true)
        let migration = AppLifecycleManagementSimulation.migrateLaunchAtLoginPreferenceIfNeeded(
            hasSavedPreference: false,
            currentSettings: .defaults,
            service: pendingApproval
        )
        XCTAssertTrue(migration.settings.launchAtLogin)
        XCTAssertEqual(migration.reason, .systemEnabledOrPending)

        var bareExecutable = AppLifecycleSimulationLoginItemService(status: .notRegistered, isAppBundle: false)
        let unavailable = AppLifecycleManagementSimulation.setLaunchAtLoginPreference(true, service: &bareExecutable)
        XCTAssertEqual(unavailable.alert, .requiresAppBundle)
        XCTAssertEqual(unavailable.operations, [])
        XCTAssertEqual(unavailable.projectedStatus, .notRegistered)
        XCTAssertFalse(bareExecutable.touchesServiceManagement)
    }

    func testCoverageMapMarksLifecycleManagementAcceptedByLocalSimulation() throws {
        let map = ZoomItFeatureCoverageMap.current

        for capability in [ZoomItFeatureCapability.singleInstance, .menuBarStatus, .launchAtLogin] {
            let entry = try XCTUnwrap(map.entry(for: capability))
            XCTAssertEqual(entry.status, .localSimulationAccepted)
            XCTAssertTrue(entry.simulatedTestRefs.contains("Tests/ZoomItMacCoreTests/Phase6AppLifecycleSimulationTests.swift"))
            XCTAssertTrue(entry.evidenceRefs.contains(.localSimulationAcceptance))
        }

    }
}
