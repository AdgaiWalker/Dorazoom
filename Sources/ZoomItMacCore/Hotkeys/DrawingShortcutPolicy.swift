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
