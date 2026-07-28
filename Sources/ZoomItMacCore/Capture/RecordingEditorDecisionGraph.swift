import Foundation

struct RecordingEditorClip: Equatable, Sendable {
    var id: String
    var durationSeconds: Double
}

struct RecordingEditorTimeRange: Equatable, Sendable {
    var startSeconds: Double
    var endSeconds: Double

    var durationSeconds: Double {
        max(0, endSeconds - startSeconds)
    }
}

enum RecordingEditorTransition: Equatable, Sendable {
    case fadeBlack
    case none
    case fadeWhite
}

enum RecordingEditorOperation: Equatable, Sendable {
    case preview
    case trim(startSeconds: Double, endSeconds: Double)
    case append(RecordingEditorClip, transition: RecordingEditorTransition)
    case setVolume(Double)
    case setMuted(Bool)
}

enum RecordingEditorRejectedOperation: Equatable, Sendable {
    case invalidTrim(startSeconds: Double, endSeconds: Double)
}

enum RecordingEditorPreviewDecision: Equatable, Sendable {
    case disabled
    case enabled(activeRange: RecordingEditorTimeRange)
}

struct RecordingEditorTimelineSegment: Equatable, Sendable {
    var sourceID: String
    var sourceRange: RecordingEditorTimeRange
    var outputStartSeconds: Double

    var durationSeconds: Double {
        sourceRange.durationSeconds
    }
}

struct RecordingEditorTransitionDecision: Equatable, Sendable {
    var boundarySeconds: Double
    var transition: RecordingEditorTransition
    var durationSeconds: Double
}

enum RecordingEditorAudioDecision: Equatable, Sendable {
    case volume(Double)
    case muted(previousAudibleVolume: Double)
}

enum RecordingEditorExportAction: Equatable, Sendable {
    case writeNewFile
}

struct RecordingEditorExportDecision: Equatable, Sendable {
    var fileExtension: String
    var action: RecordingEditorExportAction
}

enum RecordingEditorSourceFileAction: Equatable, Sendable {
    case none
}

struct RecordingEditorDecisionPlan: Equatable, Sendable {
    var preview: RecordingEditorPreviewDecision
    var timelineSegments: [RecordingEditorTimelineSegment]
    var transitions: [RecordingEditorTransitionDecision]
    var audio: RecordingEditorAudioDecision
    var export: RecordingEditorExportDecision
    var sourceFileActions: [RecordingEditorSourceFileAction]
    var mutatesSourceFiles: Bool
    var rejectedOperations: [RecordingEditorRejectedOperation]
    var platformBoundary: AutomationPlatformBoundary
}

enum RecordingEditorDecisionGraph {
    static func make(
        source: RecordingEditorClip,
        operations: [RecordingEditorOperation],
        outputProfile: MovieRecordingProfile
    ) -> RecordingEditorDecisionPlan {
        var baseRange = RecordingEditorTimeRange(
            startSeconds: 0,
            endSeconds: max(0, source.durationSeconds)
        )
        var appended: [(clip: RecordingEditorClip, transition: RecordingEditorTransition)] = []
        var volume = 1.0
        var previousAudibleVolume = 1.0
        var muted = false
        var previewEnabled = false
        var rejectedOperations: [RecordingEditorRejectedOperation] = []

        for operation in operations {
            switch operation {
            case .preview:
                previewEnabled = true
            case .trim(let start, let end):
                if start >= 0, end <= source.durationSeconds, end > start {
                    baseRange = RecordingEditorTimeRange(startSeconds: rounded(start), endSeconds: rounded(end))
                } else {
                    rejectedOperations.append(.invalidTrim(startSeconds: start, endSeconds: end))
                }
            case .append(let clip, let transition):
                guard clip.durationSeconds > 0 else { continue }
                appended.append((clip, transition))
            case .setVolume(let newVolume):
                volume = clampedVolume(newVolume)
                if volume > 0 {
                    previousAudibleVolume = volume
                }
            case .setMuted(let newMuted):
                if newMuted, volume > 0 {
                    previousAudibleVolume = volume
                }
                muted = newMuted
            }
        }

        var timelineSegments: [RecordingEditorTimelineSegment] = [
            RecordingEditorTimelineSegment(sourceID: source.id, sourceRange: baseRange, outputStartSeconds: 0)
        ]
        var transitions: [RecordingEditorTransitionDecision] = []
        var cursor = baseRange.durationSeconds
        for entry in appended {
            transitions.append(.init(boundarySeconds: rounded(cursor), transition: entry.transition, durationSeconds: 1))
            let range = RecordingEditorTimeRange(startSeconds: 0, endSeconds: rounded(entry.clip.durationSeconds))
            timelineSegments.append(.init(sourceID: entry.clip.id, sourceRange: range, outputStartSeconds: rounded(cursor)))
            cursor += range.durationSeconds
        }

        let activeRange = RecordingEditorTimeRange(startSeconds: 0, endSeconds: rounded(cursor))
        let preview: RecordingEditorPreviewDecision = previewEnabled || !operations.isEmpty
            ? .enabled(activeRange: activeRange)
            : .disabled

        return RecordingEditorDecisionPlan(
            preview: preview,
            timelineSegments: timelineSegments,
            transitions: transitions,
            audio: muted ? .muted(previousAudibleVolume: rounded(previousAudibleVolume)) : .volume(rounded(volume)),
            export: .init(fileExtension: outputProfile.fileExtension, action: .writeNewFile),
            sourceFileActions: [],
            mutatesSourceFiles: false,
            rejectedOperations: rejectedOperations,
            platformBoundary: .simulatedOnly
        )
    }

    private static func clampedVolume(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    private static func rounded(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}
