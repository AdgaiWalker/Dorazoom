enum DrawingShortcutCommandPolicy {
    static func command(for shortcut: DrawingShortcut) -> AppCommand? {
        guard let action = DrawingShortcutPolicy.zoomItDefault.action(for: shortcut) else {
            return nil
        }

        switch action {
        case .setTool(let tool):
            return .setTool(tool)
        case .setColor(let color):
            return .setColor(color)
        case .setHighlightColor(let color):
            return .setHighlightColor(color)
        case .setCanvas(let background):
            return .setCanvas(background)
        case .toggleTyping(let rightAligned):
            return .toggleTyping(rightAligned: rightAligned)
        case .increasePenWidth:
            return .increasePenWidth
        case .decreasePenWidth:
            return .decreasePenWidth
        case .undo:
            return .undo
        case .clear:
            return .clear
        }
    }
}
