import Foundation

struct FeedbackPresentationEnvironment: Equatable, Sendable {
    var reduceMotion: Bool
    var reduceTransparency: Bool
    var increaseContrast: Bool

    static let `default` = FeedbackPresentationEnvironment(
        reduceMotion: false,
        reduceTransparency: false,
        increaseContrast: false
    )
}

enum FeedbackCompletion: Equatable, Sendable {
    case screenshotCopied
    case ocrCopied(characterCount: Int)
    case recordingSaved
}

enum FeedbackPresentationEvent: Equatable, Sendable {
    case modeEntered(InteractionState)
    case zoomChanged(factor: CGFloat)
    case toolChanged(tool: AnnotationTool, color: AnnotationColor, width: CGFloat, canvas: CanvasBackground)
    case completed(FeedbackCompletion)
    case warning(String)
    case error(String)
}

enum TransientFeedbackKind: Equatable, Sendable {
    case mode
    case zoom
    case tool
    case completion
    case warning
    case error
}

enum FeedbackCapturePolicy: Equatable, Sendable {
    case excluded
}

enum FeedbackMaterial: Equatable, Sendable {
    case translucent
    case opaque
}

enum FeedbackMotion: Equatable, Sendable {
    case shortFade
    case immediate
}

struct TransientFeedbackPlan: Equatable, Sendable {
    var text: String
    var kind: TransientFeedbackKind
    var duration: TimeInterval
    var capturePolicy: FeedbackCapturePolicy
    var palette: PaletteFeedback
    var material: FeedbackMaterial
    var motion: FeedbackMotion
    var drawsHighContrastBorder: Bool
    var usesMonospacedDigits: Bool
}

@MainActor
protocol FeedbackDismissalToken: AnyObject {
    func cancel()
}

@MainActor
protocol FeedbackDismissalScheduling: AnyObject {
    func schedule(
        after delay: TimeInterval,
        _ action: @escaping @MainActor @Sendable () -> Void
    ) -> FeedbackDismissalToken
}

@MainActor
protocol TransientFeedbackPresenting: AnyObject {
    func present(_ plan: TransientFeedbackPlan)
    func dismiss()
}

@MainActor
final class FeedbackPresentationAdapter {
    private let feedback: InteractionFeedback
    private let scheduler: FeedbackDismissalScheduling
    private let presenter: TransientFeedbackPresenting
    private let environmentProvider: () -> FeedbackPresentationEnvironment
    private var hudLease: FeedbackLease?
    private var dismissal: FeedbackDismissalToken?

    init(
        feedback: InteractionFeedback,
        scheduler: FeedbackDismissalScheduling,
        presenter: TransientFeedbackPresenting,
        environmentProvider: @escaping () -> FeedbackPresentationEnvironment
    ) {
        self.feedback = feedback
        self.scheduler = scheduler
        self.presenter = presenter
        self.environmentProvider = environmentProvider
    }

    @discardableResult
    func present(_ event: FeedbackPresentationEvent) -> TransientFeedbackPlan {
        let plan = Self.plan(for: event, environment: environmentProvider())
        dismissal?.cancel()
        hudLease?.end()

        let lease = feedback.begin(channel: .hud, content: .hud(plan.text))
        hudLease = lease
        presenter.present(plan)
        dismissal = scheduler.schedule(after: plan.duration) { [weak self, weak lease] in
            lease?.end()
            guard self?.hudLease === lease else { return }
            self?.hudLease = nil
            self?.dismissal = nil
            self?.presenter.dismiss()
        }
        return plan
    }

    func dismiss() {
        dismissal?.cancel()
        dismissal = nil
        hudLease?.end()
        hudLease = nil
        presenter.dismiss()
    }

    nonisolated static func plan(
        for event: FeedbackPresentationEvent,
        environment: FeedbackPresentationEnvironment
    ) -> TransientFeedbackPlan {
        let content = content(for: event)
        return TransientFeedbackPlan(
            text: content.text,
            kind: content.kind,
            duration: content.duration,
            capturePolicy: .excluded,
            palette: .hidden,
            material: environment.reduceTransparency ? .opaque : .translucent,
            motion: environment.reduceMotion ? .immediate : .shortFade,
            drawsHighContrastBorder: environment.increaseContrast,
            usesMonospacedDigits: content.usesMonospacedDigits
        )
    }

    nonisolated private static func content(
        for event: FeedbackPresentationEvent
    ) -> (text: String, kind: TransientFeedbackKind, duration: TimeInterval, usesMonospacedDigits: Bool) {
        switch event {
        case let .modeEntered(state):
            return (modeText(state), .mode, 0.9, false)
        case let .zoomChanged(factor):
            return ("\(Int((factor * 100).rounded()))%", .zoom, 0.9, true)
        case let .toolChanged(tool, color, width, canvas):
            let widthText = Int(width.rounded())
            let canvasText: String
            switch canvas {
            case .transparent: canvasText = ""
            case .whiteboard:
                canvasText = text("feedback.canvas.whiteboard_prefix", "Whiteboard · ")
            case .blackboard:
                canvasText = text("feedback.canvas.blackboard_prefix", "Blackboard · ")
            }
            return (
                AppLocalization.format(
                    "feedback.tool.summary",
                    defaultValue: "%1$@%2$@ · %3$@ · %4$lld pt · Esc to exit",
                    canvasText,
                    toolText(tool),
                    color.displayName,
                    Int64(widthText)
                ),
                .tool,
                1.0,
                true
            )
        case let .completed(completion):
            switch completion {
            case .screenshotCopied:
                return (
                    text("feedback.completed.screenshot_copied", "Copied · Paste with ⌘V or ⌃V"),
                    .completion,
                    1.2,
                    false
                )
            case let .ocrCopied(characterCount):
                let key = characterCount == 1
                    ? "feedback.completed.ocr_copied.one"
                    : "feedback.completed.ocr_copied"
                let defaultValue = characterCount == 1
                    ? "Copied %lld character"
                    : "Copied %lld characters"
                return (
                    AppLocalization.format(
                        key,
                        defaultValue: defaultValue,
                        Int64(characterCount)
                    ),
                    .completion,
                    1.2,
                    true
                )
            case .recordingSaved:
                return (
                    text("feedback.completed.recording_saved", "Recording saved"),
                    .completion,
                    1.2,
                    false
                )
            }
        case let .warning(message):
            return (message, .warning, 1.6, false)
        case let .error(message):
            return (message, .error, 2.4, false)
        }
    }

    nonisolated private static func modeText(_ state: InteractionState) -> String {
        switch state {
        case .idle:
            text("feedback.mode.ready", "Ready")
        case .staticZoom:
            text("feedback.mode.static_zoom", "Static Zoom")
        case .liveZoom:
            text("feedback.mode.live_zoom", "Live Zoom")
        case let .drawing(live):
            live
                ? text("feedback.mode.live_drawing", "Live Drawing")
                : text("feedback.mode.drawing", "Drawing")
        case let .typing(rightAligned):
            rightAligned
                ? text("feedback.mode.right_aligned_text", "Right-Aligned Text")
                : text("feedback.mode.text", "Text")
        case .regionSelection(.screenshotToClipboard):
            text("feedback.mode.capture_region_to_clipboard", "Capture Region · Copy to Clipboard")
        case .regionSelection(.screenshotToFile):
            text("feedback.mode.capture_region_to_file", "Capture Region · Save to File")
        case .regionSelection(.ocrToClipboard):
            text("feedback.mode.extract_text_ocr", "Extract Text (OCR)")
        case .regionSelection(.recording):
            text("feedback.mode.select_recording_region", "Select Recording Region")
        case .panorama:
            text("feedback.mode.panorama_capture", "Panorama Capture")
        case .demoType:
            text("feedback.mode.demo_type", "DemoType")
        case .timer:
            text("feedback.mode.break_timer", "Break Timer")
        }
    }

    nonisolated private static func toolText(_ tool: AnnotationTool) -> String {
        switch tool {
        case .pen: text("annotation_tool.pen", "Pen")
        case .line: text("annotation_tool.line", "Line")
        case .rectangle: text("annotation_tool.rectangle", "Rectangle")
        case .ellipse: text("annotation_tool.ellipse", "Ellipse")
        case .arrow: text("annotation_tool.arrow", "Arrow")
        case .text: text("annotation_tool.text", "Text")
        case .highlighter: text("annotation_tool.highlighter", "Highlighter")
        case .blur: text("annotation_tool.blur", "Blur")
        case .redact: text("annotation_tool.redact", "Redact")
        case .numberedCallout: text("annotation_tool.numbered_callout", "Numbered Callout")
        }
    }

    nonisolated private static func text(_ key: String, _ defaultValue: String) -> String {
        AppLocalization.string(key, defaultValue: defaultValue)
    }
}
