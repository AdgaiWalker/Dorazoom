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
        let idle = AppLifecycleManagementSimulation.menuBarPlan(for: .init(
            interaction: .idle,
            recording: .idle,
            annotation: .init(tool: .pen, color: .red, isHighlighter: false),
            canvas: .transparent
        ))
        let drawing = AppLifecycleManagementSimulation.menuBarPlan(for: .init(
            interaction: .drawing(live: false),
            recording: .idle,
            annotation: .init(tool: .arrow, color: .blue, isHighlighter: false),
            canvas: .whiteboard
        ))
        let recording = AppLifecycleManagementSimulation.menuBarPlan(for: .init(
            interaction: .drawing(live: true),
            recording: .recording(target: .fullScreen(displayID: 1), elapsedSeconds: 9, includesSystemAudio: true, includesMicrophone: false, includesWebcam: true),
            annotation: .init(tool: .pen, color: .yellow, isHighlighter: true),
            canvas: .blackboard
        ))

        XCTAssertEqual(idle.feedback, .idle)
        XCTAssertEqual(idle.icon, .templateIdle)
        XCTAssertEqual(drawing.feedback, .active)
        XCTAssertEqual(drawing.icon, .templateActive)
        XCTAssertEqual(recording.feedback, .recording)
        XCTAssertEqual(recording.icon, .recordingRed)
        XCTAssertEqual(idle.menuTitles, [
            "Settings…",
            "Draw",
            "Static Zoom",
            "Live Zoom",
            "Record Screen",
            "Panorama Capture",
            "Break Timer",
            "Check Permissions",
            "Quit"
        ])
        XCTAssertEqual(recording.platformBoundary, .simulatedOnly)
        XCTAssertFalse(recording.createsRealStatusItem)
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
        let map = ZoomItFeatureCoverageMap.phase6Default

        for capability in [ZoomItFeatureCapability.singleInstance, .menuBarStatus, .launchAtLogin] {
            let entry = try XCTUnwrap(map.entry(for: capability))
            XCTAssertEqual(entry.status, .localSimulationAccepted)
            XCTAssertTrue(entry.simulatedTestRefs.contains("Tests/ZoomItMacCoreTests/Phase6AppLifecycleSimulationTests.swift"))
            XCTAssertTrue(entry.phase7Refs.contains(.localSimulationAcceptance))
        }

        XCTAssertEqual(map.gaps, [])
    }
}
