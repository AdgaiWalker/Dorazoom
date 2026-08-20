import XCTest
@testable import ZoomItMacCore

final class AppleRecordingResultTests: XCTestCase {
    func testLightweightResultExposesOnlyDailyControlsAndOneAdvancedEntry() {
        let plan = RecordingResultPresentationPlan.plan(for: .lightweight)

        XCTAssertEqual(plan.primaryControls, [
            .preview,
            .trim,
            .mute,
            .volume,
            .export,
            .openFileInFinder
        ])
        XCTAssertEqual(plan.secondaryControls, [.advancedEditor])
        XCTAssertFalse(plan.primaryControls.contains(.appendClip))
        XCTAssertFalse(plan.primaryControls.contains(.deleteRange))
        XCTAssertFalse(plan.primaryControls.contains(.transition))
        XCTAssertFalse(plan.mutatesSourceFile)
    }

    func testAdvancedEditorOwnsComplexCompositionControls() {
        let plan = RecordingResultPresentationPlan.plan(for: .advanced)

        XCTAssertTrue(plan.primaryControls.contains(.appendClip))
        XCTAssertTrue(plan.primaryControls.contains(.deleteRange))
        XCTAssertTrue(plan.primaryControls.contains(.transition))
        XCTAssertFalse(plan.primaryControls.contains(.advancedEditor))
        XCTAssertFalse(plan.mutatesSourceFile)
    }

    func testRecordingResultControllerAlwaysStartsInLightweightMode() {
        XCTAssertEqual(RecordingResultController.initialPresentationMode, .lightweight)
    }

    func testTrimVolumeAndMuteRemainNonDestructiveUntilExport() {
        let source = RecordingEditorClip(id: "simulated.mov", durationSeconds: 15)
        let decision = RecordingEditorDecisionGraph.make(
            source: source,
            operations: [
                .preview,
                .trim(startSeconds: 2, endSeconds: 11),
                .setVolume(0.4),
                .setMuted(true)
            ],
            outputProfile: RecordingOutputStrategy.defaultMovieProfile
        )

        XCTAssertFalse(decision.mutatesSourceFiles)
        XCTAssertEqual(decision.sourceFileActions, [])
        XCTAssertEqual(decision.export.action, .writeNewFile)
        XCTAssertEqual(
            RecordingResultAudioPolicy.exportVolume(sliderVolume: 0.4, isMuted: true),
            0
        )
        XCTAssertTrue(RecordingResultAudioPolicy.requiresExport(
            sliderVolume: 0.4,
            isMuted: false
        ))
        XCTAssertFalse(RecordingResultAudioPolicy.requiresExport(
            sliderVolume: 1,
            isMuted: false
        ))
    }
}
