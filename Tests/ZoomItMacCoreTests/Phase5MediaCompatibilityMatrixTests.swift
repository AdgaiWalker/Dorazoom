import XCTest
@testable import ZoomItMacCore

final class Phase5MediaCompatibilityMatrixTests: XCTestCase {
    func testDefaultMatrixDefinesTargetsSamplesChecksAndLocalSimulationResults() {
        let matrix = RecordingMediaCompatibilityMatrix.phase7Default

        XCTAssertEqual(matrix.targets.map(\.environment), [
            .quickTimePlayer,
            .windowsNativePlayback,
            .capCut,
            .davinciResolve
        ])
        XCTAssertTrue(matrix.targets.allSatisfy { $0.versionPolicy == .recordInstalledVersionAtAcceptance })

        XCTAssertEqual(matrix.samples, [
            .init(format: .mov, required: true, purpose: .defaultDailyRecording),
            .init(format: .mov, required: true, purpose: .recordingWithAudioWebcamAndAnnotations),
            .init(format: .mp4, required: true, purpose: .retainedExportOption),
            .init(format: .gif, required: true, purpose: .retainedExportOption)
        ])

        XCTAssertEqual(matrix.requiredChecks, [
            .opensOrImports,
            .playsVideo,
            .audioIsPresentWhenExpected,
            .audioVideoSync,
            .durationMatchesExpected,
            .failureReasonRecorded
        ])
        XCTAssertEqual(Set(matrix.results.map(\.status)), [.localSimulationPassed])
        XCTAssertEqual(matrix.platformBoundary, .simulatedOnly)
    }

    func testMatrixRecordsGifCompatibilityAsLocalSimulationOnly() {
        let matrix = RecordingMediaCompatibilityMatrix.phase7Default

        let gifRows = matrix.results.filter { $0.sample.format == .gif }
        XCTAssertEqual(gifRows.count, 4)
        XCTAssertTrue(gifRows.allSatisfy { $0.status == .localSimulationPassed })
        XCTAssertTrue(gifRows.allSatisfy { $0.notes.contains("Local simulation acceptance only; no external player was launched.") })
    }
}
