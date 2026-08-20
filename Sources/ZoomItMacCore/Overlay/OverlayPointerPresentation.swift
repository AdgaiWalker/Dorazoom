import CoreGraphics

enum OverlayPointerVisual: Equatable, Sendable {
    case hidden
    case magnifier
    case penRing(color: AnnotationColor, diameter: CGFloat, highContrast: Bool)
    case highlighterNib(color: AnnotationColor, width: CGFloat, highContrast: Bool)
    case toolCrosshair(tool: AnnotationTool, color: AnnotationColor, highContrast: Bool)
    case textCaret(highContrast: Bool)
}

enum OverlayPointerPresentation {
    static func visual(
        interactionMode: AppMode,
        isDrawingMode: Bool,
        isSelectingRegion: Bool,
        activeStrokeTool: AnnotationTool?,
        currentTool: AnnotationTool,
        style: AnnotationStyle,
        canvas: CanvasBackground,
        environment: FeedbackPresentationEnvironment
    ) -> OverlayPointerVisual {
        if isSelectingRegion {
            return .hidden
        }
        if isDrawingMode {
            let tool = activeStrokeTool ?? currentTool
            let color = visibleColor(style.color, canvas: canvas)
            let highContrast = environment.increaseContrast || color != style.color
            switch tool {
            case .pen:
                return .penRing(color: color, diameter: style.rootWidth, highContrast: highContrast)
            case .highlighter:
                return .highlighterNib(color: color, width: style.rootWidth, highContrast: highContrast)
            case .line, .rectangle, .ellipse, .arrow, .blur, .redact, .numberedCallout:
                return .toolCrosshair(tool: tool, color: color, highContrast: highContrast)
            case .text:
                return .textCaret(highContrast: highContrast)
            }
        }
        switch interactionMode {
        case .staticZoom, .liveZoom:
            return .magnifier
        case .typing:
            return .textCaret(highContrast: environment.increaseContrast)
        default:
            return .hidden
        }
    }

    private static func visibleColor(
        _ color: AnnotationColor,
        canvas: CanvasBackground
    ) -> AnnotationColor {
        switch (canvas, color) {
        case (.blackboard, .black): .white
        case (.whiteboard, .white): .black
        default: color
        }
    }
}
