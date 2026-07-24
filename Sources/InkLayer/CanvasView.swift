import AppKit

/// 圈画画布：冻结底图 + 全部笔画的渲染与鼠标键盘输入
final class CanvasView: NSView {
    var freezeImage: CGImage? { didSet { needsDisplay = true } }
    private(set) var strokes: [Stroke] = []
    private var inking: Stroke?

    var inkColor: NSColor = InkPalette.defaultColor { didSet { needsDisplay = true; refreshCursor() } }
    var inkWidth: CGFloat = InkConstants.defaultInkWidth { didSet { needsDisplay = true; refreshCursor() } }
    var showBadge = false { didSet { needsDisplay = true } }

    var onStrokeCommit: ((Stroke) -> Void)?
    var onUndo: (() -> Void)?
    var onEscape: (() -> Void)?
    var onColorKey: ((String) -> Void)?
    var onWidthChange: ((CGFloat) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    // MARK: - 画笔光标

    private lazy var penCursor: NSCursor = PenCursor.make(color: inkColor, width: inkWidth)

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: penCursor)
    }

    private func refreshCursor() {
        penCursor = PenCursor.make(color: inkColor, width: inkWidth)
        window?.invalidateCursorRects(for: self)
    }

    /// 画笔光标（ZoomIt 风格）：十字准星 + 中心实心圆点
    /// 圆点直径 = 笔宽，颜色 = 笔色；白色描边保证深底可见
    private enum PenCursor {
        static func make(color: NSColor, width: CGFloat) -> NSCursor {
            let dot = min(max(width, 3), 14)      // 实心圆点直径 = 笔宽
            let line: CGFloat = 2                 // 十字线宽
            let arm: CGFloat = 9                  // 十字臂长（圆点边缘到线端）
            let half = dot / 2 + arm + 2
            let d = half * 2
            let img = NSImage(size: NSSize(width: d, height: d), flipped: false) { rect in
                let c = rect.width / 2
                let span = NSRect(x: 0, y: 0, width: d, height: d).insetBy(dx: 2, dy: 2)
                // 1. 十字白描边
                NSColor.white.withAlphaComponent(0.9).setStroke()
                let crossOutline = NSBezierPath()
                crossOutline.lineWidth = line + 2
                crossOutline.move(to: NSPoint(x: span.minX, y: c))
                crossOutline.line(to: NSPoint(x: span.maxX, y: c))
                crossOutline.move(to: NSPoint(x: c, y: span.minY))
                crossOutline.line(to: NSPoint(x: c, y: span.maxY))
                crossOutline.stroke()
                // 2. 十字彩线
                color.setStroke()
                let cross = NSBezierPath()
                cross.lineWidth = line
                cross.move(to: NSPoint(x: span.minX, y: c))
                cross.line(to: NSPoint(x: span.maxX, y: c))
                cross.move(to: NSPoint(x: c, y: span.minY))
                cross.line(to: NSPoint(x: c, y: span.maxY))
                cross.stroke()
                // 3. 圆点白描边 + 4. 实心彩点（直径 = 笔宽）
                NSColor.white.withAlphaComponent(0.9).setFill()
                NSBezierPath(ovalIn: NSRect(x: c - dot / 2 - 1, y: c - dot / 2 - 1,
                                            width: dot + 2, height: dot + 2)).fill()
                color.setFill()
                NSBezierPath(ovalIn: NSRect(x: c - dot / 2, y: c - dot / 2,
                                            width: dot, height: dot)).fill()
                return true
            }
            return NSCursor(image: img, hotSpot: NSPoint(x: d / 2, y: d / 2))
        }
    }

    // MARK: - 渲染

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 统一经 ImageDraw：避免 CG 顶左 vs AppKit 底左翻转
        if let img = freezeImage { ImageDraw.draw(img, in: bounds) }
        for s in strokes { render(s, in: ctx) }
        if let c = inking { render(c, in: ctx) }
        for stamp in overlayStamps { TypeTypography.draw(stamp) }
        if showBadge { drawBadge() }
    }

    private func render(_ s: Stroke, in ctx: CGContext) {
        ctx.setStrokeColor(s.color.cgColor)
        ctx.setFillColor(s.color.cgColor)
        ctx.setLineWidth(s.width)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        guard let first = s.points.first else { return }
        if s.points.count == 1 { // 单击成点
            ctx.fillEllipse(in: CGRect(x: first.x - s.width / 2,
                                       y: first.y - s.width / 2,
                                       width: s.width, height: s.width))
            return
        }
        ctx.beginPath()
        ctx.move(to: first)
        for p in s.points.dropFirst() { ctx.addLine(to: p) }
        ctx.strokePath()
    }

    /// 角落常驻标记：当前色圆点 + 层名 + 笔宽
    private func drawBadge() {
        let badge = NSRect(x: bounds.maxX - 160, y: 20, width: 140, height: 32)
        NSColor.black.withAlphaComponent(0.55).setFill()
        NSBezierPath(roundedRect: badge, xRadius: 8, yRadius: 8).fill()

        inkColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: badge.minX + 12, y: badge.minY + 8,
                                    width: 16, height: 16)).fill()

        let label = "圈 · \(Int(inkWidth))px" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        label.draw(at: NSPoint(x: badge.minX + 36, y: badge.minY + 8),
                   withAttributes: attrs)
    }

    // MARK: - 鼠标

    override func mouseDown(with event: NSEvent) {
        inking = Stroke(points: [convert(event.locationInWindow, from: nil)],
                        color: inkColor, width: inkWidth)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        inking?.points.append(convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        inking?.points.append(convert(event.locationInWindow, from: nil))
        if let s = inking {
            strokes.append(s)
            onStrokeCommit?(s)
        }
        inking = nil
        needsDisplay = true
    }

    // MARK: - 键盘

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onEscape?(); return } // Esc
        if event.modifierFlags.contains(.control),
           event.charactersIgnoringModifiers?.lowercased() == "z" {
            onUndo?(); return
        }
        if let chars = event.charactersIgnoringModifiers?.lowercased(),
           let ch = chars.first, chars.count == 1, InkPalette.keys.contains(ch) {
            onColorKey?(String(ch)); return
        }
        super.keyDown(with: event)
    }

    // MARK: - 滚轮

    override func scrollWheel(with event: NSEvent) {
        guard event.modifierFlags.contains(.control) else { return }
        let delta: CGFloat = event.deltaY > 0 ? 1 : -1
        inkWidth = min(InkConstants.inkWidthRange.upperBound,
                       max(InkConstants.inkWidthRange.lowerBound, inkWidth + delta))
        onWidthChange?(inkWidth)
    }

    // MARK: - 笔画操作

    @discardableResult
    func undoLast() -> Bool {
        guard !strokes.isEmpty else { return false }
        strokes.removeLast()
        needsDisplay = true
        return true
    }

    func clearAll() {
        strokes.removeAll()
        inking = nil
        needsDisplay = true
    }

    /// Snip 预览复用：只读装载底图与笔画（输入由容器拦截，本视图不响应）
    func loadForPreview(freeze: CGImage?, strokes: [Stroke], stamps: [TextStamp] = []) {
        self.freezeImage = freeze
        self.strokes = strokes
        self.overlayStamps = stamps
        self.showBadge = false
        needsDisplay = true
    }

    /// Snip 合成用的烙字（不参与交互）
    var overlayStamps: [TextStamp] = [] { didSet { needsDisplay = true } }
}
