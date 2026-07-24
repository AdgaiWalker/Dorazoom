import AppKit

/// 白板层：Ctrl+4。纯白底，鼠标穿透，可与圈画/打字叠加
final class WhiteboardLayer {
    /// 略低于圈画/打字，保证标注画在白板之上
    private let window = OverlayWindow(
        level: NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue - 1))
    private let board: WhiteboardView
    private(set) var isActive = false

    /// Snip 排除用
    var windowRef: NSWindow { window }

    var onActiveChange: ((Bool) -> Void)?

    init() {
        board = WhiteboardView(frame: NSRect(origin: .zero, size: window.frame.size))
        window.contentView = board
        // 始终穿透：白板只作背景，不抢输入
        window.ignoresMouseEvents = true
    }

    func toggle() {
        isActive ? deactivate(trigger: "hotkey.ctrl4") : activate()
    }

    func escape() {
        guard isActive else { return }
        deactivate(trigger: "esc")
    }

    private func activate() {
        window.orderFrontRegardless()
        isActive = true
        Telemetry.shared.log("layer.whiteboard.on")
        onActiveChange?(true)
        maybeShowHint()
    }

    private func deactivate(trigger: String) {
        isActive = false
        window.orderOut(nil)
        Telemetry.shared.log("layer.whiteboard.off", ["trigger": trigger])
        onActiveChange?(false)
    }

    private func maybeShowHint() {
        let count = StateStore.bump("whiteboardOnCount")
        guard count <= InkConstants.hintShowLimit else { return }
        // 提示挂在 board 上；因穿透，数秒后自动消失即可
        HintBar(text: "白板已开 · 可叠加 Ctrl+2 圈画 / Ctrl+3 打字 · Esc 清场")
            .flash(in: board)
    }
}

/// 纯白画板
final class WhiteboardView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        bounds.fill()
        // 角落标记
        let badge = NSRect(x: bounds.maxX - 100, y: 20, width: 80, height: 32)
        NSColor.black.withAlphaComponent(0.45).setFill()
        NSBezierPath(roundedRect: badge, xRadius: 8, yRadius: 8).fill()
        ("白板" as NSString).draw(at: NSPoint(x: badge.minX + 22, y: badge.minY + 8),
                                  withAttributes: [
                                    .font: NSFont.systemFont(ofSize: 14, weight: .medium),
                                    .foregroundColor: NSColor.white
                                  ])
    }
}
