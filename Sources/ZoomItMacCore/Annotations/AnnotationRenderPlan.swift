import CoreGraphics

enum AnnotationRenderKind: Equatable, Sendable {
    case freehand
    case line
    case rectangleOutline
    case rectangleFill
    case ellipseOutline
    case ellipseFill
    case arrow
    case highlightFreehand
    case text
}

struct AnnotationRenderOperation: Equatable, Sendable {
    var kind: AnnotationRenderKind
    var points: [CGPoint]
    var style: AnnotationStyle
    var text: String
    var fontSize: CGFloat
    var fontName: String
    var rightAligned: Bool

    var isHighlight: Bool {
        switch kind {
        case .highlightFreehand, .rectangleFill, .ellipseFill:
            return true
        default:
            return false
        }
    }
}

enum AnnotationRenderPlan {
    static func operations(for annotations: [Annotation]) -> [AnnotationRenderOperation] {
        let highlights = annotations.filter(isHighlight)
        let solids = annotations.filter { !isHighlight($0) }
        return (highlights + solids).compactMap(operation(for:))
    }

    static func isHighlight(_ annotation: Annotation) -> Bool {
        guard annotation.tool != .text else { return false }
        return annotation.tool == .highlighter || annotation.style.alpha < 1
    }

    private static func operation(for annotation: Annotation) -> AnnotationRenderOperation? {
        guard !annotation.points.isEmpty else { return nil }

        return AnnotationRenderOperation(
            kind: kind(for: annotation),
            points: annotation.points,
            style: normalizedStyle(for: annotation),
            text: annotation.text,
            fontSize: annotation.fontSize,
            fontName: annotation.fontName,
            rightAligned: annotation.rightAligned
        )
    }

    private static func kind(for annotation: Annotation) -> AnnotationRenderKind {
        let highlight = isHighlight(annotation)
        switch annotation.tool {
        case .pen:
            return highlight ? .highlightFreehand : .freehand
        case .highlighter:
            return .highlightFreehand
        case .line:
            return .line
        case .arrow:
            return .arrow
        case .rectangle:
            return highlight ? .rectangleFill : .rectangleOutline
        case .ellipse:
            return highlight ? .ellipseFill : .ellipseOutline
        case .text:
            return .text
        }
    }

    private static func normalizedStyle(for annotation: Annotation) -> AnnotationStyle {
        guard isHighlight(annotation) else { return annotation.style }
        return AnnotationStyle(
            color: annotation.style.color,
            rootWidth: annotation.style.rootWidth,
            alpha: AnnotationStyle.highlightAlpha
        )
    }
}
