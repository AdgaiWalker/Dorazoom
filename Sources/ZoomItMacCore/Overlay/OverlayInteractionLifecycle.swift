import CoreGraphics

enum OverlayInteractionResource: Equatable, Hashable, Sendable {
    case overlayWindow
    case hiddenSystemCursor
    case zoomPointer
    case penPointer
    case toolPointer
}

struct OverlayInteractionLifecycle: Equatable, Sendable {
    private(set) var isActive: Bool
    private let mode: AppMode
    private let pointerVisual: OverlayPointerVisual

    static func active(
        mode: AppMode,
        isDrawingMode: Bool,
        isSelectingRegion: Bool,
        activeStrokeTool: AnnotationTool?,
        currentTool: AnnotationTool,
        style: AnnotationStyle,
        canvas: CanvasBackground,
        environment: FeedbackPresentationEnvironment
    ) -> OverlayInteractionLifecycle {
        OverlayInteractionLifecycle(
            isActive: true,
            mode: mode,
            pointerVisual: OverlayPointerPresentation.visual(
                interactionMode: mode,
                isDrawingMode: isDrawingMode,
                isSelectingRegion: isSelectingRegion,
                activeStrokeTool: activeStrokeTool,
                currentTool: currentTool,
                style: style,
                canvas: canvas,
                environment: environment
            )
        )
    }

    var activeResources: [OverlayInteractionResource] {
        guard isActive else { return [] }
        var resources: [OverlayInteractionResource] = [.overlayWindow, .hiddenSystemCursor]
        switch pointerVisual {
        case .magnifier:
            resources.append(.zoomPointer)
        case .penRing, .highlighterNib:
            resources.append(.penPointer)
        case .toolCrosshair, .textCaret:
            resources.append(.toolPointer)
        case .hidden:
            break
        }
        return resources
    }

    mutating func close() {
        isActive = false
    }
}
