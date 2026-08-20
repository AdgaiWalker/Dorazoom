import AppKit

enum CanvasTextEditingFontSizeAdjustment: Equatable, Sendable {
    case increase
    case decrease
}

enum CanvasTextEditingInputPolicy {
    static func fontSizeAdjustment(
        charactersIgnoringModifiers: String?,
        modifiers: NSEvent.ModifierFlags
    ) -> CanvasTextEditingFontSizeAdjustment? {
        let normalized = modifiers.intersection(.deviceIndependentFlagsMask)
        guard normalized.contains(.command),
              !normalized.contains(.control),
              !normalized.contains(.option) else {
            return nil
        }
        return switch charactersIgnoringModifiers {
        case "=", "+": .increase
        case "-", "_": .decrease
        default: nil
        }
    }

    static func fontSizeAdjustment(
        scrollingDeltaY: CGFloat
    ) -> CanvasTextEditingFontSizeAdjustment? {
        if scrollingDeltaY > 0 { return .increase }
        if scrollingDeltaY < 0 { return .decrease }
        return nil
    }
}

@MainActor
final class CanvasTextEditingSession {
    private final class CanvasTextView: NSTextView {
        var onTextChange: ((String) -> Void)?
        var onExitRequested: (() -> Void)?
        var onFontSizeAdjustment: ((CanvasTextEditingFontSizeAdjustment) -> Void)?

        override func didChangeText() {
            super.didChangeText()
            onTextChange?(string)
        }

        override func keyDown(with event: NSEvent) {
            if event.keyCode == 53, !hasMarkedText() {
                onExitRequested?()
                return
            }
            super.keyDown(with: event)
        }

        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            if let adjustment = CanvasTextEditingInputPolicy.fontSizeAdjustment(
                charactersIgnoringModifiers: event.charactersIgnoringModifiers,
                modifiers: event.modifierFlags
            ) {
                onFontSizeAdjustment?(adjustment)
                return true
            }
            return super.performKeyEquivalent(with: event)
        }

        override func scrollWheel(with event: NSEvent) {
            guard let adjustment = CanvasTextEditingInputPolicy.fontSizeAdjustment(
                scrollingDeltaY: event.scrollingDeltaY
            ) else { return }
            onFontSizeAdjustment?(adjustment)
        }
    }

    private let textView = CanvasTextView(frame: .zero)
    private let onTextChange: (String) -> Void
    private let onExitRequested: () -> Void
    private let onFontSizeAdjustment: (CanvasTextEditingFontSizeAdjustment) -> Void

    init(
        onTextChange: @escaping (String) -> Void,
        onExitRequested: @escaping () -> Void,
        onFontSizeAdjustment: @escaping (CanvasTextEditingFontSizeAdjustment) -> Void = { _ in }
    ) {
        self.onTextChange = onTextChange
        self.onExitRequested = onExitRequested
        self.onFontSizeAdjustment = onFontSizeAdjustment
        configureTextView()
    }

    var inputClient: NSTextView { textView }
    var text: String { textView.string }
    var isActive: Bool { textView.superview != nil }

    func begin(
        in hostView: NSView,
        frame: CGRect,
        font: NSFont,
        color: NSColor = .labelColor,
        alignment: NSTextAlignment
    ) {
        guard !isActive else { return }
        textView.frame = frame
        textView.font = font
        textView.textColor = color
        textView.insertionPointColor = color
        textView.alignment = alignment
        textView.string = ""
        hostView.addSubview(textView)
        hostView.window?.makeFirstResponder(textView)
    }

    func updateFrame(_ frame: CGRect) {
        guard isActive else { return }
        textView.frame = frame
    }

    func updateFont(_ font: NSFont) {
        textView.font = font
    }

    @discardableResult
    func finish() -> String {
        let committedText = textView.string
        if textView.hasMarkedText() {
            textView.unmarkText()
        }
        textView.removeFromSuperview()
        return committedText
    }

    private func configureTextView() {
        textView.onTextChange = { [weak self] text in
            self?.onTextChange(text)
        }
        textView.onExitRequested = { [weak self] in
            self?.onExitRequested()
        }
        textView.onFontSizeAdjustment = { [weak self] adjustment in
            self?.onFontSizeAdjustment(adjustment)
        }
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
    }
}
