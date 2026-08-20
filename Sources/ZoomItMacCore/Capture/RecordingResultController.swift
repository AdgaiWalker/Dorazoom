import Foundation

enum RecordingEditorPresentationMode: Equatable, Sendable {
    case lightweight
    case advanced
}

enum RecordingResultControl: Equatable, Sendable {
    case preview
    case trim
    case mute
    case volume
    case export
    case openFileInFinder
    case advancedEditor
    case appendClip
    case deleteRange
    case transition
}

struct RecordingResultPresentation: Equatable, Sendable {
    var primaryControls: [RecordingResultControl]
    var secondaryControls: [RecordingResultControl]
    var mutatesSourceFile: Bool
}

enum RecordingResultPresentationPlan {
    static func plan(for mode: RecordingEditorPresentationMode) -> RecordingResultPresentation {
        switch mode {
        case .lightweight:
            return RecordingResultPresentation(
                primaryControls: [
                    .preview,
                    .trim,
                    .mute,
                    .volume,
                    .export,
                    .openFileInFinder
                ],
                secondaryControls: [.advancedEditor],
                mutatesSourceFile: false
            )
        case .advanced:
            return RecordingResultPresentation(
                primaryControls: [
                    .preview,
                    .trim,
                    .mute,
                    .volume,
                    .export,
                    .openFileInFinder,
                    .appendClip,
                    .deleteRange,
                    .transition
                ],
                secondaryControls: [],
                mutatesSourceFile: false
            )
        }
    }
}

enum RecordingResultAudioPolicy {
    static func exportVolume(sliderVolume: Float, isMuted: Bool) -> Float {
        isMuted ? 0 : min(1, max(0, sliderVolume))
    }

    static func requiresExport(sliderVolume: Float, isMuted: Bool) -> Bool {
        abs(exportVolume(sliderVolume: sliderVolume, isMuted: isMuted) - 1) > 0.0001
    }
}

@MainActor
final class RecordingResultController {
    nonisolated static let initialPresentationMode = RecordingEditorPresentationMode.lightweight

    private let editor = VideoClipEditorController()

    func present(
        tempURL: URL,
        suggestedName: String,
        outputProfile: MovieRecordingProfile,
        onExport: @escaping (URL) -> Void,
        onCancel: @escaping () -> Void
    ) {
        editor.present(
            tempURL: tempURL,
            suggestedName: suggestedName,
            outputProfile: outputProfile,
            mode: Self.initialPresentationMode,
            onSave: onExport,
            onCancel: onCancel
        )
    }
}
