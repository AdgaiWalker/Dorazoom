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

enum LiveZoomGlobalTrackingEvent: Equatable, Sendable {
    case pointerMovement
    case scrollWheel
}

struct LiveZoomInteractionPresentation: Equatable, Sendable {
    var mouseRouting: OverlayMouseRouting
    var systemCursor: SystemCursorVisibility
    var mouseTracking: LiveMouseTracking
    var globalTrackingEvents: [LiveZoomGlobalTrackingEvent]
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
                mouseTracking: .global,
                globalTrackingEvents: [.pointerMovement, .scrollWheel]
            )
        }

        return LiveZoomInteractionPresentation(
            mouseRouting: .captureInOverlay,
            systemCursor: .hidden,
            mouseTracking: .none,
            globalTrackingEvents: []
        )
    }
}
