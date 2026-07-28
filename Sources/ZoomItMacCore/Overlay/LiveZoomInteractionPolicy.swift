enum OverlayMouseRouting: Equatable, Sendable {
    case passThroughToUnderlyingApp
    case captureInOverlay
}

enum SystemCursorVisibility: Equatable, Sendable {
    case visible
    case hidden
}

enum LiveMouseTracking: Equatable, Sendable {
    case global
    case none
}

struct LiveZoomInteractionPresentation: Equatable, Sendable {
    var mouseRouting: OverlayMouseRouting
    var systemCursor: SystemCursorVisibility
    var mouseTracking: LiveMouseTracking
}

enum LiveZoomInteractionPolicy {
    static func presentation(
        interactionMode: AppMode,
        isDrawingMode: Bool,
        isSelectingRegion: Bool
    ) -> LiveZoomInteractionPresentation {
        if interactionMode == .liveZoom && !isDrawingMode && !isSelectingRegion {
            return LiveZoomInteractionPresentation(
                mouseRouting: .passThroughToUnderlyingApp,
                systemCursor: .visible,
                mouseTracking: .global
            )
        }

        return LiveZoomInteractionPresentation(
            mouseRouting: .captureInOverlay,
            systemCursor: .hidden,
            mouseTracking: .none
        )
    }
}
