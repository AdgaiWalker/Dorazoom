import CoreGraphics

enum OverlayInteractionResource: Equatable, Hashable, Sendable {
    case overlayWindow
    case hiddenSystemCursor
    case zoomPointer
    case penPointer
    case zoomHUD
}

struct OverlayInteractionLifecycle: Equatable, Sendable {
    private(set) var isActive: Bool
    private let mode: AppMode
    private let pointerVisual: OverlayPointerVisual
    private let hud: OverlayHUD?

    static func active(
        mode: AppMode,
        isDrawingMode: Bool,
        isSelectingRegion: Bool,
        activeStrokeTool: AnnotationTool?,
        zoomFactor: CGFloat,
        container: CGRect
    ) -> OverlayInteractionLifecycle {
        OverlayInteractionLifecycle(
            isActive: true,
            mode: mode,
            pointerVisual: OverlayPointerPresentation.visual(
                interactionMode: mode,
                isDrawingMode: isDrawingMode,
                isSelectingRegion: isSelectingRegion,
                activeStrokeTool: activeStrokeTool
            ),
            hud: OverlayHUDPresentation.presentation(
                interactionMode: mode,
                zoomFactor: zoomFactor,
                container: container
            )
        )
    }

    var activeResources: [OverlayInteractionResource] {
        guard isActive else { return [] }
        var resources: [OverlayInteractionResource] = [.overlayWindow, .hiddenSystemCursor]
        switch pointerVisual {
        case .zoomCrosshair:
            resources.append(.zoomPointer)
        case .penDot:
            resources.append(.penPointer)
        case .hidden:
            break
        }
        if hud != nil {
            resources.append(.zoomHUD)
        }
        return resources
    }

    mutating func close() {
        isActive = false
    }
}
