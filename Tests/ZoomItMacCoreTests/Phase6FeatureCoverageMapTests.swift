import XCTest
@testable import ZoomItMacCore

final class Phase6FeatureCoverageMapTests: XCTestCase {
    func testMapListsEveryPRDRequiredCapabilityWithEvidenceAndExplicitStatus() throws {
        let map = ZoomItFeatureCoverageMap.phase6Default

        XCTAssertEqual(map.platformBoundary, .simulatedOnly)
        XCTAssertEqual(map.requiredCapabilities, ZoomItFeatureCapability.prdSection5_1)
        XCTAssertEqual(Set(map.requiredCapabilities), Set(map.entries.filter(\.isPRDRequired).map(\.capability)))

        for capability in ZoomItFeatureCapability.prdSection5_1 {
            let entry = try XCTUnwrap(map.entry(for: capability), "Missing coverage row for \(capability)")
            XCTAssertFalse(entry.implementationRefs.isEmpty, "\(capability) must point at implementation or planned implementation refs")
            XCTAssertFalse(entry.simulatedTestRefs.isEmpty, "\(capability) must point at simulated tests or explicit simulated-test gaps")
            XCTAssertNotEqual(entry.status, .unknown, "\(capability) must not have an unknown coverage status")
        }
    }

    func testMapMarksPlatformSensitiveCapabilitiesAcceptedByLocalSimulation() throws {
        let map = ZoomItFeatureCoverageMap.phase6Default

        let platformSensitiveCapabilities: Set<ZoomItFeatureCapability> = [
            .staticZoom,
            .liveZoom,
            .drawWithoutZoom,
            .liveDraw,
            .regionSnipToClipboard,
            .regionSnipToFile,
            .regionOCRToClipboard,
            .fullScreenRecording,
            .regionRecording,
            .windowRecording,
            .systemAudioAndMicrophoneRecording,
            .webcamPictureInPicture,
            .panoramaClipboardOrFile,
            .singleInstance,
            .menuBarStatus,
            .permissionChecks,
            .launchAtLogin,
            .pasteCompatibility,
            .cursorFeedback
        ]

        for capability in platformSensitiveCapabilities {
            let entry = try XCTUnwrap(map.entry(for: capability), "Missing coverage row for \(capability)")
            XCTAssertTrue(entry.phase7Refs.contains(.localSimulationAcceptance), "\(capability) needs a local simulation acceptance ref")
            XCTAssertEqual(entry.status, .localSimulationAccepted, "\(capability) should be accepted by local simulation, not blocked on real Mac acceptance")
        }
    }

    func testMapIdentifiesRemainingPhase6ImplementationGaps() {
        let map = ZoomItFeatureCoverageMap.phase6Default

        XCTAssertEqual(map.gaps, [])
    }

    func testImageExportCapabilitiesAreCoveredAndAcceptedByLocalSimulation() throws {
        let map = ZoomItFeatureCoverageMap.phase6Default
        let covered: [ZoomItFeatureCapability] = [
            .currentViewportCopyAndSave,
            .regionSnipToFile,
            .regionOCRToClipboard
        ]

        for capability in covered {
            let entry = try XCTUnwrap(map.entry(for: capability), "Missing coverage row for \(capability)")
            XCTAssertEqual(entry.status, .localSimulationAccepted)
            XCTAssertTrue(entry.simulatedTestRefs.contains("Tests/ZoomItMacCoreTests/Phase6ImageExportSimulationTests.swift"))
            XCTAssertTrue(entry.phase7Refs.contains(.localSimulationAcceptance))
        }
    }

    func testPanoramaIsCoveredAndAcceptedByLocalSimulation() throws {
        let map = ZoomItFeatureCoverageMap.phase6Default
        let entry = try XCTUnwrap(map.entry(for: .panoramaClipboardOrFile))

        XCTAssertEqual(entry.status, .localSimulationAccepted)
        XCTAssertTrue(entry.simulatedTestRefs.contains("Tests/ZoomItMacCoreTests/Phase6PanoramaSimulationTests.swift"))
        XCTAssertTrue(entry.phase7Refs.contains(.localSimulationAcceptance))
    }
}
