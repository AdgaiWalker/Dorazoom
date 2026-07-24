import AppKit

/// Snip：Ctrl+6 拖选区域 → 合成底图+全部可见标注 → 剪贴板（不落盘）+ 成功闪烁
final class SnipLayer {
    private var window: OverlayWindow?
    private(set) var isActive = false
    var onActiveChange: ((Bool) -> Void)?
    /// Esc 请求全清（由编排器关闭所有层）
    var onRequestClearAll: (() -> Void)?

    /// freeze: 底图；strokes/stamps: 矢量标注（不依赖 SC 是否拍到 overlay）
    func start(freeze: CGImage?, strokes: [Stroke], stamps: [TextStamp] = [], mode: String) {
        guard !isActive else { return }
        let w = OverlayWindow()
        let container = SnipContainerView(
            frame: NSRect(origin: .zero, size: w.frame.size),
            freeze: freeze, strokes: strokes, stamps: stamps)
        container.onComplete = { [weak self] selection in
            self?.finish(selection: selection, container: container)
        }
        container.onCancel = { [weak self] in
            // Esc：全清所有层（PRD 统一语义）
            if let clear = self?.onRequestClearAll {
                clear()
            } else {
                self?.cancel()
            }
        }
        w.contentView = container
        w.ignoresMouseEvents = false
        w.orderFrontRegardless()
        w.makeKey()
        w.makeFirstResponder(container)
        NSApp.activate(ignoringOtherApps: true)
        window = w
        isActive = true
        onActiveChange?(true)
        Telemetry.shared.log("snip.start", [
            "mode": mode,
            "withStrokes": "\(strokes.count)",
            "withStamps": "\(stamps.count)"
        ])
    }

    private func finish(selection: NSRect, container: SnipContainerView) {
        if let data = container.compositePNG(selection: selection) {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setData(data, forType: .png)
            Self.flashScreen()
            Telemetry.shared.log("snip.done",
                                 ["w": "\(Int(selection.width))",
                                  "h": "\(Int(selection.height))"])
        } else {
            Telemetry.shared.log("snip.cancel", ["reason": "tiny-selection"])
        }
        close()
    }

    private func cancel() {
        Telemetry.shared.log("snip.cancel", ["reason": "esc"])
        close()
    }

    /// 编排器全清时调用（避免递归进 onRequestClearAll）
    func cancelFromOutside() {
        guard isActive else { return }
        Telemetry.shared.log("snip.cancel", ["reason": "clear.all"])
        close()
    }

    private func close() {
        window?.orderOut(nil)
        window = nil
        isActive = false
        onActiveChange?(false)
    }

    /// 成功微反馈：全屏白闪
    private static func flashScreen() {
        guard let screen = NSScreen.main else { return }
        let w = NSWindow(contentRect: screen.frame, styleMask: .borderless,
                         backing: .buffered, defer: false)
        w.isOpaque = false
        w.backgroundColor = NSColor.white.withAlphaComponent(0.5)
        w.hasShadow = false
        w.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        w.sharingType = .readWrite
        w.ignoresMouseEvents = true
        w.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            w.animator().alphaValue = 0
        }, completionHandler: { w.orderOut(nil) })
    }
}

/// Snip 交互容器：预览（底图+标注）+ 暗化选区层；hitTest 拦截全部输入
final class SnipContainerView: NSView {
    private let preview: CanvasView
    private let dim = SnipDimView()
    private var dragStart: NSPoint?
    private var selection: NSRect = .zero { didSet { dim.selection = selection } }
    var onComplete: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?

    init(frame f: NSRect, freeze: CGImage?, strokes: [Stroke], stamps: [TextStamp]) {
        preview = CanvasView(frame: f)
        super.init(frame: f)
        preview.frame = bounds
        preview.loadForPreview(freeze: freeze, strokes: strokes, stamps: stamps)
        dim.frame = bounds
        addSubview(preview)
        addSubview(dim)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { self }

    override func mouseDown(with event: NSEvent) {
        dragStart = convert(event.locationInWindow, from: nil)
        selection = .zero
    }

    override func mouseDragged(with event: NSEvent) {
        guard let s = dragStart else { return }
        let p = convert(event.locationInWindow, from: nil)
        selection = NSRect(x: min(s.x, p.x), y: min(s.y, p.y),
                           width: abs(p.x - s.x), height: abs(p.y - s.y))
    }

    override func mouseUp(with event: NSEvent) {
        mouseDragged(with: event)
        dragStart = nil
        onComplete?(selection)
    }

    override func keyDown(with event: NSEvent) {
        // 本地 Esc 也会走到 clearAll（经 onCancel）；全局 Esc 是主路径
        if event.keyCode == 53 { onCancel?() }
    }

    /// 离屏渲染选区：按 backingScale 出图，保证 Retina 清晰
    func compositePNG(selection: NSRect) -> Data? {
        let minEdge = InkConstants.snipMinEdge
        guard selection.width >= minEdge, selection.height >= minEdge else { return nil }
        guard let rep = ImageDraw.bitmapRep(for: preview, rect: selection) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        if let ctx = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = ctx
            // 把选区原点平移到 (0,0)
            let transform = NSAffineTransform()
            transform.translateX(by: -selection.minX, yBy: -selection.minY)
            transform.concat()
            preview.draw(selection)
        }
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }
}

/// 暗化 + 选区挖洞 + 白框 + 尺寸标签
final class SnipDimView: NSView {
    var selection: NSRect = .zero { didSet { needsDisplay = true } }
    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.35).cgColor)
        ctx.fill(bounds)
        guard selection.width > 0, selection.height > 0 else { return }
        ctx.setBlendMode(.clear)
        ctx.fill(selection)
        ctx.setBlendMode(.normal)

        NSColor.white.setStroke()
        let border = NSBezierPath(rect: selection.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1
        border.stroke()

        let label = "\(Int(selection.width)) × \(Int(selection.height))" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.7)
        ]
        let size = label.size(withAttributes: attrs)
        var ly = selection.maxY + 6
        if ly + size.height > bounds.maxY - 4 { ly = selection.maxY - size.height - 6 }
        label.draw(at: NSPoint(x: selection.minX, y: ly), withAttributes: attrs)
    }
}
