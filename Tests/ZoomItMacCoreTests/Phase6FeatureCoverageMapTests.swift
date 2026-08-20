import XCTest
@testable import ZoomItMacCore

final class FeatureCoverageMapTests: XCTestCase {
    func testMapListsEveryPRDRequiredCapabilityWithValidAcceptedOrPlannedEvidence() throws {
        let map = ZoomItFeatureCoverageMap.current

        XCTAssertEqual(map.platformBoundary, .simulatedOnly)
        XCTAssertEqual(map.requiredCapabilities, ZoomItFeatureCapability.prdSection5_1)
        XCTAssertEqual(Set(map.requiredCapabilities), Set(map.entries.filter(\.isPRDRequired).map(\.capability)))
        XCTAssertEqual(map.validationIssues, [])

        for capability in ZoomItFeatureCapability.prdSection5_1 {
            let entry = try XCTUnwrap(map.entry(for: capability), "Missing coverage row for \(capability)")
            XCTAssertNotEqual(entry.status, .unknown, "\(capability) must not have an unknown coverage status")

            switch entry.status {
            case .localSimulationAccepted:
                XCTAssertFalse(entry.implementationRefs.isEmpty, "\(capability) must point at implemented production code")
                XCTAssertFalse(entry.simulatedTestRefs.isEmpty, "\(capability) must point at passing simulated tests")
                XCTAssertTrue(entry.plannedImplementationRefs.isEmpty)
                XCTAssertTrue(entry.plannedSimulatedTestRefs.isEmpty)
            case .implementationGap:
                XCTAssertTrue(entry.implementationRefs.isEmpty, "\(capability) must not claim production implementation before it exists")
                XCTAssertTrue(entry.simulatedTestRefs.isEmpty, "\(capability) must not claim passing tests before they exist")
                XCTAssertFalse(entry.plannedImplementationRefs.isEmpty, "\(capability) must name its planned implementation surface")
                XCTAssertFalse(entry.plannedSimulatedTestRefs.isEmpty, "\(capability) must name its planned simulated proof")
            case .unknown:
                XCTFail("\(capability) must not remain unknown")
            }
        }
    }

    func testMapMarksPlatformSensitiveCapabilitiesAcceptedByLocalSimulation() throws {
        let map = ZoomItFeatureCoverageMap.current

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
            XCTAssertTrue(entry.evidenceRefs.contains(.localSimulationAcceptance), "\(capability) needs a local simulation acceptance ref")
            XCTAssertEqual(entry.status, .localSimulationAccepted, "\(capability) should be accepted by local simulation, not blocked on real Mac acceptance")
        }
    }

    func testImageExportCapabilitiesAreCoveredAndAcceptedByLocalSimulation() throws {
        let map = ZoomItFeatureCoverageMap.current
        let covered: [ZoomItFeatureCapability] = [
            .currentViewportCopyAndSave,
            .regionSnipToFile,
            .regionOCRToClipboard
        ]

        for capability in covered {
            let entry = try XCTUnwrap(map.entry(for: capability), "Missing coverage row for \(capability)")
            XCTAssertEqual(entry.status, .localSimulationAccepted)
            XCTAssertTrue(entry.simulatedTestRefs.contains("Tests/ZoomItMacCoreTests/Phase6ImageExportSimulationTests.swift"))
            XCTAssertTrue(entry.evidenceRefs.contains(.localSimulationAcceptance))
        }
    }

    func testPanoramaIsCoveredAndAcceptedByLocalSimulation() throws {
        let map = ZoomItFeatureCoverageMap.current
        let entry = try XCTUnwrap(map.entry(for: .panoramaClipboardOrFile))

        XCTAssertEqual(entry.status, .localSimulationAccepted)
        XCTAssertTrue(entry.simulatedTestRefs.contains("Tests/ZoomItMacCoreTests/Phase6PanoramaSimulationTests.swift"))
        XCTAssertTrue(entry.evidenceRefs.contains(.localSimulationAcceptance))
    }
}
