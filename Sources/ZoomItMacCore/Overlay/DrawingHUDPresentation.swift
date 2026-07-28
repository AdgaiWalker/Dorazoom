import CoreGraphics

enum DrawingHUDPresentation {
    static func presentation(
        isDrawingMode: Bool,
        tool: AnnotationTool,
        style: AnnotationStyle,
        container: CGRect
    ) -> OverlayHUD? {
        guard isDrawingMode else { return nil }

        let width = Int(style.rootWidth.rounded())
        let text = "Draw \(tool.displayName) · \(style.color.displayName) · \(width)px"
        let estimatedSize = CGSize(width: CGFloat(text.count) * 8 + 20, height: 24)
        let size = CGSize(
            width: min(estimatedSize.width, max(1, container.width - 12)),
            height: min(estimatedSize.height, max(1, container.height - 6))
        )
        let origin = CGPoint(
            x: OverlayHUDPresentation.clamp(container.minX + 12, lower: container.minX, upper: container.maxX - size.width),
            y: OverlayHUDPresentation.clamp(container.minY + 12, lower: container.minY, upper: container.maxY - size.height)
        )
        return OverlayHUD(text: text, frame: CGRect(origin: origin, size: size))
    }
}

private extension AnnotationTool {
    var displayName: String {
        switch self {
        case .pen: "Pen"
        case .line: "Line"
        case .rectangle: "Rectangle"
        case .ellipse: "Ellipse"
        case .arrow: "Arrow"
        case .text: "Text"
        case .highlighter: "Highlighter"
        }
    }
}
