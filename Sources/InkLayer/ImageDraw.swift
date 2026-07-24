import AppKit

/// 统一 CGImage → AppKit 坐标系绘制（消除顶左/底左翻转与模糊）
enum ImageDraw {
    /// 在当前 NSGraphicsContext 中把 CGImage 画进 rect（pt）
    static func draw(_ image: CGImage, in rect: CGRect) {
        let src = NSRect(x: 0, y: 0,
                         width: CGFloat(image.width),
                         height: CGFloat(image.height))
        let ns = NSImage(cgImage: image, size: src.size)
        ns.draw(in: rect, from: src, operation: .copy, fraction: 1.0,
                respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.high])
    }

    /// 按视图 backingScale 生成离屏位图（Retina 清晰）
    static func bitmapRep(for view: NSView, rect: NSRect) -> NSBitmapImageRep? {
        let scale = view.window?.backingScaleFactor
            ?? view.window?.screen?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2
        guard rect.width > 0, rect.height > 0 else { return nil }
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: max(1, Int((rect.width * scale).rounded())),
            pixelsHigh: max(1, Int((rect.height * scale).rounded())),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        rep.size = rect.size // 逻辑尺寸（pt）
        return rep
    }
}
