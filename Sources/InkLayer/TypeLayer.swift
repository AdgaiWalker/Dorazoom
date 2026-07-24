import AppKit

/// 烙字：回车确认后的静态文字
struct TextStamp {
    var text: String
    /// 与输入时 cell 标题区原点一致（canvas 坐标）
    var origin: CGPoint
    var color: NSColor
    var fontSize: CGFloat
}

/// 打字层 Ctrl+3：单行横排输入（防中文竖排错位）+ Ctrl+Z 撤销
final class TypeLayer: NSObject, NSTextFieldDelegate {
    private let window: OverlayWindow
    private let canvas: TypeCanvasView
    private(set) var isActive = false
    private var scrollMonitor: Any?
    private var field: InkTypeField?

    var onActiveChange: ((Bool) -> Void)?
    var onRequestClearAll: (() -> Void)?

    /// Snip 排除用
    var windowRef: NSWindow { window }
    /// Snip 合成用烙字
    var currentStamps: [TextStamp] { canvas.stamps }
    /// IME 拼写中（编排器不抢键）
    var isComposing: Bool {
        guard let f = field, let tv = f.currentEditor() as? NSTextView else { return false }
        return tv.hasMarkedText()
    }
    /// 输入框是否空（空则可换色）
    var isFieldEmpty: Bool { field?.stringValue.isEmpty ?? true }

    override init() {
        let win = OverlayWindow()
        canvas = TypeCanvasView(frame: NSRect(origin: .zero, size: win.frame.size))
        window = win
        super.init()
        window.contentView = canvas
        canvas.onEscape = { [weak self] in self?.onRequestClearAll?() }
        canvas.onPlaceField = { [weak self] point in self?.beginEditing(at: point) }
        canvas.onUndo = { [weak self] in self?.performUndo() }
        canvas.onColorKey = { [weak self] key in self?.applyColorKey(key) }
        canvas.onFontSizeChange = { [weak self] size in
            self?.applyStyleToField()
            Telemetry.shared.log("type.fontSize", ["size": "\(Int(size))"])
        }
    }

    func toggle() {
        isActive ? deactivate(trigger: "hotkey.ctrl3") : activate()
    }

    func escape() {
        guard isActive else { return }
        deactivate(trigger: "esc")
    }

    /// 编排器/Snip 后夺回焦点
    func regainFocus() {
        guard isActive else { return }
        window.makeKey()
        if let f = field {
            window.makeFirstResponder(f)
        } else {
            window.makeFirstResponder(canvas)
        }
    }

    /// 编排器路由 Ctrl+Z
    func performUndoPublic() { performUndo() }

    /// 编排器路由换色
    func applyColorKey(_ key: String) {
        guard isActive, let color = InkPalette.color(forKey: key) else { return }
        canvas.inkColor = color
        applyStyleToField()
        Telemetry.shared.log("type.color", ["key": key])
    }

    private func activate() {
        canvas.showBadge = true
        window.ignoresMouseEvents = false
        window.orderFrontRegardless()
        window.makeKey()
        window.makeFirstResponder(canvas)
        NSApp.activate(ignoringOtherApps: true)
        isActive = true
        installMonitors()
        Telemetry.shared.log("layer.type.on")
        onActiveChange?(true)
        maybeShowHint()
    }

    private func deactivate(trigger: String) {
        endEditing(commit: false)
        removeMonitors()
        isActive = false
        let count = canvas.stamps.count
        canvas.clearAll()
        canvas.showBadge = false
        window.ignoresMouseEvents = true
        window.orderOut(nil)
        Telemetry.shared.log("layer.type.off",
                             ["trigger": trigger, "stamps": "\(count)"])
        onActiveChange?(false)
    }

    // MARK: - 输入

    private func beginEditing(at point: CGPoint) {
        endEditing(commit: false)

        let font = TypeTypography.font(size: canvas.fontSize)
        let lineH = TypeTypography.lineHeight(font: font)
        // 点击点 ≈ 文字中线
        let origin = NSPoint(x: point.x, y: point.y - lineH * 0.5)

        let f = InkTypeField(frame: NSRect(x: origin.x, y: origin.y,
                                           width: TypeTypography.fieldWidth(fontSize: canvas.fontSize),
                                           height: lineH))
        f.font = font
        f.textColor = canvas.inkColor
        f.delegate = self
        canvas.addSubview(f)
        window.makeFirstResponder(f)
        field = f
        Telemetry.shared.log("type.field.open")
    }

    private func applyStyleToField() {
        guard let f = field else { return }
        let font = TypeTypography.font(size: canvas.fontSize)
        let lineH = TypeTypography.lineHeight(font: font)
        f.font = font
        f.textColor = canvas.inkColor
        var frame = f.frame
        let midY = frame.midY
        frame.size.height = lineH
        frame.origin.y = midY - lineH / 2
        frame.size.width = TypeTypography.fieldWidth(fontSize: canvas.fontSize)
        f.frame = frame
        f.needsDisplay = true
        canvas.needsDisplay = true
    }

    private func endEditing(commit: Bool) {
        guard let f = field else { return }
        // 去掉首尾空白，但保留中间空格；去掉意外换行（防竖排残留）
        let raw = f.stringValue
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
        let text = raw.trimmingCharacters(in: .whitespaces)
        let drawOrigin = TypeTypography.drawOrigin(of: f, in: canvas)
        f.removeFromSuperview()
        field = nil
        window.makeFirstResponder(canvas)
        if commit, !text.isEmpty {
            canvas.addStamp(TextStamp(text: text, origin: drawOrigin,
                                      color: canvas.inkColor, fontSize: canvas.fontSize))
            Telemetry.shared.log("type.stamp", ["chars": "\(text.count)"])
        }
    }

    /// Ctrl+Z：输入中清空/关框；否则撤销上一枚烙字
    private func performUndo() {
        if let f = field {
            if !f.stringValue.isEmpty {
                f.stringValue = ""
                Telemetry.shared.log("type.undo", ["scope": "field"])
            } else {
                endEditing(commit: false)
                Telemetry.shared.log("type.undo", ["scope": "field-close"])
            }
            return
        }
        if canvas.undoLast() {
            Telemetry.shared.log("type.undo", ["scope": "stamp"])
        }
    }

    // MARK: - NSTextFieldDelegate

    func control(_ control: NSControl, textView: NSTextView,
                 doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if textView.hasMarkedText() { return false } // IME 选词中
            endEditing(commit: true)
            return true
        }
        if commandSelector == Selector(("undo:")) {
            performUndo()
            return true
        }
        // 禁止插入换行（中文输入偶发）
        if commandSelector == #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:))
            || commandSelector == #selector(NSResponder.insertLineBreak(_:))
            || commandSelector == #selector(NSResponder.insertContainerBreak(_:)) {
            return true
        }
        return false
    }

    // MARK: - 监视器（输入框抢焦点时仍能调字号；Ctrl+Z/换色由编排器统一路由）

    private func installMonitors() {
        removeMonitors()
        // 仅滚轮：Ctrl+Z / 换色交给 LayerCoordinator，避免双层 monitor 抢键
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, self.isActive, event.modifierFlags.contains(.control) else {
                return event
            }
            let step = InkConstants.fontSizeStep
            let delta: CGFloat = event.scrollingDeltaY > 0 ? step : -step
            self.canvas.fontSize = min(InkConstants.fontSizeRange.upperBound,
                                       max(InkConstants.fontSizeRange.lowerBound,
                                           self.canvas.fontSize + delta))
            self.applyStyleToField()
            self.canvas.onFontSizeChange?(self.canvas.fontSize)
            return nil
        }
    }

    private func removeMonitors() {
        if let m = scrollMonitor { NSEvent.removeMonitor(m); scrollMonitor = nil }
    }

    private func maybeShowHint() {
        let count = StateStore.bump("typeOnCount")
        guard count <= InkConstants.hintShowLimit else { return }
        HintBar(text: "点击输入 · 回车烙字 · Ctrl+Z 撤销 · Ctrl+滚轮字号 · Esc 清场")
            .flash(in: canvas)
    }
}

// MARK: - 单行输入框（强制横排，禁止换行）

/// 板书用单行 TextField：无边框、透明底、绝不竖排换行
final class InkTypeField: NSTextField {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false
        isBezeled = false
        drawsBackground = false
        backgroundColor = .clear
        focusRingType = .none
        isEditable = true
        isSelectable = true
        isAutomaticTextCompletionEnabled = false
        alignment = .left
        maximumNumberOfLines = 1
        usesSingleLineMode = true
        lineBreakMode = .byClipping
        cell?.wraps = false
        cell?.isScrollable = true
        cell?.usesSingleLineMode = true
        if let cell = cell as? NSTextFieldCell {
            cell.lineBreakMode = .byClipping
            cell.wraps = false
            cell.isScrollable = true
            cell.usesSingleLineMode = true
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    /// 禁止多行编辑器行为
    override var allowsEditingTextAttributes: Bool {
        get { false }
        set {}
    }
}

// MARK: - 字体与几何（输入 / 烙字共用）

enum TypeTypography {
    static func font(size: CGFloat) -> NSFont {
        .systemFont(ofSize: size, weight: .bold)
    }

    static func lineHeight(font: NSFont) -> CGFloat {
        ceil(font.ascender + abs(font.descender) + font.leading + 6)
    }

    static func fieldWidth(fontSize: CGFloat) -> CGFloat {
        // 宁宽勿窄：窄框是中文被竖排换行的主因
        max(800, fontSize * 22)
    }

    static func attributes(color: NSColor, fontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        let para = NSMutableParagraphStyle()
        para.lineBreakMode = .byClipping
        para.alignment = .left
        return [
            .font: font(size: fontSize),
            .foregroundColor: color,
            .paragraphStyle: para
        ]
    }

    static func draw(_ stamp: TextStamp) {
        let string = NSAttributedString(
            string: stamp.text,
            attributes: attributes(color: stamp.color, fontSize: stamp.fontSize))
        let size = string.size()
        let rect = CGRect(
            origin: stamp.origin,
            size: CGSize(width: max(size.width, 1), height: max(size.height, 1)))
        string.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
    }

    /// cell 实际画字原点 → canvas 坐标（烙字与输入对齐）
    static func drawOrigin(of field: NSTextField, in canvas: NSView) -> CGPoint {
        if let cell = field.cell as? NSTextFieldCell {
            let title = cell.titleRect(forBounds: field.bounds)
            return field.convert(title.origin, to: canvas)
        }
        return field.convert(field.bounds.origin, to: canvas)
    }
}

// MARK: - 画布

final class TypeCanvasView: NSView {
    private(set) var stamps: [TextStamp] = []
    var inkColor: NSColor = InkPalette.defaultColor { didSet { needsDisplay = true } }
    var fontSize: CGFloat = InkConstants.defaultFontSize { didSet { needsDisplay = true } }
    var showBadge = false { didSet { needsDisplay = true } }

    var onPlaceField: ((CGPoint) -> Void)?
    var onEscape: (() -> Void)?
    var onUndo: (() -> Void)?
    var onColorKey: ((String) -> Void)?
    var onFontSizeChange: ((CGFloat) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        for stamp in stamps { TypeTypography.draw(stamp) }
        if showBadge { drawBadge() }
    }

    private func drawBadge() {
        let badge = NSRect(x: bounds.maxX - 160, y: 20, width: 140, height: 32)
        NSColor.black.withAlphaComponent(0.55).setFill()
        NSBezierPath(roundedRect: badge, xRadius: 8, yRadius: 8).fill()
        inkColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: badge.minX + 12, y: badge.minY + 8,
                                    width: 16, height: 16)).fill()
        let label = "字 · \(Int(fontSize))pt" as NSString
        label.draw(at: NSPoint(x: badge.minX + 36, y: badge.minY + 8), withAttributes: [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.white
        ])
    }

    override func mouseDown(with event: NSEvent) {
        onPlaceField?(convert(event.locationInWindow, from: nil))
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onEscape?(); return }
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

    override func scrollWheel(with event: NSEvent) {
        guard event.modifierFlags.contains(.control) else { return }
        let step = InkConstants.fontSizeStep
        let delta: CGFloat = event.scrollingDeltaY > 0 ? step : -step
        fontSize = min(InkConstants.fontSizeRange.upperBound,
                       max(InkConstants.fontSizeRange.lowerBound, fontSize + delta))
        onFontSizeChange?(fontSize)
    }

    func addStamp(_ s: TextStamp) {
        stamps.append(s)
        needsDisplay = true
    }

    @discardableResult
    func undoLast() -> Bool {
        guard !stamps.isEmpty else { return false }
        stamps.removeLast()
        needsDisplay = true
        return true
    }

    func clearAll() {
        stamps.removeAll()
        needsDisplay = true
    }
}
