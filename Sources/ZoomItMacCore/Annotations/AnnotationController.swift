import AppKit

@MainActor
final class AnnotationController {
    var currentTool: AnnotationTool = .pen
    var currentStyle: AnnotationStyle = .default
    private(set) var canvasBackground: CanvasBackground = .transparent

    // Typing mode state, mirroring ZoomIt's font scaling and justification.
    static let defaultFontSize: CGFloat = 20
    var typingFontSize: CGFloat = AnnotationController.defaultFontSize
    var typingRightAligned: Bool = false
    /// PostScript/font family name used for typing mode. Empty means the
    /// system font, matching the default appearance.
    var typingFontName: String = ""

    private var annotations: [Annotation] = []
    private var inProgress: Annotation?
    private var textAnnotationIndex: Int?
    private var insertionPoint: CGPoint = CGPoint(x: 120, y: 120)
    private var nextCalloutNumber = 1
    var isTypingDraftPresentedByNativeEditor = false

    var annotationSnapshot: [Annotation] {
        annotations
    }

    var inProgressSnapshot: Annotation? {
        inProgress
    }

    var renderPlanSnapshot: [AnnotationRenderOperation] {
        AnnotationRenderPlan.operations(for: allAnnotationsForRendering)
    }

    var privacyRenderPlanSnapshot: [AnnotationRenderOperation] {
        renderPlanSnapshot.filter(\.isPrivacy)
    }

    /// Builds the typing-mode font for the given name and size, falling back to
    /// the semibold system font when no custom font is configured or available.
    static func typingFont(named name: String, size: CGFloat) -> NSFont {
        if !name.isEmpty, let font = NSFont(name: name, size: size) {
            return font
        }
        return NSFont.systemFont(ofSize: size, weight: .regular)
    }

    func reset() {
        annotations.removeAll()
        inProgress = nil
        textAnnotationIndex = nil
        insertionPoint = CGPoint(x: 120, y: 120)
        currentTool = .pen
        currentStyle = .default
        canvasBackground = .transparent
        typingFontSize = AnnotationController.defaultFontSize
        typingRightAligned = false
        isTypingDraftPresentedByNativeEditor = false
        nextCalloutNumber = 1
    }

    func setCanvasBackground(_ background: CanvasBackground) {
        canvasBackground = background
    }

    func setInsertionPoint(_ point: CGPoint) {
        insertionPoint = point
        textAnnotationIndex = nil
    }

    /// Starts a fresh typing session, matching ZoomIt's behaviour when entering
    /// type mode (T enters left-justified, Shift+T right-justified).
    func beginTypingSession(rightAligned: Bool) {
        typingRightAligned = rightAligned
        textAnnotationIndex = nil
    }

    func increaseFontSize() {
        setTypingFontSize(typingFontSize * 1.1)
    }

    func decreaseFontSize() {
        setTypingFontSize(typingFontSize / 1.1)
    }

    private func setTypingFontSize(_ size: CGFloat) {
        typingFontSize = min(max(size, 10), 600)
        // Live-resize the text currently being typed, like ZoomIt.
        if let textAnnotationIndex, annotations.indices.contains(textAnnotationIndex),
           annotations[textAnnotationIndex].tool == .text {
            annotations[textAnnotationIndex].fontSize = typingFontSize
        }
    }

    /// Whether the typing caret is locked in place. ZoomIt lets the caret
    /// follow the mouse until the first character is typed, then locks it.
    var isTypingLocked: Bool {
        if let textAnnotationIndex, annotations.indices.contains(textAnnotationIndex),
           annotations[textAnnotationIndex].tool == .text {
            return true
        }
        return false
    }

    /// Returns the caret origin (top) and height in content space for the text
    /// currently being typed, or the insertion point when no text exists yet.
    func typingCaret() -> (origin: CGPoint, height: CGFloat)? {
        let activeAnnotation: Annotation?
        if let textAnnotationIndex, annotations.indices.contains(textAnnotationIndex),
           annotations[textAnnotationIndex].tool == .text {
            activeAnnotation = annotations[textAnnotationIndex]
        } else {
            activeAnnotation = nil
        }

        let fontSize = activeAnnotation?.fontSize ?? typingFontSize
        let fontName = activeAnnotation?.fontName ?? typingFontName
        let font = Self.typingFont(named: fontName, size: fontSize)
        let lineHeight = font.ascender - font.descender + font.leading

        guard let annotation = activeAnnotation, let point = annotation.points.first else {
            return (insertionPoint, lineHeight)
        }

        let lines = annotation.text.components(separatedBy: "\n")
        let lastLine = lines.last ?? ""
        let lastWidth = NSString(string: lastLine).size(withAttributes: [.font: font]).width
        let y = point.y + CGFloat(lines.count - 1) * lineHeight
        // Right-justified text grows to the left, so the caret stays at the
        // insertion point's x; left-justified text trails the last line.
        let x = annotation.rightAligned ? point.x : point.x + lastWidth
        return (CGPoint(x: x, y: y), lineHeight)
    }

    func begin(at point: CGPoint) {
        inProgress = makeAnnotation(tool: currentTool, point: point)
    }

    func begin(at point: CGPoint, tool: AnnotationTool) {
        inProgress = makeAnnotation(tool: tool, point: point)
    }

    func update(at point: CGPoint) {
        guard let tool = inProgress?.tool else { return }

        if tool == .pen || tool == .highlighter || tool == .blur {
            inProgress?.points.append(point)
        } else if inProgress?.points.count == 1 {
            inProgress?.points.append(point)
        } else {
            inProgress?.points[1] = point
        }
    }

    func end(at point: CGPoint) {
        update(at: point)
        guard let annotation = inProgress else { return }
        annotations.append(annotation)
        if annotation.tool == .numberedCallout {
            nextCalloutNumber += 1
        }
        inProgress = nil
    }

    func undo() {
        _ = annotations.popLast()
        textAnnotationIndex = nil
        nextCalloutNumber = (annotations.compactMap(\.calloutNumber).max() ?? 0) + 1
    }

    func clear() {
        annotations.removeAll()
        inProgress = nil
        textAnnotationIndex = nil
        nextCalloutNumber = 1
    }

    /// Replaces the native text editor's current draft. Marked-text updates
    /// replace the same annotation instead of being appended as raw key events.
    func replaceTypingText(_ text: String) {
        if let textAnnotationIndex,
           annotations.indices.contains(textAnnotationIndex),
           annotations[textAnnotationIndex].tool == .text {
            if text.isEmpty {
                annotations.remove(at: textAnnotationIndex)
                self.textAnnotationIndex = nil
            } else {
                annotations[textAnnotationIndex].text = text
            }
            return
        }

        guard !text.isEmpty else { return }
        let annotation = Annotation(
            tool: .text,
            points: [insertionPoint],
            style: currentStyle,
            text: text,
            fontSize: typingFontSize,
            fontName: typingFontName,
            rightAligned: typingRightAligned
        )
        annotations.append(annotation)
        textAnnotationIndex = annotations.indices.last
    }

    private var allAnnotationsForRendering: [Annotation] {
        let committedAnnotations: [Annotation]
        if isTypingDraftPresentedByNativeEditor,
           let textAnnotationIndex,
           annotations.indices.contains(textAnnotationIndex) {
            committedAnnotations = annotations.enumerated().compactMap { index, annotation in
                index == textAnnotationIndex ? nil : annotation
            }
        } else {
            committedAnnotations = annotations
        }
        return committedAnnotations + Array(inProgress.map { [$0] } ?? [])
    }

    private func makeAnnotation(tool: AnnotationTool, point: CGPoint) -> Annotation {
        Annotation(
            tool: tool,
            points: [point],
            style: currentStyle,
            calloutNumber: tool == .numberedCallout ? nextCalloutNumber : nil
        )
    }

    func render(in context: CGContext, bounds: CGRect, includesPrivacyPreview: Bool) {
        let operations = renderPlanSnapshot.filter { includesPrivacyPreview || !$0.isPrivacy }
        let highlights = operations.filter(\.isHighlight)
        let solids = operations.filter { !$0.isHighlight }

        // Composite every highlight into a single transparency layer drawn at
        // full opacity, then blend the whole layer once at the highlight alpha.
        // This way overlapping highlight strokes (within or across annotations)
        // paint the same opaque pixels and never accumulate, so going over a
        // highlight again doesn't darken it. Highlights sit beneath solid ink.
        if !highlights.isEmpty {
            context.saveGState()
            context.setAlpha(AnnotationStyle.highlightAlpha)
            context.beginTransparencyLayer(auxiliaryInfo: nil)
            for operation in highlights {
                render(operation, in: context, forceOpaque: true)
            }
            context.endTransparencyLayer()
            context.restoreGState()
        }

        for operation in solids {
            render(operation, in: context)
        }
    }

    private func render(_ operation: AnnotationRenderOperation, in context: CGContext, forceOpaque: Bool = false) {
        guard let first = operation.points.first else { return }

        // Inside the highlight transparency layer everything is drawn opaque so
        // overlaps don't accumulate; the layer applies the highlight alpha once.
        let drawAlpha: CGFloat = forceOpaque ? 1 : operation.style.alpha
        let color = operation.style.color.nsColor.withAlphaComponent(drawAlpha)
        context.setStrokeColor(color.cgColor)
        context.setFillColor(color.cgColor)
        context.setLineWidth(operation.style.rootWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch operation.kind {
        case .freehand, .highlightFreehand, .blurFreehand:
            let path = CGMutablePath()
            path.move(to: first)
            for point in operation.points.dropFirst() {
                path.addLine(to: point)
            }
            if operation.kind == .blurFreehand {
                context.setStrokeColor(NSColor.systemGray.withAlphaComponent(0.55).cgColor)
            }
            context.addPath(path)
            context.strokePath()
        case .line, .arrow:
            guard let last = operation.points.last else { return }
            // Only draw the arrowhead once the shaft is long enough to make the
            // direction unambiguous; until then show a plain line without a tip.
            let shaftLength = hypot(last.x - first.x, last.y - first.y)
            let headLength = operation.style.rootWidth * 3.5
            if operation.kind == .arrow && operation.points.count >= 2 && shaftLength >= headLength {
                // ZoomIt anchors the arrowhead at the start point (where the
                // drag began) and trails the shaft out to the current cursor.
                drawArrow(tail: last, tip: first, width: operation.style.rootWidth, color: color, in: context)
            } else {
                context.move(to: first)
                context.addLine(to: last)
                context.strokePath()
            }
        case .rectangleOutline, .rectangleFill:
            guard let last = operation.points.last else { return }
            let rect = CGRect(origin: first, size: CGSize(width: last.x - first.x, height: last.y - first.y)).standardized
            // In highlight mode shapes are filled so they read as a highlight
            // swatch; otherwise they're outlined.
            if operation.kind == .rectangleFill {
                context.fill(rect)
            } else {
                context.stroke(rect)
            }
        case .ellipseOutline, .ellipseFill:
            guard let last = operation.points.last else { return }
            let rect = CGRect(origin: first, size: CGSize(width: last.x - first.x, height: last.y - first.y)).standardized
            if operation.kind == .ellipseFill {
                context.fillEllipse(in: rect)
            } else {
                context.strokeEllipse(in: rect)
            }
        case .redactionFill:
            guard let last = operation.points.last else { return }
            let rect = CGRect(
                origin: first,
                size: CGSize(width: last.x - first.x, height: last.y - first.y)
            ).standardized
            context.setAlpha(1)
            context.fill(rect)
        case .numberedCallout:
            drawNumberedCallout(operation, in: context)
        case .text:
            drawText(operation)
        }
    }

    private func drawText(_ operation: AnnotationRenderOperation) {
        guard let point = operation.points.first else { return }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = operation.rightAligned ? .right : .left
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Self.typingFont(named: operation.fontName, size: operation.fontSize),
            .foregroundColor: operation.style.color.nsColor.withAlphaComponent(operation.style.alpha),
            .paragraphStyle: paragraph
        ]
        let string = NSString(string: operation.text)
        if operation.rightAligned {
            // Anchor the right edge of the text at the insertion point so the
            // text grows to the left as ZoomIt's right-justified mode does.
            let size = string.size(withAttributes: attributes)
            let rect = CGRect(x: point.x - size.width, y: point.y, width: size.width, height: size.height)
            string.draw(in: rect, withAttributes: attributes)
        } else {
            string.draw(at: point, withAttributes: attributes)
        }
    }

    private func drawNumberedCallout(_ operation: AnnotationRenderOperation, in context: CGContext) {
        guard let center = operation.points.last, let number = operation.calloutNumber else { return }
        let radius = max(12, operation.style.rootWidth * 2.4)
        let circle = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.saveGState()
        context.setAlpha(1)
        context.setFillColor(operation.style.color.nsColor.cgColor)
        context.fillEllipse(in: circle)
        context.restoreGState()

        let font = NSFont.monospacedDigitSystemFont(ofSize: radius, weight: .bold)
        let string = NSString(string: String(number))
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let size = string.size(withAttributes: attributes)
        let previousContext = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        defer { NSGraphicsContext.current = previousContext }
        string.draw(
            at: CGPoint(x: circle.midX - size.width / 2, y: circle.midY - size.height / 2),
            withAttributes: attributes
        )
    }

    private func drawArrow(tail: CGPoint, tip: CGPoint, width: CGFloat, color: NSColor, in context: CGContext) {
        let dx = tip.x - tail.x
        let dy = tip.y - tail.y
        let length = hypot(dx, dy)
        let ux: CGFloat = length > 0 ? dx / length : 1
        let uy: CGFloat = length > 0 ? dy / length : 0

        // Slightly larger than ZoomIt's head (penWidth * 2.5 / 1.5) for a more
        // visible arrowhead.
        let headLength = width * 3.5
        let headHalfWidth = width * 2.0

        // Base midpoint, backed off from the tip along the shaft.
        let baseX = tip.x - ux * headLength
        let baseY = tip.y - uy * headLength
        // Wings perpendicular to the shaft.
        let left = CGPoint(x: baseX - uy * headHalfWidth, y: baseY + ux * headHalfWidth)
        let right = CGPoint(x: baseX + uy * headHalfWidth, y: baseY - ux * headHalfWidth)
        // Indented base center for a concave (nicer) arrowhead.
        let mid = CGPoint(x: tip.x - ux * headLength / 2, y: tip.y - uy * headLength / 2)

        // Shaft runs from the tail to the indented base of the head.
        context.move(to: tail)
        context.addLine(to: mid)
        context.strokePath()

        // Filled arrowhead: tip -> left wing -> indented mid -> right wing.
        context.setFillColor(color.cgColor)
        context.beginPath()
        context.move(to: tip)
        context.addLine(to: left)
        context.addLine(to: mid)
        context.addLine(to: right)
        context.closePath()
        context.fillPath()
    }
}
