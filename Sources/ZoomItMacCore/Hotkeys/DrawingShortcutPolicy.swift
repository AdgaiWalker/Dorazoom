struct DrawingShortcut: Equatable, Hashable, Sendable {
    var key: String
    var modifiers: Set<KeyboardModifier>

    init(key: String, modifiers: Set<KeyboardModifier> = []) {
        self.key = key.lowercased()
        self.modifiers = modifiers
    }
}

enum DrawingAction: Equatable, Sendable {
    case setTool(AnnotationTool)
    case setColor(AnnotationColor)
    case setHighlightColor(AnnotationColor)
    case setCanvas(CanvasBackground)
    case toggleTyping(rightAligned: Bool)
    case increasePenWidth
    case decreasePenWidth
    case undo
    case clear
}

struct DrawingShortcutPolicy: Equatable, Sendable {
    private var actionsByShortcut: [DrawingShortcut: DrawingAction]

    static let zoomItDefault = DrawingShortcutPolicy(actionsByShortcut: [
        DrawingShortcut(key: "r"): .setColor(.red),
        DrawingShortcut(key: "g"): .setColor(.green),
        DrawingShortcut(key: "b"): .setColor(.blue),
        DrawingShortcut(key: "y"): .setColor(.yellow),
        DrawingShortcut(key: "o"): .setColor(.orange),
        DrawingShortcut(key: "p"): .setColor(.pink),
        DrawingShortcut(key: "r", modifiers: [.shift]): .setHighlightColor(.red),
        DrawingShortcut(key: "g", modifiers: [.shift]): .setHighlightColor(.green),
        DrawingShortcut(key: "b", modifiers: [.shift]): .setHighlightColor(.blue),
        DrawingShortcut(key: "y", modifiers: [.shift]): .setHighlightColor(.yellow),
        DrawingShortcut(key: "o", modifiers: [.shift]): .setHighlightColor(.orange),
        DrawingShortcut(key: "p", modifiers: [.shift]): .setHighlightColor(.pink),
        DrawingShortcut(key: "w"): .setCanvas(.whiteboard),
        DrawingShortcut(key: "k"): .setCanvas(.blackboard),
        DrawingShortcut(key: "f"): .setTool(.pen),
        DrawingShortcut(key: "l"): .setTool(.line),
        DrawingShortcut(key: "a"): .setTool(.arrow),
        DrawingShortcut(key: "h"): .setTool(.highlighter),
        DrawingShortcut(key: "m"): .setTool(.blur),
        DrawingShortcut(key: "x"): .setTool(.redact),
        DrawingShortcut(key: "n"): .setTool(.numberedCallout),
        DrawingShortcut(key: "t"): .toggleTyping(rightAligned: false),
        DrawingShortcut(key: "t", modifiers: [.shift]): .toggleTyping(rightAligned: true),
        DrawingShortcut(key: "["): .decreasePenWidth,
        DrawingShortcut(key: "]"): .increasePenWidth,
        DrawingShortcut(key: "z", modifiers: [.command]): .undo,
        DrawingShortcut(key: "z", modifiers: [.control]): .undo,
        DrawingShortcut(key: "e"): .clear
    ])

    func action(for shortcut: DrawingShortcut) -> DrawingAction? {
        actionsByShortcut[shortcut]
    }

    func shortcut(for action: DrawingAction) -> DrawingShortcut? {
        actionsByShortcut.first { $0.value == action }?.key
    }
}

enum DrawingShortcutGuide {
    static let colors = "按 R / G / B / Y / O / P 切换红、绿、蓝、黄、橙、粉画笔。白色和黑色画笔没有默认按键，可从颜色控件选择。"
    static let canvas = "进入圈画状态后，按 W 进入白板，按 K 进入黑板；再次选择其他画布状态即可返回。W / K 不是全局快捷键，也不需要 Control。"
    static let text = "进入圈画状态后，按 T 开始左对齐文字，按 Shift+T 开始右对齐文字。点击新位置会提交上一段并开始下一段；按 Esc 结束文字编辑。滚轮或 Command++ / Command+- 调整字号；方向键、删除、选择和粘贴由 macOS 文本系统处理。"
}
