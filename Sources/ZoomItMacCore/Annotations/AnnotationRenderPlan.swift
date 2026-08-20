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
    case blurFreehand
    case redactionFill
    case numberedCallout
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
    var calloutNumber: Int?

    var isHighlight: Bool {
        switch kind {
        case .highlightFreehand, .rectangleFill, .ellipseFill:
            return true
        default:
            return false
        }
    }

    var isPrivacy: Bool {
        switch kind {
        case .blurFreehand, .redactionFill:
            return true
        default:
            return false
        }
    }
}

enum AnnotationRenderPlan {
    static func operations(for annotations: [Annotation]) -> [AnnotationRenderOperation] {
        let highlights = annotations.filter(isHighlight)
        let privacy = annotations.filter(isPrivacy)
        let solids = annotations.filter { !isHighlight($0) && !isPrivacy($0) }
        return (highlights + solids + privacy).compactMap(operation(for:))
    }

    static func isHighlight(_ annotation: Annotation) -> Bool {
        guard annotation.tool != .text, !isPrivacy(annotation) else { return false }
        return annotation.tool == .highlighter || annotation.style.alpha < 1
    }

    static func isPrivacy(_ annotation: Annotation) -> Bool {
        annotation.tool == .blur || annotation.tool == .redact
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
            rightAligned: annotation.rightAligned,
            calloutNumber: annotation.calloutNumber
        )
    }

    private static func kind(for annotation: Annotation) -> AnnotationRenderKind {
        let highlight = isHighlight(annotation)
        switch annotation.tool {
        case .pen:
            return highlight ? .highlightFreehand : .freehand
        case .highlighter:
            return .highlightFreehand
        case .blur:
            return .blurFreehand
        case .redact:
            return .redactionFill
        case .numberedCallout:
            return .numberedCallout
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
        if annotation.tool == .redact {
            return AnnotationStyle(
                color: annotation.style.color,
                rootWidth: annotation.style.rootWidth,
                alpha: 1
            )
        }
        guard isHighlight(annotation) else { return annotation.style }
        return AnnotationStyle(
            color: annotation.style.color,
            rootWidth: annotation.style.rootWidth,
            alpha: AnnotationStyle.highlightAlpha
        )
    }
}
