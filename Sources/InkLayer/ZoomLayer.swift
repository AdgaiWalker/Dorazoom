import AppKit

/// 轻量缩放：Ctrl+1 进入/退出。以进入时光标为中心，滚轮连续调倍率，拖移平移
final class ZoomLayer {
    private let window = OverlayWindow()
    private let view: ZoomView
    private var activation = ActivationLifecycle()
    var isActive: Bool { activation.isActive }
    var requiresDeactivation: Bool { activation.requiresDeactivation }

    /// Snip 排除用
    var windowRef: NSWindow { window }

    var onActiveChange: ((Bool) -> Void)?
    var onRequestClearAll: (() -> Void)?
    var onNeedPermission: (() -> Void)?

    init() {
        view = ZoomView(frame: NSRect(origin: .zero, size: window.frame.size))
        window.contentView = view
        view.onEscape = { [weak self] in self?.onRequestClearAll?() }
        view.onScaleChange = { scale in
            Telemetry.shared.log("zoom.scale", ["scale": String(format: "%.2f", scale)])
        }
    }

    func toggle() {
        if isActive {
            deactivate(trigger: "hotkey.ctrl1")
        } else {
            activate()
        }
        // 加载中再按：忽略，避免"放大→立刻关掉"
    }

    func escape() {
        guard requiresDeactivation else { return }
        deactivate(trigger: "esc")
    }

    private func activate() {
        guard let token = activation.beginLoading() else { return }
        let mouse = NSEvent.mouseLocation
        Task { [weak self] in
            let img = await FreezeCapture.grab()
            await MainActor.run { [weak self] in
                guard let self else { return }
                guard let img else {
                    guard self.activation.fail(token) else { return }
                    Telemetry.shared.log("zoom.denied")
                    self.onNeedPermission?()
                    return
                }
                guard self.activation.activate(token) else { return }
                self.show(image: img, focus: mouse)
            }
        }
    }

    @MainActor private func show(image: CGImage, focus: NSPoint) {
        let sf = window.frame
        let local = NSPoint(x: focus.x - sf.minX, y: focus.y - sf.minY)
        view.load(image: image, focus: local, scale: InkConstants.zoomDefaultScale)
        window.ignoresMouseEvents = false
        window.orderFrontRegardless()
        window.makeKey()
        window.makeFirstResponder(view)
        NSApp.activate(ignoringOtherApps: true)
        Telemetry.shared.log("layer.zoom.on",
                             ["scale": "\(InkConstants.zoomDefaultScale)"])
        onActiveChange?(true)
        maybeShowHint()
    }

    private func deactivate(trigger: String) {
        guard activation.deactivate() else { return }
        view.clear()
        window.ignoresMouseEvents = true
        window.orderOut(nil)
        Telemetry.shared.log("layer.zoom.off", ["trigger": trigger])
        onActiveChange?(false)
    }

    private func maybeShowHint() {
        let count = StateStore.bump("zoomOnCount")
        guard count <= InkConstants.hintShowLimit else { return }
        HintBar(text: "滚轮调倍率 · 拖移平移 · 再按 Ctrl+1 或 Esc 退出")
            .flash(in: view)
    }
}

/// 缩放视图：固定中心点缩放 + 拖移平移 + 滚轮调倍率
final class ZoomView: NSView {
    private var image: CGImage?
    private var scale: CGFloat = InkConstants.zoomDefaultScale
    /// 视图坐标中的缩放锚点（进入时的光标位置，不随鼠标移动改变）
    private var focusPoint: NSPoint = .zero
    /// 图像在视图中的偏移
    private var offset: CGPoint = .zero
    private var dragStart: NSPoint?
    private var offsetAtDragStart: CGPoint = .zero

    var onEscape: (() -> Void)?
    var onScaleChange: ((CGFloat) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    func load(image: CGImage, focus: NSPoint, scale: CGFloat) {
        self.image = image
        self.scale = scale
        self.focusPoint = focus
        recomputeOffsetKeepingFocus()
        needsDisplay = true
    }

    func clear() {
        image = nil
        offset = .zero
        needsDisplay = true
    }

    /// 以 focusPoint 为不动点，按当前 scale 重算 offset
    private func recomputeOffsetKeepingFocus() {
        guard let image else { return }
        let imgW = CGFloat(image.width)
        let imgH = CGFloat(image.height)
        let viewW = bounds.width
        let viewH = bounds.height
        guard viewW > 0, viewH > 0, imgW > 0, imgH > 0 else { return }

        let pixelScaleX = imgW / viewW
        let pixelScaleY = imgH / viewH
        let fx = focusPoint.x * pixelScaleX
        let fy = (viewH - focusPoint.y) * pixelScaleY

        let drawnW = viewW * scale
        let drawnH = viewH * scale
        let focusInDrawnX = (fx / imgW) * drawnW
        let focusInDrawnY = drawnH - (fy / imgH) * drawnH
        offset = NSPoint(x: focusPoint.x - focusInDrawnX,
                         y: focusPoint.y - focusInDrawnY)
    }

    /// 滚轮调倍率时：以当前视图中心下的图像点为临时锚点，避免跳动
    private func adjustScale(by delta: CGFloat) {
        let old = scale
        let next = min(InkConstants.zoomScaleRange.upperBound,
                       max(InkConstants.zoomScaleRange.lowerBound, old + delta))
        guard abs(next - old) > 0.001 else { return }

        // 以视图中心为缩放锚点（倍率变化时画面稳定）
        let anchor = NSPoint(x: bounds.midX, y: bounds.midY)
        // 锚点在图像归一化坐标中的位置
        if let image, bounds.width > 0, bounds.height > 0 {
            let drawnW = bounds.width * old
            let drawnH = bounds.height * old
            let nx = (anchor.x - offset.x) / drawnW
            let ny = (anchor.y - offset.y) / drawnH
            scale = next
            let newW = bounds.width * scale
            let newH = bounds.height * scale
            offset = NSPoint(x: anchor.x - nx * newW, y: anchor.y - ny * newH)
            // 同步更新 focus，便于后续 recompute
            focusPoint = anchor
            _ = image
        } else {
            scale = next
            recomputeOffsetKeepingFocus()
        }
        needsDisplay = true
        onScaleChange?(scale)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        bounds.fill()
        guard let image else { return }
        let drawn = NSRect(x: offset.x, y: offset.y,
                           width: bounds.width * scale,
                           height: bounds.height * scale)
        ImageDraw.draw(image, in: drawn)

        let badge = NSRect(x: bounds.maxX - 110, y: 20, width: 90, height: 32)
        NSColor.black.withAlphaComponent(0.55).setFill()
        NSBezierPath(roundedRect: badge, xRadius: 8, yRadius: 8).fill()
        let text = String(format: "×%.2g", scale) as NSString
        text.draw(at: NSPoint(x: badge.minX + 22, y: badge.minY + 8), withAttributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.white
        ])
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = convert(event.locationInWindow, from: nil)
        offsetAtDragStart = offset
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        let p = convert(event.locationInWindow, from: nil)
        offset = NSPoint(x: offsetAtDragStart.x + (p.x - start.x),
                         y: offsetAtDragStart.y + (p.y - start.y))
        // 拖移后焦点跟到新偏移下的视图中心语义由 anchor 在滚轮时刷新
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        dragStart = nil
    }

    override func scrollWheel(with event: NSEvent) {
        // 滚轮调倍率：向上放大、向下缩小（不跟鼠标移动中心）
        let step = InkConstants.zoomScaleStep
        let delta: CGFloat = event.scrollingDeltaY > 0 ? step : -step
        // 精确触控板：累积小增量
        if abs(event.scrollingDeltaY) < 1 {
            adjustScale(by: event.scrollingDeltaY > 0 ? step * 0.5 : -step * 0.5)
        } else {
            adjustScale(by: delta)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onEscape?(); return }
        // + / - 也可调倍率
        if event.charactersIgnoringModifiers == "=" || event.charactersIgnoringModifiers == "+" {
            adjustScale(by: InkConstants.zoomScaleStep); return
        }
        if event.charactersIgnoringModifiers == "-" {
            adjustScale(by: -InkConstants.zoomScaleStep); return
        }
        super.keyDown(with: event)
    }
}
