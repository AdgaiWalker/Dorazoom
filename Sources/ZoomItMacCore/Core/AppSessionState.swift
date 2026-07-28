import Foundation

enum RegionSelectionPurpose: Equatable, Sendable {
    case screenshotToClipboard
    case screenshotToFile
    case ocrToClipboard
    case recording
}

enum InteractionState: Equatable, Sendable {
    case idle
    case staticZoom
    case liveZoom
    case drawing(live: Bool)
    case typing(rightAligned: Bool)
    case regionSelection(RegionSelectionPurpose)
    case panorama(save: Bool)
    case demoType
    case timer
}

enum RecordingTarget: Equatable, Sendable {
    case fullScreen(displayID: UInt32)
    case region(x: Double, y: Double, width: Double, height: Double)
    case window(windowID: UInt32)
}

enum RecordingState: Equatable, Sendable {
    case idle
    case recording(
        target: RecordingTarget,
        elapsedSeconds: Int,
        includesSystemAudio: Bool,
        includesMicrophone: Bool,
        includesWebcam: Bool
    )

    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    var includesWebcam: Bool {
        guard case let .recording(_, _, _, _, includesWebcam) = self else { return false }
        return includesWebcam
    }

    var elapsedSeconds: Int? {
        guard case let .recording(_, elapsedSeconds, _, _, _) = self else { return nil }
        return elapsedSeconds
    }
}

struct AnnotationState: Equatable, Sendable {
    var tool: AnnotationTool
    var color: AnnotationColor
    var isHighlighter: Bool
}

enum CanvasBackground: Equatable, Sendable {
    case transparent
    case whiteboard
    case blackboard

    var renderFill: CanvasBackgroundRenderFill {
        switch self {
        case .transparent:
            return .none
        case .whiteboard:
            return .white
        case .blackboard:
            return .black
        }
    }

    var isCompositedIntoExports: Bool {
        self != .transparent
    }
}

enum CanvasBackgroundRenderFill: Equatable, Sendable {
    case none
    case white
    case black
}

struct AppSessionState: Equatable, Sendable {
    var interaction: InteractionState
    var recording: RecordingState
    var annotation: AnnotationState
    var canvas: CanvasBackground

    var isRecording: Bool { recording.isRecording }
}

enum PointerPurpose: Equatable, Sendable {
    case zoom
    case draw
    case screenshot
    case ocr
    case recordingSelection
    case panoramaSelection
}

enum PointerFeedback: Equatable, Sendable {
    case system
    case crosshair(purpose: PointerPurpose)
    case pen
    case text
}

enum RecordingStatusFeedback: Equatable, Sendable {
    case hidden
    case visible(elapsedSeconds: Int)
}

enum MenuBarFeedback: Equatable, Sendable {
    case idle
    case active
    case recording
}

enum PaletteFeedback: Equatable, Sendable {
    case hidden
    case drawing(tool: AnnotationTool, color: AnnotationColor, canvas: CanvasBackground)
}

struct InteractionPresentationSnapshot: Equatable, Sendable {
    var pointer: PointerFeedback
    var recordingStatus: RecordingStatusFeedback
    var menuBar: MenuBarFeedback
    var palette: PaletteFeedback

    static func derive(from state: AppSessionState) -> InteractionPresentationSnapshot {
        InteractionPresentationSnapshot(
            pointer: pointer(for: state),
            recordingStatus: recordingStatus(for: state.recording),
            menuBar: state.isRecording ? .recording : menuBar(for: state.interaction),
            palette: palette(for: state)
        )
    }

    private static func pointer(for state: AppSessionState) -> PointerFeedback {
        switch state.interaction {
        case .idle:
            return .system
        case .staticZoom, .liveZoom:
            return .crosshair(purpose: .zoom)
        case .drawing:
            return state.annotation.tool == .text ? .text : .pen
        case .typing:
            return .text
        case .regionSelection(.screenshotToClipboard), .regionSelection(.screenshotToFile):
            return .crosshair(purpose: .screenshot)
        case .regionSelection(.ocrToClipboard):
            return .crosshair(purpose: .ocr)
        case .regionSelection(.recording):
            return .crosshair(purpose: .recordingSelection)
        case .panorama:
            return .crosshair(purpose: .panoramaSelection)
        case .demoType, .timer:
            return .crosshair(purpose: .draw)
        }
    }

    private static func recordingStatus(for recording: RecordingState) -> RecordingStatusFeedback {
        guard let elapsed = recording.elapsedSeconds else { return .hidden }
        return .visible(elapsedSeconds: elapsed)
    }

    private static func menuBar(for interaction: InteractionState) -> MenuBarFeedback {
        interaction == .idle ? .idle : .active
    }

    private static func palette(for state: AppSessionState) -> PaletteFeedback {
        switch state.interaction {
        case .drawing, .typing:
            return .drawing(tool: state.annotation.tool, color: state.annotation.color, canvas: state.canvas)
        default:
            return .hidden
        }
    }
}
