import XCTest
@testable import ZoomItMacCore

final class AppleIterationFeatureCoverageTests: XCTestCase {
    func testCurrentCoverageListsOnlyUnimplementedLatestPRDCapabilitiesAsGaps() {
        let map = ZoomItFeatureCoverageMap.current

        XCTAssertTrue(Self.latestCapabilities.isSubset(of: Set(map.requiredCapabilities)))
        XCTAssertEqual(
            Set(map.gaps.map(\.capability)),
            Self.latestCapabilities.subtracting([
                .permissionCenter,
                .macSettingsNavigation,
                .transientModeFeedback,
                .displaySynchronizedZoom,
                .blurAndRedact,
                .numberedCallouts,
                .previousRegionSnip,
                .windowSnipToClipboard,
                .multiDisplayTargeting,
                .recordingPreflight,
                .recordingPauseAndResume,
                .recordingRecovery,
                .recordingClickAndShortcutOverlay,
                .lightweightRecordingResult
            ])
        )
    }

    func testCoverageAPIUsesCurrentIterationNamesInsteadOfHistoricalPhaseNames() throws {
        let map = ZoomItFeatureCoverageMap.current
        let entry = try XCTUnwrap(map.entry(for: .permissionCenter))

        XCTAssertEqual(entry.status, .localSimulationAccepted)
    }

    func testRequiredCapabilitiesDeclareTheirProductTier() throws {
        let map = ZoomItFeatureCoverageMap.current

        for capability in map.requiredCapabilities {
            let entry = try XCTUnwrap(map.entry(for: capability))
            XCTAssertNotEqual(entry.productTier, .unclassified)
        }

        XCTAssertEqual(map.entry(for: .blurAndRedact)?.productTier, .defaultCore)
        XCTAssertEqual(map.entry(for: .breakTimer)?.productTier, .advancedCompatibility)
        XCTAssertEqual(map.entry(for: .permissionCenter)?.productTier, .sharedPlatform)
    }

    func testCurrentProductTiersMatchTheLatestPRDDefaultAdvancedAndPlatformLayers() {
        let map = ZoomItFeatureCoverageMap.current
        let required = Set(map.requiredCapabilities)

        XCTAssertTrue(Set([ZoomItFeatureCapability.pasteCompatibility, .cursorFeedback]).isSubset(of: required))

        let advanced = Set(map.entries.filter {
            $0.isPRDRequired && $0.productTier == .advancedCompatibility
        }.map(\.capability))
        XCTAssertEqual(advanced, [
            .regionSnipToFile,
            .webcamPictureInPicture,
            .postRecordingEditor,
            .breakTimer,
            .demoType,
            .panoramaClipboardOrFile,
            .drawingTextRecordingWebcamPanoramaAndLaunchSettings,
            .launchAtLogin
        ])

        let sharedPlatform = Set(map.entries.filter {
            $0.isPRDRequired && $0.productTier == .sharedPlatform
        }.map(\.capability))
        XCTAssertEqual(sharedPlatform, [
            .settingsAndHotkeyCustomization,
            .singleInstance,
            .menuBarStatus,
            .permissionChecks,
            .pasteCompatibility,
            .cursorFeedback,
            .permissionCenter,
            .macSettingsNavigation,
            .transientModeFeedback,
            .displaySynchronizedZoom,
            .multiDisplayTargeting
        ])
    }

    func testCoverageSeparatesAcceptedEvidenceFromPlannedWorkAndManualAcceptance() throws {
        let map = ZoomItFeatureCoverageMap.current
        let accepted = try XCTUnwrap(map.entry(for: .staticZoom))
        let latestAccepted = try XCTUnwrap(map.entry(for: .lightweightRecordingResult))

        XCTAssertFalse(accepted.implementationRefs.isEmpty)
        XCTAssertFalse(accepted.simulatedTestRefs.isEmpty)
        XCTAssertTrue(accepted.plannedImplementationRefs.isEmpty)
        XCTAssertTrue(accepted.plannedSimulatedTestRefs.isEmpty)
        XCTAssertTrue(accepted.evidenceRefs.contains(.localSimulationAcceptance))

        XCTAssertEqual(latestAccepted.status, .localSimulationAccepted)
        XCTAssertFalse(latestAccepted.implementationRefs.isEmpty)
        XCTAssertFalse(latestAccepted.simulatedTestRefs.isEmpty)
        XCTAssertTrue(latestAccepted.plannedImplementationRefs.isEmpty)
        XCTAssertTrue(latestAccepted.plannedSimulatedTestRefs.isEmpty)
        XCTAssertTrue(latestAccepted.evidenceRefs.contains(.localSimulationAcceptance))
        XCTAssertTrue(latestAccepted.evidenceRefs.contains(.userManualAcceptance))

        XCTAssertEqual(map.validationIssues, [])
    }

    func testTextInputCoverageIncludesNativeEditorPasteArbitrationAndManualIMEAcceptance() throws {
        let entry = try XCTUnwrap(
            ZoomItFeatureCoverageMap.current.entry(for: .textInputAlignmentAndFontSize)
        )

        XCTAssertTrue(entry.implementationRefs.contains(
            "Sources/ZoomItMacCore/Overlay/CanvasTextEditingSession.swift"
        ))
        XCTAssertTrue(entry.implementationRefs.contains(
            "Sources/ZoomItMacCore/App/ControlVPasteHotkeyService.swift"
        ))
        XCTAssertTrue(entry.simulatedTestRefs.contains(
            "Tests/ZoomItMacCoreTests/AppleNativeTextEditingTests.swift"
        ))
        XCTAssertTrue(entry.simulatedTestRefs.contains(
            "Tests/ZoomItMacCoreTests/Phase3EventTapTests.swift"
        ))
        XCTAssertTrue(entry.simulatedTestRefs.contains(
            "Tests/ZoomItMacCoreTests/AppleShortcutGuideConsistencyTests.swift"
        ))
        XCTAssertTrue(entry.evidenceRefs.contains(.userManualAcceptance))
    }

    func testCoverageValidationRejectsMixedOrMisclassifiedEvidence() {
        let acceptedWithoutSimulation = ZoomItFeatureCoverageEntry(
            capability: .staticZoom,
            isPRDRequired: true,
            productTier: .defaultCore,
            implementationRefs: ["StaticZoom.swift"],
            simulatedTestRefs: ["StaticZoomTests.swift"],
            plannedImplementationRefs: [],
            plannedSimulatedTestRefs: [],
            evidenceRefs: [.userManualAcceptance],
            status: .localSimulationAccepted
        )
        let acceptedWithPlannedWork = ZoomItFeatureCoverageEntry(
            capability: .liveZoom,
            isPRDRequired: true,
            productTier: .defaultCore,
            implementationRefs: ["LiveZoom.swift"],
            simulatedTestRefs: ["LiveZoomTests.swift"],
            plannedImplementationRefs: ["FutureLiveZoom.swift"],
            plannedSimulatedTestRefs: [],
            evidenceRefs: [.localSimulationAcceptance],
            status: .localSimulationAccepted
        )
        let gapClaimingCompletedEvidence = ZoomItFeatureCoverageEntry(
            capability: .permissionCenter,
            isPRDRequired: true,
            productTier: .sharedPlatform,
            implementationRefs: ["PermissionCenter.swift"],
            simulatedTestRefs: ["PermissionCenterTests.swift"],
            plannedImplementationRefs: ["PermissionCenter.swift"],
            plannedSimulatedTestRefs: ["PermissionCenterTests.swift"],
            evidenceRefs: [.localSimulationAcceptance, .userManualAcceptance],
            status: .implementationGap
        )
        let map = ZoomItFeatureCoverageMap(
            requiredCapabilities: [.staticZoom, .liveZoom, .permissionCenter],
            entries: [acceptedWithoutSimulation, acceptedWithPlannedWork, gapClaimingCompletedEvidence],
            platformBoundary: .simulatedOnly
        )

        XCTAssertEqual(map.validationIssues, [
            .acceptedWithoutLocalSimulationEvidence(.staticZoom),
            .acceptedStillHasPlannedWork(.liveZoom),
            .gapClaimsCompletedEvidence(.permissionCenter)
        ])
    }

    private static let latestCapabilities: Set<ZoomItFeatureCapability> = [
        .permissionCenter,
        .macSettingsNavigation,
        .transientModeFeedback,
        .displaySynchronizedZoom,
        .blurAndRedact,
        .previousRegionSnip,
        .windowSnipToClipboard,
        .numberedCallouts,
        .multiDisplayTargeting,
        .recordingPreflight,
        .recordingPauseAndResume,
        .recordingRecovery,
        .recordingClickAndShortcutOverlay,
        .lightweightRecordingResult
    ]
}
