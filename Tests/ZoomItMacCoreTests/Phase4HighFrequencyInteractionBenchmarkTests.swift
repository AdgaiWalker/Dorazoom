import XCTest
@testable import ZoomItMacCore

final class Phase4HighFrequencyInteractionBenchmarkTests: XCTestCase {
    func testHighFrequencyBenchmarkIsDeterministicForFixedEventSample() {
        let first = HighFrequencyInteractionBenchmark.run(.phase4Default)
        let second = HighFrequencyInteractionBenchmark.run(.phase4Default)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.eventsProcessed, 190)
        XCTAssertEqual(first.stateCommitCount, first.eventsProcessed)
        XCTAssertGreaterThan(first.renderOperationCount, 0)
        XCTAssertLessThanOrEqual(first.allocationUnits, 1_200)
        XCTAssertLessThanOrEqual(first.simulatedDurationMicroseconds, 25_000)
    }

    func testHighFrequencyBenchmarkKeepsRealPlatformBoundariesOutOfAutomation() {
        let report = HighFrequencyInteractionBenchmark.run(.phase4Default)

        XCTAssertEqual(report.platformBoundary, .simulatedOnly)
        XCTAssertFalse(report.touchesScreenCapture)
        XCTAssertFalse(report.touchesGlobalKeyboard)
        XCTAssertFalse(report.touchesPasteboard)
        XCTAssertFalse(report.touchesMicrophoneOrCamera)
    }
}
