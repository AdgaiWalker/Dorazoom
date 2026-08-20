import AppKit

@MainActor
final class WindowTargetSelectionController {
    private(set) var window: NSWindow?
    private var onSelected: ((WindowSnipRequestPlan) -> Void)?
    private var onCancelled: (() -> Void)?

    init(
        candidatesFrontToBack: [WindowSnipCandidate],
        ownProcessID: Int32,
        includeShadow: Bool,
        displayFrames: [CGRect],
        pointerProvider: @escaping () -> CGPoint,
        onSelected: @escaping (WindowSnipRequestPlan) -> Void,
        onCancelled: @escaping () -> Void
    ) {
        self.onSelected = onSelected
        self.onCancelled = onCancelled
        let desktopFrame = displayFrames.reduce(CGRect.null) { $0.union($1) }
        guard !desktopFrame.isNull, !desktopFrame.isEmpty else { return }

        let window = SnipWindow(
            contentRect: desktopFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.backgroundColor = .clear
        window.isOpaque = false
        window.isReleasedWhenClosed = false
        window.acceptsMouseMovedEvents = true
        window.sharingType = .none

        let view = WindowTargetSelectionView(
            frame: CGRect(origin: .zero, size: desktopFrame.size),
            desktopOrigin: desktopFrame.origin,
            candidatesFrontToBack: candidatesFrontToBack,
            ownProcessID: ownProcessID,
            includeShadow: includeShadow,
            displayFrames: displayFrames,
            pointerProvider: pointerProvider
        )
        view.onSelected = { [weak self] plan in self?.select(plan) }
        view.onCancelled = { [weak self] in self?.cancel() }
        window.contentView = view
        self.window = window
    }

    func present() {
        guard let window else {
            cancel()
            return
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(window.contentView)
    }

    func cancel() {
        closeWindow()
        let callback = onCancelled
        onCancelled = nil
        onSelected = nil
        callback?()
    }

    private func select(_ plan: WindowSnipRequestPlan) {
        closeWindow()
        let callback = onSelected
        onSelected = nil
        onCancelled = nil
        callback?(plan)
    }

    private func closeWindow() {
        window?.orderOut(nil)
        window = nil
    }
}

@MainActor
private final class WindowTargetSelectionView: NSView {
    var onSelected: ((WindowSnipRequestPlan) -> Void)?
    var onCancelled: (() -> Void)?

    private let desktopOrigin: CGPoint
    private let candidatesFrontToBack: [WindowSnipCandidate]
    private let ownProcessID: Int32
    private let includeShadow: Bool
    private let displayFrames: [CGRect]
    private let pointerProvider: () -> CGPoint
    private var hoveredPlan: WindowSnipRequestPlan?

    init(
        frame: CGRect,
        desktopOrigin: CGPoint,
        candidatesFrontToBack: [WindowSnipCandidate],
        ownProcessID: Int32,
        includeShadow: Bool,
        displayFrames: [CGRect],
        pointerProvider: @escaping () -> CGPoint
    ) {
        self.desktopOrigin = desktopOrigin
        self.candidatesFrontToBack = candidatesFrontToBack
        self.ownProcessID = ownProcessID
        self.includeShadow = includeShadow
        self.displayFrames = displayFrames
        self.pointerProvider = pointerProvider
        super.init(frame: frame)
        updateHoveredPlan()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseMoved(with event: NSEvent) {
        updateHoveredPlan()
    }

    override func mouseDragged(with event: NSEvent) {
        updateHoveredPlan()
    }

    override func mouseDown(with event: NSEvent) {
        updateHoveredPlan()
        if let hoveredPlan {
            onSelected?(hoveredPlan)
        } else {
            onCancelled?()
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancelled?()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setFillColor(NSColor.black.withAlphaComponent(0.08).cgColor)
        context.fill(bounds)

        if let hoveredPlan,
           let candidate = candidatesFrontToBack.first(where: { $0.windowID == hoveredPlan.windowID }) {
            var appKitRect = MultiDisplayTargetingPolicy.appKitRect(
                fromScreenCaptureRect: candidate.frame,
                displayFrames: displayFrames
            )
            appKitRect.origin.x -= desktopOrigin.x
            appKitRect.origin.y -= desktopOrigin.y
            context.setFillColor(NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor)
            context.fill(appKitRect)
            context.setStrokeColor(NSColor.controlAccentColor.cgColor)
            context.setLineWidth(3)
            context.stroke(appKitRect.insetBy(dx: 1.5, dy: 1.5))
        }

        let message = AppLocalization.string(
            "capture.window_selection.instruction",
            defaultValue: "Point to a window and click · Esc to cancel"
        )
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.78)
        ]
        NSString(string: message).draw(at: CGPoint(x: 24, y: bounds.height - 48), withAttributes: attributes)
    }

    private func updateHoveredPlan() {
        var session = WindowSnipSession()
        hoveredPlan = session.begin(
            pointer: pointerProvider(),
            candidatesFrontToBack: candidatesFrontToBack,
            ownProcessID: ownProcessID,
            includeShadow: includeShadow
        )
        needsDisplay = true
    }
}
