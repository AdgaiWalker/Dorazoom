import AppKit

/// 共享透明置顶画布容器
/// 生死线：sharingType = .readWrite（允许被 Screen Studio 等外部录制捕获）
final class OverlayWindow: NSWindow {
    init(level: NSWindow.Level = .screenSaver) {
        let frame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        super.init(contentRect: frame,
                   styleMask: .borderless,
                   backing: .buffered,
                   defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        self.level = level
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        sharingType = .readWrite
        ignoresMouseEvents = true // 未激活时鼠标穿透
    }

    override var canBecomeKey: Bool { true }
}
