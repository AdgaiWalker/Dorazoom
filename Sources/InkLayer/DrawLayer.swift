import AppKit

/// 圈画层：Ctrl+2。有录屏权限 → 冻结态；无权限 → 活屏玻璃
final class DrawLayer {
    private let window = OverlayWindow()
    private let canvas: CanvasView
    private var activation = ActivationLifecycle()
    var isActive: Bool { activation.isActive }
    var requiresDeactivation: Bool { activation.requiresDeactivation }

    /// 活屏回魂代理指标：Esc 清场后窗口内重进圈画的间隔秒数
    var afterEscSeconds: (() -> TimeInterval?)?
    var onActiveChange: ((Bool, String) -> Void)?
    /// Esc 请求全清（由编排器关闭所有层）
    var onRequestClearAll: (() -> Void)?

    /// Snip 排除用
    var windowRef: NSWindow { window }
    /// Snip 复用：当前冻结底图与笔画（只读）
    var currentFreeze: CGImage? { canvas.freezeImage }
    var currentStrokes: [Stroke] { canvas.strokes }

    /// 编排器/Snip 关闭后夺回键盘焦点
    func regainFocus() {
        guard isActive else { return }
        window.makeKey()
        window.makeFirstResponder(canvas)
        window.invalidateCursorRects(for: canvas)
    }

    /// 编排器路由 Ctrl+Z
    func performUndo() {
        guard isActive else { return }
        if canvas.undoLast() { Telemetry.shared.log("draw.undo") }
    }

    /// 编排器路由换色
    func applyColorKey(_ key: String) {
        guard isActive, let color = InkPalette.color(forKey: key) else { return }
        canvas.inkColor = color
        Telemetry.shared.log("draw.color", ["key": key])
    }

    init() {
        canvas = CanvasView(frame: NSRect(origin: .zero, size: window.frame.size))
        window.contentView = canvas
        wireCanvas()
    }

    func toggle() {
        if isActive {
            deactivate(trigger: "hotkey.ctrl2")
        } else {
            activate()
        }
    }

    func escape() {
        guard requiresDeactivation else { return }
        deactivate(trigger: "esc")
    }

    private func activate() {
        guard let token = activation.beginLoading() else { return }
        Task { [weak self] in
            // 截图发生在 overlay 显示之前，底图不会拍到自身
            let img = await FreezeCapture.grab()
            await MainActor.run { [weak self] in
                guard let self, self.activation.activate(token) else { return }
                self.show(freeze: img)
            }
        }
    }

    @MainActor private func show(freeze img: CGImage?) {
        canvas.freezeImage = img
        canvas.showBadge = true
        window.ignoresMouseEvents = false
        window.orderFrontRegardless()
        window.makeKey()
        window.makeFirstResponder(canvas)
        window.invalidateCursorRects(for: canvas)
        NSApp.activate(ignoringOtherApps: true)

        var props = ["mode": img != nil ? "frozen" : "live-glass"]
        if let d = afterEscSeconds?() { props["afterEsc"] = String(format: "%.1f", d) }
        Telemetry.shared.log("layer.draw.on", props)
        onActiveChange?(true, "hotkey.ctrl2")
        maybeShowHint()
    }

    private func deactivate(trigger: String) {
        guard activation.deactivate() else { return }
        let count = canvas.strokes.count
        canvas.clearAll()
        canvas.freezeImage = nil
        canvas.showBadge = false
        window.ignoresMouseEvents = true
        window.orderOut(nil)
        Telemetry.shared.log("layer.draw.off",
                             ["trigger": trigger, "strokes": "\(count)"])
        onActiveChange?(false, trigger)
    }

    private func wireCanvas() {
        canvas.onStrokeCommit = { s in
            Telemetry.shared.log("draw.stroke",
                                 ["points": "\(s.points.count)", "width": "\(Int(s.width))"])
        }
        canvas.onUndo = { [weak self] in self?.performUndo() }
        canvas.onEscape = { [weak self] in self?.onRequestClearAll?() }
        canvas.onColorKey = { [weak self] key in self?.applyColorKey(key) }
        canvas.onWidthChange = { w in
            Telemetry.shared.log("draw.width", ["width": "\(Int(w))"])
        }
    }

    private func maybeShowHint() {
        let count = StateStore.bump("drawOnCount")
        guard count <= InkConstants.hintShowLimit else { return }
        HintBar(text: "R/G/B/O/Y/P 换色 · Ctrl+滚轮 笔宽 · Ctrl+Z 撤销 · Esc 清场")
            .flash(in: canvas)
    }
}
