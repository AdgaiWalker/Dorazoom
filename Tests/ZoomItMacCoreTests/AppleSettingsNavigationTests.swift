import XCTest
@testable import ZoomItMacCore

final class AppleSettingsNavigationTests: XCTestCase {
    func testSettingsNavigationUsesSixMacGroupsInFixedOrder() {
        let plan = SettingsNavigationModel.defaultPlan

        XCTAssertEqual(plan.sections.map(\.id), [
            .general,
            .shortcuts,
            .captureAndDraw,
            .recording,
            .permissions,
            .advanced
        ])
        XCTAssertEqual(plan.sections.map(\.title), [
            "General",
            "Shortcuts",
            "Capture & Draw",
            "Recording",
            "Permissions",
            "Advanced"
        ])
        XCTAssertEqual(plan.platformBoundary, .simulatedOnly)
    }

    func testAdvancedGroupOwnsCompatibilityFeaturesWithoutHidingCoreActions() throws {
        let plan = SettingsNavigationModel.defaultPlan
        let advanced = try XCTUnwrap(plan.section(for: .advanced))

        XCTAssertEqual(Set(advanced.destinations), [
            .demoType,
            .breakTimer,
            .panorama,
            .webcamDetails,
            .recordingFormats,
            .complexEditor
        ])
        XCTAssertEqual(plan.section(containing: .zoomBehavior)?.id, .general)
        XCTAssertEqual(plan.section(containing: .coreHotkeys)?.id, .shortcuts)
        XCTAssertEqual(plan.section(containing: .snip)?.id, .captureAndDraw)
        XCTAssertEqual(plan.section(containing: .drawing)?.id, .captureAndDraw)
        XCTAssertEqual(plan.section(containing: .recordingCore)?.id, .recording)
        XCTAssertEqual(plan.section(containing: .permissionCenter)?.id, .permissions)
    }

    func testEverySettingsDestinationHasExactlyOneOwner() {
        let plan = SettingsNavigationModel.defaultPlan
        let destinations = plan.sections.flatMap(\.destinations)

        XCTAssertEqual(destinations.count, Set(destinations).count)
        XCTAssertEqual(Set(destinations), Set(SettingsDestination.allCases))
    }

    @MainActor
    func testHotkeyCaptureSessionSuspendsOnlyDuringCaptureAndResumesExactlyOnce() {
        var suspendCount = 0
        var resumeCount = 0
        let session = HotkeyCaptureSession(
            suspendHotkeys: { suspendCount += 1 },
            resumeHotkeys: { resumeCount += 1 }
        )

        XCTAssertEqual(session.state, .idle)
        session.begin()
        session.begin()
        XCTAssertEqual(session.state, .recording)
        XCTAssertEqual(suspendCount, 1)
        XCTAssertEqual(resumeCount, 0)

        session.finish()
        session.finish()
        XCTAssertEqual(session.state, .idle)
        XCTAssertEqual(suspendCount, 1)
        XCTAssertEqual(resumeCount, 1)
    }

    @MainActor
    func testSettingsWindowUsesNormalSplitNavigationAndDoesNotSuspendHotkeysOnOpen() {
        let store = SettingsStoreFake()
        var suspendCount = 0
        var resumeCount = 0
        let controller = SettingsWindowController(
            settingsStore: store,
            onHotKeyChange: {},
            onSettingsChange: {},
            onSuspendHotkeys: { suspendCount += 1 },
            onResumeHotkeys: { resumeCount += 1 },
            onRequestMicrophone: {},
            onRequestCamera: {},
            onOpenTrimEditor: {},
            onOpenPermissionCenter: {}
        )

        controller.show()
        defer { controller.close() }

        XCTAssertEqual(controller.windowLevel, .normal)
        XCTAssertTrue(controller.usesSplitNavigation)
        XCTAssertEqual(controller.renderedSectionIDs, SettingsNavigationSectionID.allCases)
        XCTAssertEqual(controller.windowFrameAutosaveName, "DoraZoom.SettingsWindow")
        XCTAssertEqual(suspendCount, 0)
        XCTAssertEqual(resumeCount, 0)
    }
}

private final class SettingsStoreFake: SettingsStore {
    private var settings = AppSettings.defaults

    func load() -> AppSettings { settings }
    func save(_ settings: AppSettings) { self.settings = settings }
}
