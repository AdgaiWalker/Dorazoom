import AppKit

/// 全局常量：集中配置，避免魔法数散落
enum InkConstants {
    /// 缩放初始倍率
    static let zoomDefaultScale: CGFloat = 2
    /// 缩放倍率范围（滚轮连续调节）
    static let zoomScaleRange: ClosedRange<CGFloat> = 1.25...8
    /// 滚轮每次倍率步进
    static let zoomScaleStep: CGFloat = 0.25

    /// 默认笔宽
    static let defaultInkWidth: CGFloat = 6
    /// 笔宽上下限
    static let inkWidthRange: ClosedRange<CGFloat> = 1...30

    /// 默认字号（打字层，对标板书可读性）
    static let defaultFontSize: CGFloat = 36
    /// 字号上下限
    static let fontSizeRange: ClosedRange<CGFloat> = 16...120
    /// 字号步进
    static let fontSizeStep: CGFloat = 4

    /// 发现性提示条：激活次数超过此值后不再弹出
    static let hintShowLimit = 20
    /// 活屏回魂代理指标窗口（秒）
    static let afterEscWindow: TimeInterval = 10
    /// Snip 最小选区边长（pt）
    static let snipMinEdge: CGFloat = 5
}

/// 六色调色板：圈画 / 打字共用，键位 R/G/B/O/Y/P
enum InkPalette {
    static let map: [String: NSColor] = [
        "r": .systemRed, "g": .systemGreen, "b": .systemBlue,
        "o": .systemOrange, "y": .systemYellow, "p": .systemPink
    ]
    static let defaultColor: NSColor = .systemRed
    static let keys = "rgboyp"

    static func color(forKey key: String) -> NSColor? { map[key.lowercased()] }
}
