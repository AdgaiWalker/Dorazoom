import XCTest
@testable import ZoomItMacCore

final class Phase5RecordingEditorDecisionPlanTests: XCTestCase {
    func testEditorDecisionGraphKeepsPreviewTrimAppendTransitionMuteAndExportNonDestructive() {
        let original = RecordingEditorClip(id: "recording.mov", durationSeconds: 12)
        let appendix = RecordingEditorClip(id: "appendix.mov", durationSeconds: 4)

        let plan = RecordingEditorDecisionGraph.make(
            source: original,
            operations: [
                .preview,
                .trim(startSeconds: 2, endSeconds: 10),
                .append(appendix, transition: .fadeWhite),
                .setVolume(0.35),
                .setMuted(true)
            ],
            outputProfile: .init(container: .mov, fileExtension: "mov", videoCodec: .h264, audioCodec: .aac)
        )

        XCTAssertEqual(plan.preview, .enabled(activeRange: .init(startSeconds: 0, endSeconds: 12)))
        XCTAssertEqual(plan.timelineSegments, [
            .init(sourceID: "recording.mov", sourceRange: .init(startSeconds: 2, endSeconds: 10), outputStartSeconds: 0),
            .init(sourceID: "appendix.mov", sourceRange: .init(startSeconds: 0, endSeconds: 4), outputStartSeconds: 8)
        ])
        XCTAssertEqual(plan.transitions, [
            .init(boundarySeconds: 8, transition: .fadeWhite, durationSeconds: 1)
        ])
        XCTAssertEqual(plan.audio, .muted(previousAudibleVolume: 0.35))
        XCTAssertEqual(plan.export, .init(fileExtension: "mov", action: .writeNewFile))
        XCTAssertEqual(plan.sourceFileActions, [])
        XCTAssertFalse(plan.mutatesSourceFiles)
        XCTAssertEqual(plan.platformBoundary, .simulatedOnly)
    }

    func testEditorDecisionGraphExportsVolumeWhenNotMutedAndRejectsInvalidTrim() {
        let original = RecordingEditorClip(id: "recording.mov", durationSeconds: 8)

        let plan = RecordingEditorDecisionGraph.make(
            source: original,
            operations: [
                .trim(startSeconds: 6, endSeconds: 3),
                .setVolume(0.6),
                .setMuted(false)
            ],
            outputProfile: .init(container: .mov, fileExtension: "mov", videoCodec: .h264, audioCodec: .aac)
        )

        XCTAssertEqual(plan.preview, .enabled(activeRange: .init(startSeconds: 0, endSeconds: 8)))
        XCTAssertEqual(plan.timelineSegments, [
            .init(sourceID: "recording.mov", sourceRange: .init(startSeconds: 0, endSeconds: 8), outputStartSeconds: 0)
        ])
        XCTAssertEqual(plan.audio, .volume(0.6))
        XCTAssertEqual(plan.rejectedOperations, [.invalidTrim(startSeconds: 6, endSeconds: 3)])
        XCTAssertFalse(plan.mutatesSourceFiles)
    }
}
