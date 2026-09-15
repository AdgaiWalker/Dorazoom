import XCTest
@testable import ZoomItMacCore

/// The App Store target compiles DemoType out entirely (`DemoTypeController` is
/// excluded under `DORAZOOM_APP_STORE`), because its script reader, synthetic
/// keyboard injection, and key-listening event tap all need authorization that
/// target does not request. These tests pin both shapes of every plan that
/// decides whether DemoType is reachable, so "the store build offers no DemoType
/// entry" stays verifiable from the one test target the package builds — the
/// test target itself is always compiled without `DORAZOOM_APP_STORE`.
final class AppleDemoTypeBuildExclusionTests: XCTestCase {
    private let permissions = PermissionCenterModel.plan(for: .init(
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

    // MARK: - Status menu

    func testStatusMenuOmitsDemoTypeWhenBuildExcludesIt() {
        let plan = StatusMenuPlan.make(
            status: .idle,
            permissions: permissions,
            settings: .defaults,
            demoTypeAvailable: false
        )

        XCTAssertNil(plan.item(.demoType), "A store build must not offer a menu item it cannot dispatch")
        XCTAssertEqual(
            plan.item(.moreFeatures)?.children.map(\.id),
            [.panorama, .breakTimer, .advancedEditor]
        )
    }

    func testStatusMenuKeepsDemoTypeWhenBuildIncludesIt() {
        let plan = StatusMenuPlan.make(
            status: .idle,
            permissions: permissions,
            settings: .defaults,
            demoTypeAvailable: true
        )

        XCTAssertEqual(
            plan.item(.moreFeatures)?.children.map(\.id),
            [.panorama, .demoType, .breakTimer, .advancedEditor]
        )
    }

    func testDefaultStatusMenuMatchesTheBuildThatCompiledIt() {
        let plan = StatusMenuPlan.make(status: .idle, permissions: permissions, settings: .defaults)

        XCTAssertEqual(
            plan.item(.demoType) != nil,
            DemoTypeBuildAvailability.isIncludedInBuild
        )
    }

    // MARK: - Settings navigation

    func testSettingsNavigationOmitsDemoTypeWhenBuildExcludesIt() throws {
        let plan = SettingsNavigationModel.plan(demoTypeAvailable: false)
        let advanced = try XCTUnwrap(plan.section(for: .advanced))

        XCTAssertEqual(advanced.destinations, [
            .breakTimer,
            .panorama,
            .webcamDetails,
            .recordingFormats,
            .complexEditor
        ])
        XCTAssertNil(plan.section(containing: .demoType))
    }

    func testSettingsNavigationKeepsDemoTypeWhenBuildIncludesIt() throws {
        let plan = SettingsNavigationModel.plan(demoTypeAvailable: true)
        let advanced = try XCTUnwrap(plan.section(for: .advanced))

        XCTAssertEqual(advanced.destinations, [
            .demoType,
            .breakTimer,
            .panorama,
            .webcamDetails,
            .recordingFormats,
            .complexEditor
        ])
        XCTAssertEqual(plan.section(containing: .demoType)?.id, .advanced)
    }

    func testDefaultSettingsNavigationMatchesTheBuildThatCompiledIt() {
        XCTAssertEqual(
            SettingsNavigationModel.defaultPlan.section(containing: .demoType) != nil,
            DemoTypeBuildAvailability.isIncludedInBuild
        )
    }

    // MARK: - Shortcut bindings

    func testShortcutPlanDropsDemoTypeBindingsWhenBuildExcludesIt() {
        let store = SettingsManagementSimulation.hotkeyPlan(for: .defaults, demoTypeAvailable: false)

        XCTAssertFalse(store.bindings.contains { $0.command == .demoType })
        XCTAssertFalse(store.bindings.contains { $0.command == .demoTypePreviousSegment })
    }

    /// `AppSettings.defaults` really does bind DemoType to Control+7, so this
    /// also proves the default shortcut stops being reserved in store builds.
    func testShortcutPlanKeepsDemoTypeBindingsWhenBuildIncludesIt() {
        let full = SettingsManagementSimulation.hotkeyPlan(for: .defaults, demoTypeAvailable: true)

        XCTAssertTrue(full.bindings.contains { $0.command == .demoType })
        XCTAssertTrue(full.bindings.contains { $0.command == .demoTypePreviousSegment })
    }

    func testDemoTypeShortcutDoesNotBlockAnotherShortcutWhenBuildExcludesIt() {
        var settings = AppSettings.defaults
        // DemoType's default Control+7 combination, claimed by Static Zoom.
        settings.hotKeyCode = settings.demoTypeHotKeyCode
        settings.hotKeyModifiers = settings.demoTypeHotKeyModifiers

        let plan = SettingsManagementSimulation.hotkeyPlan(for: settings, demoTypeAvailable: false)

        XCTAssertTrue(
            plan.canSave,
            "Store builds register no DemoType shortcut, so claiming its old combination must not be rejected"
        )
    }

    // MARK: - Permission demand sources

    func testDemoTypeSettingsNeverCreateAnInputListeningDemand() {
        var settings = AppSettings.defaults
        settings.demoTypeHotKeyCode = 26
        settings.demoTypeHotKeyModifiers = 1 << 18
        settings.demoTypeFile = "/tmp/demo-type.txt"
        settings.demoTypeSpeed = 84
        settings.demoTypeUserDriven = true
        settings.recordMouseClicks = false
        settings.recordShortcutKeys = false

        let demands = PermissionCapabilityDemandModel.demands(settings: settings, hotkeyFallbackNeeded: false)

        XCTAssertFalse(
            demands.needsInputListening,
            "DemoType observed input, but it is compiled out of store builds and must not demand Input Monitoring"
        )
    }

    /// Guards the other direction: the two capabilities that genuinely still
    /// observe input must keep demanding the permission.
    func testRecordingInputOverlayStillDemandsInputListening() {
        var settings = AppSettings.defaults
        settings.recordMouseClicks = true
        XCTAssertTrue(
            PermissionCapabilityDemandModel.demands(settings: settings, hotkeyFallbackNeeded: false).needsInputListening
        )

        settings.recordMouseClicks = false
        settings.recordShortcutKeys = true
        XCTAssertTrue(
            PermissionCapabilityDemandModel.demands(settings: settings, hotkeyFallbackNeeded: false).needsInputListening
        )

        settings.recordShortcutKeys = false
        XCTAssertTrue(
            PermissionCapabilityDemandModel.demands(settings: settings, hotkeyFallbackNeeded: true).needsInputListening
        )
    }

    func testInputListeningRowStaysQuietWhenNothingNeedsIt() {
        let plan = PermissionCenterModel.plan(for: .init(
            screenCapture: .granted,
            inputPosting: .granted,
            inputListeningFallback: .notDetermined,
            microphone: .notDetermined,
            camera: .notDetermined,
            controlVPasteEnabled: false,
            inputListeningFallbackNeeded: false,
            microphoneEnabled: false,
            cameraEnabled: false
        ))
        let row = plan.row(for: .inputListeningFallback)

        XCTAssertEqual(row?.state, .optionalNotRequested)
        // Qualified: a bare `.none` here would resolve to `Optional.none`.
        XCTAssertEqual(row?.action, PermissionCenterAction.none)
        XCTAssertEqual(row?.isOptional, true)
    }

    // MARK: - Stored preferences

    /// Requirement: excluding DemoType from a build must not clear a user's
    /// existing DemoType preferences, so a later build can restore the feature.
    func testDemoTypePreferencesSurviveAPersistenceRoundTrip() {
        let suiteName = "ZoomItMacCoreTests.DemoTypePreferences.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsSettingsStore(defaults: defaults)

        var settings = AppSettings.defaults
        settings.demoTypeHotKeyCode = 26
        settings.demoTypeHotKeyModifiers = 1 << 18
        settings.demoTypeFile = "/tmp/demo-type.txt"
        settings.demoTypeSpeed = 84
        settings.demoTypeUserDriven = true
        store.save(settings)

        let loaded = store.load()

        XCTAssertEqual(loaded.demoTypeHotKeyCode, 26)
        XCTAssertEqual(loaded.demoTypeHotKeyModifiers, 1 << 18)
        XCTAssertEqual(loaded.demoTypeFile, "/tmp/demo-type.txt")
        XCTAssertEqual(loaded.demoTypeSpeed, 84)
        XCTAssertTrue(loaded.demoTypeUserDriven)
    }

    /// Building the store-shaped plans must not write settings as a side effect.
    func testStoreShapedPlansDoNotRewriteStoredPreferences() {
        let suiteName = "ZoomItMacCoreTests.DemoTypePreferences.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsSettingsStore(defaults: defaults)

        var settings = AppSettings.defaults
        settings.demoTypeFile = "/tmp/demo-type.txt"
        store.save(settings)

        _ = StatusMenuPlan.make(status: .idle, permissions: permissions, settings: store.load(), demoTypeAvailable: false)
        _ = SettingsNavigationModel.plan(demoTypeAvailable: false)
        _ = SettingsManagementSimulation.hotkeyPlan(for: store.load(), demoTypeAvailable: false)

        XCTAssertEqual(store.load().demoTypeFile, "/tmp/demo-type.txt")
    }
}
