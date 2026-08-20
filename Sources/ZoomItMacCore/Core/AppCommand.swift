import CoreGraphics

enum AppCommand: Equatable {
    case activateStaticZoom
    case activateLiveZoom
    case activateDrawWithoutZoom
    case zoomIn
    case zoomOut
    case adjustZoomFromScroll(scrollingDeltaY: CGFloat, isPrecise: Bool)
    case toggleTyping(rightAligned: Bool)
    case increaseFontSize
    case decreaseFontSize
    case setTool(AnnotationTool)
    case setColor(AnnotationColor)
    case setHighlightColor(AnnotationColor)
    case setCanvas(CanvasBackground)
    case increasePenWidth
    case decreasePenWidth
    case undo
    case clear
    case snipRegion(save: Bool)
    case snipPreviousRegion
    case snipWindowAtPointer
    case snipOcr
    case startPanorama(save: Bool)
    case toggleRecording(region: Bool)
    case toggleRecordingPause
    case startDemoType
    case resetDemoType
    case toggleBreakTimer
    case exit
}
