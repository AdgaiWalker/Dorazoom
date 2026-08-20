import XCTest
@testable import ZoomItMacCore

final class Phase6SettingsPermissionsSimulationTests: XCTestCase {
    func testSettingsSnapshotGroupsZoomItTabsAndPersistsThroughMemoryStoreRestart() {
        var settings = AppSettings.defaults
        settings.defaultZoomFactor = 3
        settings.rootPenWidth = 9
        settings.recordSystemAudio = true
        settings.webcamEnabled = true
        settings.panoramaHotKeyCode = 28
        settings.launchAtLogin = true

        let snapshot = SettingsManagementSimulation.snapshot(for: settings)

        XCTAssertEqual(snapshot.platformBoundary, .simulatedOnly)
        XCTAssertEqual(snapshot.categories.map(\.category), [
            .zoom,
            .draw,
            .text,
            .snip,
            .record,
            .webcam,
            .panorama,
            .launch
        ])
        XCTAssertEqual(snapshot.value(for: .zoom, key: "defaultZoomFactor"), "3.0")
        XCTAssertEqual(snapshot.value(for: .draw, key: "rootPenWidth"), "9.0")
        XCTAssertEqual(snapshot.value(for: .record, key: "systemAudio"), "on")
        XCTAssertEqual(snapshot.value(for: .webcam, key: "enabled"), "on")
        XCTAssertEqual(snapshot.value(for: .launch, key: "launchAtLogin"), "on")

        var store = SettingsManagementMemoryStore(initial: .defaults)
        store.save(settings)
        let restartedStore = store.simulateRestart()

        XCTAssertEqual(restartedStore.load().defaultZoomFactor, 3)
        XCTAssertEqual(restartedStore.load().rootPenWidth, 9)
        XCTAssertTrue(restartedStore.load().recordSystemAudio)
        XCTAssertTrue(restartedStore.load().webcamEnabled)
        XCTAssertTrue(restartedStore.load().launchAtLogin)
    }

    func testHotkeyPlanIncludesDerivedShortcutsAndRejectsConflictsBeforeSaving() {
        var settings = AppSettings.defaults
        let plan = SettingsManagementSimulation.hotkeyPlan(for: settings)

        XCTAssertEqual(plan.platformBoundary, .simulatedOnly)
        XCTAssertEqual(plan.bindings.first { $0.command == .staticZoom }?.key, .init(code: 18, modifiers: [.control]))
        XCTAssertEqual(plan.bindings.first { $0.command == .snipToFile }?.key, .init(code: 22, modifiers: [.control, .shift]))
        XCTAssertEqual(plan.bindings.first { $0.command == .recordRegion }?.key, .init(code: 23, modifiers: [.control, .shift]))
        XCTAssertEqual(plan.bindings.first { $0.command == .demoTypePreviousSegment }?.key, .init(code: 26, modifiers: [.control, .shift]))
        XCTAssertEqual(plan.bindings.first { $0.command == .panoramaToFile }?.key, .init(code: 28, modifiers: [.control, .shift]))
        XCTAssertEqual(plan.conflicts, [])

        settings.liveHotKeyCode = settings.drawHotKeyCode
        settings.liveHotKeyModifiers = settings.drawHotKeyModifiers
        let conflicting = SettingsManagementSimulation.hotkeyPlan(for: settings)

        XCTAssertEqual(conflicting.conflicts, [
            .init(key: .init(code: 19, modifiers: [.control]), commands: [.drawWithoutZoom, .liveZoom])
        ])
        XCTAssertFalse(conflicting.canSave)
    }

    func testPermissionCenterPlanMapsExistingSettingsScenarioWithoutRequestingTCC() {
        let page = PermissionCenterModel.plan(for: .init(
            screenCapture: .denied,
            inputPosting: .granted,
            inputListeningFallback: .denied,
            microphone: .notDetermined,
            camera: .granted,
            controlVPasteEnabled: true,
            inputListeningFallbackNeeded: true,
            microphoneEnabled: true,
            cameraEnabled: true
        ))

        XCTAssertEqual(page.platformBoundary, .simulatedOnly)
        XCTAssertEqual(page.row(for: .screenCapture)?.action, .openSystemSettings)
        XCTAssertEqual(page.row(for: .inputListeningFallback)?.action, .openSystemSettings)
        XCTAssertEqual(page.row(for: .inputPosting)?.state, .ready)
        XCTAssertEqual(page.row(for: .microphone)?.action, .requestPermission)
        XCTAssertEqual(page.row(for: .camera)?.state, .ready)
    }

    func testCoverageMapMarksSettingsHotkeysAndPermissionsAcceptedByLocalSimulation() throws {
        let map = ZoomItFeatureCoverageMap.current

        for capability in [ZoomItFeatureCapability.settingsAndHotkeyCustomization, .permissionChecks] {
            let entry = try XCTUnwrap(map.entry(for: capability))
            XCTAssertEqual(entry.status, .localSimulationAccepted)
            XCTAssertTrue(entry.simulatedTestRefs.contains("Tests/ZoomItMacCoreTests/Phase6SettingsPermissionsSimulationTests.swift"))
            XCTAssertTrue(entry.evidenceRefs.contains(.localSimulationAcceptance))
        }
    }
}
