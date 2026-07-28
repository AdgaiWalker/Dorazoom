enum OverlayPointerVisual: Equatable, Sendable {
    case hidden
    case zoomCrosshair
    case penDot
}

enum OverlayPointerPresentation {
    static func visual(
        interactionMode: AppMode,
        isDrawingMode: Bool,
        isSelectingRegion: Bool,
        activeStrokeTool: AnnotationTool?
    ) -> OverlayPointerVisual {
        if isSelectingRegion {
            return .hidden
        }
        if isDrawingMode {
            return hidesPenDot(activeStrokeTool) ? .hidden : .penDot
        }
        switch interactionMode {
        case .staticZoom:
            return .zoomCrosshair
        default:
            return .hidden
        }
    }

    private static func hidesPenDot(_ tool: AnnotationTool?) -> Bool {
        switch tool {
        case .line, .arrow, .rectangle, .ellipse:
            return true
        default:
            return false
        }
    }
}
