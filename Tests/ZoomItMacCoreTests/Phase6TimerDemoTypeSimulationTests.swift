import XCTest
@testable import ZoomItMacCore

final class Phase6TimerDemoTypeSimulationTests: XCTestCase {
    func testBreakTimerVirtualClockCoversStartExpirySoundExitAndFeedbackIsolation() {
        var settings = AppSettings.defaults
        settings.breakDurationMinutes = 1
        settings.breakPlaySound = true
        settings.breakSoundFile = ""
        settings.breakShowExpiredTime = true

        let result = BreakTimerSimulation.run(
            settings: settings,
            events: [
                .start,
                .advance(seconds: 59),
                .advance(seconds: 1),
                .advance(seconds: 75),
                .exit
            ]
        )

        XCTAssertEqual(result.platformBoundary, .simulatedOnly)
        XCTAssertEqual(result.snapshots.map(\.visibleText), ["1:00", "0:01", "0:00", "0:00"])
        XCTAssertEqual(result.snapshots.last?.expiredText, "(- 1:15)")
        XCTAssertEqual(result.soundEvents, [.beepAtZero])
        XCTAssertEqual(result.lifecycleEvents, [.started, .idleSleepAssertionBegan, .expired, .closedByUser, .idleSleepAssertionEnded])
        XCTAssertEqual(result.recordingVisibility, .excludedFromRecording)
        XCTAssertFalse(result.touchesRealTimer)
        XCTAssertFalse(result.touchesRealSound)
        XCTAssertFalse(result.touchesRealWindow)
    }

    func testDemoTypeReplayCoversStartPreviousSegmentPasteEnterAndExitWithoutRealKeyboard() {
        var simulation = DemoTypeReplaySimulation(
            script: "hi[end][paste]clip[/paste][enter]bye[end]",
            mode: .automatic
        )

        let first = simulation.apply(.start)
        XCTAssertEqual(first.outputs, [.typeText("h"), .typeText("i")])
        XCTAssertEqual(first.feedback, [.hud(segmentIndex: 0, status: .running), .hud(segmentIndex: 0, status: .segmentEnded)])
        XCTAssertEqual(first.cursorOffset, 7)

        let previous = simulation.apply(.previousSegment)
        XCTAssertEqual(previous.cursorOffset, 0)
        XCTAssertEqual(previous.feedback, [.hud(segmentIndex: 0, status: .rewound)])

        let replayedFirst = simulation.apply(.start)
        XCTAssertEqual(replayedFirst.outputs, [.typeText("h"), .typeText("i")])

        let second = simulation.apply(.start)
        XCTAssertEqual(second.outputs, [
            .copyTextToPasteboard("clip"),
            .postCommandV,
            .pressKey(.enter),
            .typeText("b"),
            .typeText("y"),
            .typeText("e")
        ])
        XCTAssertEqual(second.feedback.last, .hud(segmentIndex: 1, status: .segmentEnded))

        let exit = simulation.apply(.exit)
        XCTAssertEqual(exit.outputs, [])
        XCTAssertEqual(exit.feedback, [.hud(segmentIndex: 1, status: .stopped)])
        XCTAssertEqual(exit.platformBoundary, .simulatedOnly)
        XCTAssertFalse(exit.touchesRealKeyboard)
        XCTAssertFalse(exit.touchesRealPasteboard)
        XCTAssertFalse(exit.touchesTargetApp)
    }

    func testFeatureCoverageMarksTimerAndDemoTypeAcceptedByLocalSimulation() throws {
        let map = ZoomItFeatureCoverageMap.current

        for capability in [ZoomItFeatureCapability.breakTimer, .demoType] {
            let entry = try XCTUnwrap(map.entry(for: capability))
            XCTAssertEqual(entry.status, .localSimulationAccepted)
            XCTAssertTrue(entry.simulatedTestRefs.contains("Tests/ZoomItMacCoreTests/Phase6TimerDemoTypeSimulationTests.swift"))
            XCTAssertTrue(entry.evidenceRefs.contains(.localSimulationAcceptance))
        }
    }
}
