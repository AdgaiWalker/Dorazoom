import AppKit

/// 当前持有键盘语义的交互层（解决多层同开时快捷键「假死」）
enum InputOwner: String {
    case none
    case draw
    case type
    case zoom
    case snip
}

/// 层编排器：热键分发、Esc 全清、焦点归属、菜单栏状态聚合
/// 各层只关心自身；跨层协作集中在此
final class LayerCoordinator {
    let draw = DrawLayer()
    let type = TypeLayer()
    let whiteboard = WhiteboardLayer()
    let zoom = ZoomLayer()
    let snip = SnipLayer()
    let record = RecordLayer()

    private var lastEscAt: Date?
    /// 当前输入归属：Ctrl+Z / 换色等路由到此层
    private(set) var inputOwner: InputOwner = .none
    private var shortcutMonitor: Any?
    private var snipActivation = ActivationLifecycle()

    var onStatusChange: (() -> Void)?
    var onNeedScreenPermission: ((String) -> Void)?

    init() {
        wireLayers()
        installGlobalShortcuts()
    }

    deinit {
        if let m = shortcutMonitor { NSEvent.removeMonitor(m) }
    }

    // MARK: - 接线

    private func wireLayers() {
        draw.afterEscSeconds = { [weak self] in
            guard let t = self?.lastEscAt else { return nil }
            let d = Date().timeIntervalSince(t)
            return d <= InkConstants.afterEscWindow ? d : nil
        }
        draw.onActiveChange = { [weak self] active, trigger in
            if trigger == "esc" { self?.lastEscAt = Date() }
            if active {
                self?.claimInput(.draw)
            } else if self?.inputOwner == .draw {
                self?.releaseInput(preferring: .type)
            }
            self?.onStatusChange?()
        }
        draw.onRequestClearAll = { [weak self] in self?.clearAll(trigger: "esc") }

        type.onActiveChange = { [weak self] active in
            if active {
                self?.claimInput(.type)
            } else if self?.inputOwner == .type {
                self?.releaseInput(preferring: .draw)
            }
            self?.onStatusChange?()
        }
        type.onRequestClearAll = { [weak self] in self?.clearAll(trigger: "esc") }

        whiteboard.onActiveChange = { [weak self] _ in self?.onStatusChange?() }

        zoom.onActiveChange = { [weak self] active in
            if active {
                self?.claimInput(.zoom)
            } else if self?.inputOwner == .zoom {
                self?.releaseInput(preferring: .draw)
            }
            self?.onStatusChange?()
        }
        zoom.onRequestClearAll = { [weak self] in self?.clearAll(trigger: "esc") }
        zoom.onNeedPermission = { [weak self] in self?.onNeedScreenPermission?("缩放") }

        snip.onActiveChange = { [weak self] active in
            if active {
                self?.claimInput(.snip)
            } else {
                _ = self?.snipActivation.deactivate()
                if self?.inputOwner == .snip {
                    self?.releaseInput(preferring: .type)
                }
            }
            self?.onStatusChange?()
        }
        snip.onRequestClearAll = { [weak self] in self?.clearAll(trigger: "esc") }

        record.onStateChange = { [weak self] _ in self?.onStatusChange?() }
        record.onNeedPermission = { [weak self] in self?.onNeedScreenPermission?("录屏") }
    }

    // MARK: - 输入归属

    private func claimInput(_ owner: InputOwner) {
        inputOwner = owner
        switch owner {
        case .draw: draw.regainFocus()
        case .type: type.regainFocus()
        case .zoom: break // zoom 自己 makeKey
        case .snip: break
        case .none: break
        }
    }

    /// 释放当前归属，按 prefer → draw → type → zoom 回落
    private func releaseInput(preferring prefer: InputOwner) {
        let order: [InputOwner] = {
            switch prefer {
            case .type: return [.type, .draw, .zoom]
            case .draw: return [.draw, .type, .zoom]
            case .zoom: return [.zoom, .draw, .type]
            default: return [.draw, .type, .zoom]
            }
        }()
        for o in order {
            switch o {
            case .draw where draw.isActive:
                claimInput(.draw); return
            case .type where type.isActive:
                claimInput(.type); return
            case .zoom where zoom.isActive:
                claimInput(.zoom); return
            default: break
            }
        }
        inputOwner = .none
    }

    /// 全局 monitor：多窗口时仍把 Ctrl+Z / 换色送到归属层
    private func installGlobalShortcuts() {
        shortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            // Snip 自己处理 Esc；录屏/无层时不抢
            guard self.inputOwner == .draw || self.inputOwner == .type else { return event }

            // IME 拼写中不抢
            if self.inputOwner == .type, self.type.isComposing { return event }

            // Ctrl+Z
            if event.modifierFlags.contains(.control),
               event.charactersIgnoringModifiers?.lowercased() == "z",
               !event.modifierFlags.contains(.shift) {
                self.routeUndo()
                return nil
            }

            // 换色：仅当打字层未在输入内容时
            if let chars = event.charactersIgnoringModifiers?.lowercased(),
               let ch = chars.first, chars.count == 1, InkPalette.keys.contains(ch) {
                if self.inputOwner == .type, !self.type.isFieldEmpty {
                    return event // 让文字正常输入 r/g/b
                }
                self.routeColor(String(ch))
                return nil
            }
            return event
        }
    }

    private func routeUndo() {
        switch inputOwner {
        case .draw: draw.performUndo()
        case .type: type.performUndoPublic()
        default: break
        }
    }

    private func routeColor(_ key: String) {
        switch inputOwner {
        case .draw: draw.applyColorKey(key)
        case .type: type.applyColorKey(key)
        default: break
        }
    }

    // MARK: - 热键动作

    func toggleZoom() { zoom.toggle() }
    func toggleDraw() { draw.toggle() }
    func toggleType() { type.toggle() }
    func toggleWhiteboard() { whiteboard.toggle() }
    func toggleRecord() { record.toggle() }

    func startSnip() {
        guard let token = snipActivation.beginLoading() else { return }
        // 矢量合成路径：排除自家 overlay 抓干净桌面，再叠笔画/烙字
        let exclude: [NSWindow] = [draw.windowRef, type.windowRef, whiteboard.windowRef, zoom.windowRef]
            .compactMap { $0 }
        let strokes = draw.isActive ? draw.currentStrokes : []
        let stamps = type.isActive ? type.currentStamps : []
        Task { [weak self] in
            let img = await FreezeCapture.grab(excluding: exclude)
            await MainActor.run { [weak self] in
                guard let self else { return }
                if let img {
                    guard self.snipActivation.activate(token) else { return }
                    let mode = (strokes.isEmpty && stamps.isEmpty) ? "screen" : "composite"
                    self.snip.start(freeze: img, strokes: strokes, stamps: stamps, mode: mode)
                } else {
                    guard self.snipActivation.fail(token) else { return }
                    Telemetry.shared.log("snip.denied")
                    self.onNeedScreenPermission?("Snip")
                }
            }
        }
    }

    /// Esc 清场：关闭全部标注层（录屏不中断）
    func clearAll(trigger: String) {
        let any = snipActivation.requiresDeactivation || draw.requiresDeactivation || type.isActive
            || whiteboard.isActive || zoom.requiresDeactivation
        if snipActivation.requiresDeactivation {
            if snip.isActive {
                snip.cancelFromOutside()
            } else {
                _ = snipActivation.deactivate()
            }
        }
        if draw.requiresDeactivation { draw.escape() }
        if type.isActive { type.escape() }
        if whiteboard.isActive { whiteboard.escape() }
        if zoom.requiresDeactivation { zoom.escape() }
        inputOwner = .none
        if trigger == "esc" { lastEscAt = Date() }
        if any {
            Telemetry.shared.log("clear.all", ["trigger": trigger])
        }
        onStatusChange?()
    }

    // MARK: - 菜单栏文案

    func statusPresentation() -> (title: String, color: NSColor?, detail: String) {
        if record.isRecording {
            return ("墨·●", .systemRed, "录制中 · Ctrl+5 或右上角计时条停止")
        }
        if snip.isActive {
            return ("墨·✂", nil, "Snip 拖选中 · 松开入剪贴板 · Esc 取消")
        }
        var tags: [String] = []
        if zoom.isActive { tags.append("放") }
        if whiteboard.isActive { tags.append("白") }
        if draw.isActive { tags.append("圈") }
        if type.isActive { tags.append("字") }
        if tags.isEmpty {
            return ("墨", nil, "待命 · Ctrl+1 缩放 · 2 圈画 · 3 打字 · 4 白板 · 5 录屏 · 6 Snip")
        }
        let focusHint: String = {
            switch inputOwner {
            case .draw: return "焦点:圈"
            case .type: return "焦点:字"
            case .zoom: return "焦点:放"
            default: return ""
            }
        }()
        let body = tags.joined(separator: " + ")
            + (focusHint.isEmpty ? "" : " · \(focusHint)")
            + " · Esc 清场"
        return ("墨·" + tags.joined(separator: ""), nil, body)
    }
}
