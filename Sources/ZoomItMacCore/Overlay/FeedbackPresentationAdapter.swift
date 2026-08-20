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
            case .whiteboard: canvasText = "白板 · "
            case .blackboard: canvasText = "黑板 · "
            }
            return (
                "\(canvasText)\(toolText(tool)) · \(colorText(color)) · \(widthText) pt　Esc 退出",
                .tool,
                1.0,
                true
            )
        case let .completed(completion):
            switch completion {
            case .screenshotCopied:
                return ("已复制 · ⌘V 或 ⌃V 粘贴", .completion, 1.2, false)
            case let .ocrCopied(characterCount):
                return ("已复制 \(characterCount) 个字符", .completion, 1.2, true)
            case .recordingSaved:
                return ("录制已保存", .completion, 1.2, false)
            }
        case let .warning(message):
            return (message, .warning, 1.6, false)
        case let .error(message):
            return (message, .error, 2.4, false)
        }
    }

    nonisolated private static func modeText(_ state: InteractionState) -> String {
        switch state {
        case .idle: "就绪"
        case .staticZoom: "静态缩放"
        case .liveZoom: "实时缩放"
        case let .drawing(live): live ? "实时圈画" : "圈画"
        case let .typing(rightAligned): rightAligned ? "右对齐文字" : "文字"
        case .regionSelection(.screenshotToClipboard): "区域截图 · 复制到剪贴板"
        case .regionSelection(.screenshotToFile): "区域截图 · 保存文件"
        case .regionSelection(.ocrToClipboard): "OCR 识别"
        case .regionSelection(.recording): "选择录制区域"
        case .panorama: "全景截图"
        case .demoType: "DemoType"
        case .timer: "休息倒计时"
        }
    }

    nonisolated private static func toolText(_ tool: AnnotationTool) -> String {
        switch tool {
        case .pen: "画笔"
        case .line: "直线"
        case .rectangle: "矩形"
        case .ellipse: "椭圆"
        case .arrow: "箭头"
        case .text: "文字"
        case .highlighter: "高亮"
        case .blur: "模糊"
        case .redact: "遮挡"
        case .numberedCallout: "编号标记"
        }
    }

    nonisolated private static func colorText(_ color: AnnotationColor) -> String {
        switch color {
        case .red: "红色"
        case .green: "绿色"
        case .blue: "蓝色"
        case .yellow: "黄色"
        case .orange: "橙色"
        case .pink: "粉色"
        case .white: "白色"
        case .black: "黑色"
        }
    }
}
