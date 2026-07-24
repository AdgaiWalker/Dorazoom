import AppKit

/// 发现性提示条：层激活时底部居中浮出，数秒后淡出移除
final class HintBar: NSView {
    private let label = NSTextField(labelWithString: "")

    init(text: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.65).cgColor
        layer?.cornerRadius = 10
        label.stringValue = text
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.alignment = .center
        addSubview(label)
    }

    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: NSSize {
        let s = label.intrinsicContentSize
        return NSSize(width: s.width + 32, height: s.height + 16)
    }

    override func layout() {
        super.layout()
        label.frame = bounds.insetBy(dx: 16, dy: 8)
    }

    /// 在父视图底部居中弹出，duration 秒后淡出并移除
    func flash(in parent: NSView, duration: TimeInterval = 2.5) {
        let size = intrinsicContentSize
        frame = NSRect(x: (parent.bounds.width - size.width) / 2,
                       y: 60, width: size.width, height: size.height)
        alphaValue = 0
        parent.addSubview(self)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            animator().alphaValue = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.4
                self?.animator().alphaValue = 0
            }, completionHandler: {
                self?.removeFromSuperview()
            })
        }
    }
}
