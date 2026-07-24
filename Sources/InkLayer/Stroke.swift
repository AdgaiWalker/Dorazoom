import AppKit

/// 矢量笔画模型：一条自由笔迹 = 点列 + 颜色 + 宽度
struct Stroke {
    var points: [CGPoint]
    var color: NSColor
    var width: CGFloat
}
