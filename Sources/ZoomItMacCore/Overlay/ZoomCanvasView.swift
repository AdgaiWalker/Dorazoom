import AppKit

@MainActor
final class ZoomCanvasView: NSView {
    private var capturedFrame: CapturedFrame
    private let viewportController: ZoomViewportController
    private let annotationController: AnnotationController
    private let commandSink: (AppCommand) -> Void
    private let onPasteboardOutput: ((SnipPasteboardOutput) -> Void)?
    private var latestCursorLocation: CGPoint?
    private var pointerViewPoint: CGPoint = .zero
    private var isDrawingMode = false
    private var isStroking = false
    /// The tool of the in-progress stroke, used to hide the pen cursor while a
    /// shape (line/arrow/rectangle/ellipse) is being dragged out.
    private var activeStrokeTool: AnnotationTool?
    private var cursorHidden = false
    private var postTypingCursorAnchorOffset: CGPoint?
    private lazy var textEditingSession = CanvasTextEditingSession(
        onTextChange: { [weak self] text in
            guard let self else { return }
            annotationController.replaceTypingText(text)
            needsDisplay = true
        },
        onExitRequested: { [weak self] in
            self?.commandSink(.toggleTyping(rightAligned: false))
        },
        onFontSizeAdjustment: { [weak self] adjustment in
            guard let self else { return }
            switch adjustment {
            case .increase:
                commandSink(.increaseFontSize)
            case .decrease:
                commandSink(.decreaseFontSize)
            }
            updateTextEditingFont()
        }
    )
    /// While interactive live zoom is on, the overlay is click-through and a
    /// global monitor tracks the real cursor so the magnified view follows it.
    private var liveMouseMonitor: Any?
    private var drawingRightClickMonitor: Any?
    private var drawingGlobalRightClickMonitor: Any?
    private var liveZoomClickThrough = false
    /// Region-snip state: while active, a drag selects a rectangle of the
    /// current viewport to copy or save.
    private var isSelectingRegion = false
    private var regionAction: SnipAction = .copyImage
    private var regionAnchor: CGPoint?
    private var regionRect: CGRect = .zero
    private var regionCursorLease: CrosshairCursorLease?
    private var onRegionSnipFinished: (() -> Void)?
    private var onRegionPasteboardOutput: ((SnipPasteboardOutput) -> Void)?
    private let smoothImage: Bool
    private var isCapturingPrivacyBase = false

    var interactionMode: AppMode = .staticZoom {
        didSet {
            let leftTypingMode = oldValue == .typing && interactionMode != .typing
            let enteredTypingMode = oldValue != .typing && interactionMode == .typing
            if leftTypingMode {
                endTextEditingSession()
                anchorCursorAfterTyping()
            }
            switch interactionMode {
            case .typing:
                let wasDrawing = isDrawingMode
                exitDrawingMode(restoreCursor: false)
                // When coming from drawing, the pen dot is already tracked in
                // pointerViewPoint; exitDrawingMode warps the system cursor, so
                // don't re-read the mouse. Otherwise sync to the real cursor so
                // the caret appears under it and doesn't jump on the first move.
                if !wasDrawing, let window {
                    let windowPoint = window.convertPoint(fromScreen: NSEvent.mouseLocation)
                    pointerViewPoint = convert(windowPoint, from: nil)
                }
                // Place the caret at the current cursor position, like ZoomIt.
                let insertion = contentPoint(forViewPoint: pointerViewPoint)
                annotationController.setInsertionPoint(insertion)
            case .drawOnly:
                // Draw-without-zoom starts already in drawing mode so the first
                // click begins a stroke immediately. Returning from typing also
                // restores the drawn cursor, but without warping through the old
                // zoom anchor.
                enterDrawingMode()
            default:
                break
            }
            updateLiveZoomInteractivity()
            if enteredTypingMode {
                beginTextEditingSession()
            }
            needsDisplay = true
        }
    }

    init(
        frame frameRect: CGRect,
        capturedFrame: CapturedFrame,
        viewportController: ZoomViewportController,
        annotationController: AnnotationController,
        smoothImage: Bool,
        commandSink: @escaping (AppCommand) -> Void,
        onPasteboardOutput: ((SnipPasteboardOutput) -> Void)? = nil
    ) {
        self.capturedFrame = capturedFrame
        self.viewportController = viewportController
        self.annotationController = annotationController
        self.smoothImage = smoothImage
        self.commandSink = commandSink
        self.onPasteboardOutput = onPasteboardOutput
        super.init(frame: frameRect)
        // Anchor the initial zoom on the current cursor position so the view
        // does not jump when the mouse first moves after the hotkey activates.
        latestCursorLocation = NSEvent.mouseLocation
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Replaces the displayed screen image with a freshly captured live frame.
    /// Used by live zoom, where the magnified content keeps updating instead of
    /// being a frozen snapshot. The display geometry is unchanged, so only the
    /// pixels are swapped and a redraw is requested.
    func updateLiveImage(_ image: CGImage) {
        capturedFrame.image = image
        needsDisplay = true
    }

    /// Toggles drawing mode from outside (e.g. the draw hotkey while live
    /// zoomed): it arms drawing if idle, or leaves drawing mode if already on,
    /// without changing magnification.
    func toggleDrawingMode() {
        if isDrawingMode {
            exitDrawingMode()
        } else {
            enterDrawingMode()
        }
        needsDisplay = true
    }

    override var acceptsFirstResponder: Bool { true }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.interpolationQuality = smoothImage ? .high : .none

        let source = viewportController.sourceRect(for: bounds, cursorLocation: latestCursorLocation)

        switch annotationController.canvasBackground.renderFill {
        case .white:
            context.setFillColor(NSColor.white.cgColor)
            context.fill(bounds)
        case .black:
            context.setFillColor(NSColor.black.cgColor)
            context.fill(bounds)
        case .none:
            context.setFillColor(NSColor.black.cgColor)
            context.fill(bounds)

            let scaledSource = source.applying(CGAffineTransform(scaleX: capturedFrame.display.scaleFactor, y: capturedFrame.display.scaleFactor))

            // The view is flipped (top-left origin) so annotations share the same
            // coordinate space as the captured image. A CGImage draws upside down in
            // a flipped context, so flip vertically around the bounds while drawing it.
            context.saveGState()
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)
            if let cropped = capturedFrame.image.cropping(to: scaledSource) {
                context.draw(cropped, in: bounds)
            } else {
                context.draw(capturedFrame.image, in: bounds)
            }
            context.restoreGState()
        }

        context.saveGState()
        context.concatenate(viewportController.contentToDestinationTransform(source: source, destinationBounds: bounds))
        annotationController.render(
            in: context,
            bounds: bounds,
            includesPrivacyPreview: !isCapturingPrivacyBase
        )
        if interactionMode == .typing, !textEditingSession.isActive {
            drawTypingCaret(in: context, source: source)
        }
        context.restoreGState()

        switch OverlayPointerPresentation.visual(
            interactionMode: interactionMode,
            isDrawingMode: isDrawingMode,
            isSelectingRegion: isSelectingRegion,
            activeStrokeTool: activeStrokeTool,
            currentTool: annotationController.currentTool,
            style: annotationController.currentStyle,
            canvas: annotationController.canvasBackground,
            environment: FeedbackPresentationEnvironment(
                reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
                reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
                increaseContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
            )
        ) {
        case .magnifier:
            drawZoomPointerIndicator(in: context)
        case let .penRing(color, diameter, highContrast):
            drawPenRing(
                in: context,
                source: source,
                color: color,
                diameter: diameter,
                highContrast: highContrast
            )
        case let .highlighterNib(color, width, highContrast):
            drawHighlighterNib(in: context, source: source, color: color, width: width, highContrast: highContrast)
        case let .toolCrosshair(tool, color, highContrast):
            drawToolCrosshair(in: context, tool: tool, color: color, highContrast: highContrast)
        case let .textCaret(highContrast):
            drawPointerTextCaret(in: context, highContrast: highContrast)
        case .hidden:
            break
        }

        if isSelectingRegion {
            drawRegionSelection(in: context)
        }

    }

    override func mouseMoved(with event: NSEvent) {
        pointerViewPoint = convert(event.locationInWindow, from: nil)
        if interactionMode == .typing {
            postTypingCursorAnchorOffset = nil
            // The caret follows the mouse until the first character is typed,
            // then locks in place, matching ZoomIt.
            if !annotationController.isTypingLocked {
                let insertion = contentPoint(forViewPoint: pointerViewPoint)
                annotationController.setInsertionPoint(insertion)
                textEditingSession.updateFrame(textEditingFrame())
            }
        } else if !isDrawingMode {
            updateLatestCursorLocationFromMouse()
        }
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        // Some devices/contexts deliver a right-click over this overlay as a
        // leftMouseDown carrying buttonNumber 1 (the secondary button) rather
        // than a rightMouseDown. Route the secondary button to the right-click
        // handler so it still exits drawing mode.
        if event.buttonNumber == 1 {
            rightMouseDown(with: event)
            return
        }
        pointerViewPoint = convert(event.locationInWindow, from: nil)

        if isSelectingRegion {
            regionAnchor = pointerViewPoint
            regionRect = .zero
            needsDisplay = true
            return
        }

        if interactionMode == .typing {
            if annotationController.isTypingLocked {
                startNewTypingSession(
                    at: contentPoint(for: event),
                    viewPoint: pointerViewPoint
                )
                needsDisplay = true
                return
            }
            annotationController.setInsertionPoint(contentPoint(for: event))
            textEditingSession.updateFrame(textEditingFrame())
            needsDisplay = true
            return
        }

        guard isDrawingMode else {
            // In live zoom, clicking must not enter drawing mode; the user
            // explicitly enters it with the draw hotkey (Control+1/Control+2).
            if interactionMode == .liveZoom {
                return
            }
            // The first press only arms drawing mode and shows the pen cursor;
            // it does not begin a stroke.
            enterDrawingMode()
            needsDisplay = true
            return
        }

        let tool = gestureTool(for: event) ?? annotationController.currentTool
        let point = contentPoint(for: event)
        annotationController.setInsertionPoint(point)
        annotationController.begin(at: point, tool: tool)
        isStroking = true
        activeStrokeTool = tool
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        pointerViewPoint = convert(event.locationInWindow, from: nil)
        if isSelectingRegion {
            updateRegionRect(to: pointerViewPoint)
            needsDisplay = true
            return
        }
        if isDrawingMode && isStroking {
            annotationController.update(at: contentPoint(for: event))
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if event.buttonNumber == 1 {
            rightMouseUp(with: event)
            return
        }
        pointerViewPoint = convert(event.locationInWindow, from: nil)
        if isSelectingRegion {
            finishRegionSnip()
            return
        }
        if isDrawingMode && isStroking {
            annotationController.end(at: contentPoint(for: event))
            isStroking = false
            activeStrokeTool = nil
        }
        needsDisplay = true
    }

    override func rightMouseDown(with event: NSEvent) {
        pointerViewPoint = convert(event.locationInWindow, from: nil)
        if interactionMode == .typing {
            if annotationController.isTypingLocked {
                finishLockedTypingAtCaret(reason: "right mouse locked")
            } else {
                // Caret mode with nothing typed yet: return to pan/zoom mode.
                commandSink(.toggleTyping(rightAligned: false))
            }
            needsDisplay = true
            return
        }

        if isDrawingMode {
            // Right click leaves drawing mode and returns to the current
            // overlay mode; it does not exit ZoomIt.
            leaveDrawingModeFromRightClick()
            return
        }
        // Right click no longer exits the overlay; use Esc or zoom out to 1x.
    }

    override func rightMouseUp(with event: NSEvent) {
        pointerViewPoint = convert(event.locationInWindow, from: nil)
        leaveDrawingModeFromRightClick()
    }

    override func otherMouseDown(with event: NSEvent) {
        pointerViewPoint = convert(event.locationInWindow, from: nil)
        leaveDrawingModeFromRightClick()
    }

    override func otherMouseUp(with event: NSEvent) {
        pointerViewPoint = convert(event.locationInWindow, from: nil)
        leaveDrawingModeFromRightClick()
    }

    override func scrollWheel(with event: NSEvent) {
        if interactionMode == .typing {
            if event.scrollingDeltaY > 0 {
                commandSink(.increaseFontSize)
            } else if event.scrollingDeltaY < 0 {
                commandSink(.decreaseFontSize)
            }
            updateTextEditingFont()
            needsDisplay = true
            return
        }

        if isDrawingMode {
            if event.scrollingDeltaY > 0 {
                commandSink(.increasePenWidth)
            } else if event.scrollingDeltaY < 0 {
                commandSink(.decreasePenWidth)
            }
            needsDisplay = true
            return
        }

        handleZoomScroll(
            delta: event.scrollingDeltaY,
            isPrecise: event.hasPreciseScrollingDeltas
        )
    }

    private func handleZoomScroll(delta: CGFloat, isPrecise: Bool) {
        guard delta != 0 else { return }
        commandSink(
            .adjustZoomFromScroll(
                scrollingDeltaY: delta,
                isPrecise: isPrecise
            )
        )
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        if isSelectingRegion {
            // Only Escape (cancel) is honoured while selecting a snip region.
            if event.keyCode == 53 {
                cancelRegionSnip()
            }
            return
        }
        if interactionMode == .typing {
            textEditingSession.inputClient.interpretKeyEvents([event])
            return
        }
        switch event.keyCode {
        case 53:
            // Esc leaves typing mode first (matching ZoomIt). In live-zoom
            // drawing it leaves drawing mode but stays in live zoom; otherwise
            // it exits the overlay.
            if interactionMode == .liveZoom && isDrawingMode {
                exitDrawingMode()
                needsDisplay = true
            } else {
                commandSink(.exit)
            }
        case 48:
            // Swallow Tab so it never beeps; the ellipse gesture reads the live
            // Tab key state at stroke start instead.
            break
        case 126:
            handleVerticalArrow(up: true, shift: event.modifierFlags.contains(.shift))
        case 125:
            handleVerticalArrow(up: false, shift: event.modifierFlags.contains(.shift))
        case 6 where event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control):
            // ⌘Z (macOS convention) or Ctrl+Z (matching Windows ZoomIt) undoes the last gesture.
            commandSink(.undo)
        case 1 where event.modifierFlags.contains(.command):
            // ⌘S saves the whole zoomed viewport (matching ZoomIt's Ctrl+S).
            saveViewport()
        case 8 where event.modifierFlags.contains(.command):
            // ⌘C copies the whole zoomed viewport (matching ZoomIt's Ctrl+C).
            copyViewport()
        default:
            handleDrawingShortcut(event) ?? interpretKeyEvents([event])
        }
    }

    private func beginTextEditingSession() {
        let font = currentTextEditingFont()
        annotationController.isTypingDraftPresentedByNativeEditor = true
        textEditingSession.begin(
            in: self,
            frame: textEditingFrame(font: font),
            font: font,
            color: annotationController.currentStyle.color.nsColor,
            alignment: annotationController.typingRightAligned ? .right : .left
        )
    }

    private func textEditingFrame(font explicitFont: NSFont? = nil) -> CGRect {
        let source = viewportController.sourceRect(for: bounds, cursorLocation: latestCursorLocation)
        let zoomScale = source.width > 0 ? bounds.width / source.width : 1
        let font = explicitFont ?? AnnotationController.typingFont(
            named: annotationController.typingFontName,
            size: annotationController.typingFontSize * zoomScale
        )
        let rightAligned = annotationController.typingRightAligned
        let x = rightAligned ? 0 : max(0, pointerViewPoint.x)
        let width = rightAligned
            ? max(1, pointerViewPoint.x)
            : max(1, bounds.maxX - pointerViewPoint.x)
        let lineHeight = font.ascender - font.descender + font.leading
        return CGRect(
            x: x,
            y: max(0, pointerViewPoint.y),
            width: width,
            height: max(lineHeight * 2, bounds.maxY - pointerViewPoint.y)
        )
    }

    private func updateTextEditingFont() {
        guard textEditingSession.isActive else { return }
        let font = currentTextEditingFont()
        textEditingSession.updateFont(font)
        textEditingSession.updateFrame(textEditingFrame(font: font))
    }

    private func currentTextEditingFont() -> NSFont {
        let source = viewportController.sourceRect(for: bounds, cursorLocation: latestCursorLocation)
        let zoomScale = source.width > 0 ? bounds.width / source.width : 1
        return AnnotationController.typingFont(
            named: annotationController.typingFontName,
            size: annotationController.typingFontSize * zoomScale
        )
    }

    private func endTextEditingSession() {
        guard textEditingSession.isActive else { return }
        let committedText = textEditingSession.finish()
        annotationController.isTypingDraftPresentedByNativeEditor = false
        annotationController.replaceTypingText(committedText)
        window?.makeFirstResponder(self)
    }

    private func startNewTypingSession(at contentPoint: CGPoint, viewPoint: CGPoint) {
        endTextEditingSession()
        pointerViewPoint = viewPoint
        annotationController.setInsertionPoint(contentPoint)
        beginTextEditingSession()
    }

    private func handleDrawingShortcut(_ event: NSEvent) -> Void? {
        guard let shortcut = Self.drawingShortcut(for: event) else { return nil }
        guard let command = DrawingShortcutCommandPolicy.command(for: shortcut) else { return nil }

        commandSink(command)
        needsDisplay = true
        return ()
    }

    static func drawingShortcut(for event: NSEvent) -> DrawingShortcut? {
        guard let key = event.charactersIgnoringModifiers?.lowercased(), !key.isEmpty else {
            return nil
        }

        var modifiers: Set<KeyboardModifier> = []
        if event.modifierFlags.contains(.shift) {
            modifiers.insert(.shift)
        }
        if event.modifierFlags.contains(.control) {
            modifiers.insert(.control)
        }
        if event.modifierFlags.contains(.command) {
            modifiers.insert(.command)
        }
        return DrawingShortcut(key: key, modifiers: modifiers)
    }

    private func drawTypingCaret(in context: CGContext, source: CGRect) {
        guard let caret = annotationController.typingCaret() else { return }
        let color = annotationController.currentStyle.color.nsColor
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(max(1, caret.height * 0.06))
        context.setLineCap(.butt)
        context.beginPath()
        context.move(to: caret.origin)
        context.addLine(to: CGPoint(x: caret.origin.x, y: caret.origin.y + caret.height))
        context.strokePath()
    }

    private func contentPoint(for event: NSEvent) -> CGPoint {
        let viewPoint = convert(event.locationInWindow, from: nil)
        return contentPoint(forViewPoint: viewPoint)
    }

    private func contentPoint(forViewPoint viewPoint: CGPoint) -> CGPoint {
        viewportController.contentPoint(for: viewPoint, destinationBounds: bounds, cursorLocation: latestCursorLocation)
    }

    /// Maps a held modifier (or Tab) at stroke start to a ZoomIt shape gesture:
    /// Ctrl = rectangle, Shift = line, Ctrl+Shift = arrow, Tab = ellipse.
    private func gestureTool(for event: NSEvent) -> AnnotationTool? {
        let modifiers = event.modifierFlags
        let shift = modifiers.contains(.shift)
        let control = modifiers.contains(.control)
        if control && shift { return .arrow }
        if control { return .rectangle }
        if shift { return .line }
        if tabKeyIsDown() { return .ellipse }
        return nil
    }

    private func tabKeyIsDown() -> Bool {
        // Query the live keyboard state so a missed key-up can never leave us
        // stuck in the ellipse gesture. 0x30 is the Tab virtual key code.
        CGEventSource.keyState(.combinedSessionState, key: 0x30)
    }

    private func handleVerticalArrow(up: Bool, shift: Bool) {
        if shift {
            commandSink(up ? .increasePenWidth : .decreasePenWidth)
        } else {
            commandSink(up ? .zoomIn : .zoomOut)
        }
        needsDisplay = true
    }

    private func enterDrawingMode() {
        guard !isDrawingMode else { return }
        isDrawingMode = true
        isStroking = false
        startDrawingRightClickMonitor()
        updateLiveZoomInteractivity()
    }

    private func exitDrawingMode(restoreCursor: Bool = true) {
        guard isDrawingMode else { return }
        isDrawingMode = false
        isStroking = false
        activeStrokeTool = nil
        stopDrawingRightClickMonitor()
        // Keep the zoom anchored where it was while drawing. The physical mouse
        // moved around the screen while drawing, so warp the (hidden) system
        // cursor back to the frozen anchor. This keeps panning continuous and
        // prevents the view from jumping when leaving drawing mode.
        if restoreCursor, let anchor = latestCursorLocation {
            warpCursor(toGlobal: anchor)
        }
        updateLiveZoomInteractivity()
    }

    private func leaveDrawingModeFromRightClick() {
        guard isDrawingMode else { return }
        if isStroking {
            annotationController.end(at: contentPoint(forViewPoint: pointerViewPoint))
        }
        exitDrawingMode()
        needsDisplay = true
    }

    private func startDrawingRightClickMonitor() {
        guard drawingRightClickMonitor == nil else { return }
        drawingRightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp]) { [weak self] event in
            let windowNumber = event.window?.windowNumber
            let location = event.locationInWindow
            let handled = MainActor.assumeIsolated { () -> Bool in
                self?.handleDrawingRightClick(windowNumber: windowNumber, locationInWindow: location) ?? false
            }
            return handled ? nil : event
        }
        drawingGlobalRightClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp]) { [weak self] _ in
            MainActor.assumeIsolated {
                _ = self?.handleDrawingRightClick(windowNumber: nil, locationInWindow: nil)
            }
        }
    }

    private func handleDrawingRightClick(windowNumber: Int?, locationInWindow: CGPoint?) -> Bool {
        guard isDrawingMode else { return false }
        if let locationInWindow, windowNumber == window?.windowNumber {
            pointerViewPoint = convert(locationInWindow, from: nil)
        } else {
            syncPointerViewPointFromMouse()
        }
        leaveDrawingModeFromRightClick()
        return true
    }

    private func stopDrawingRightClickMonitor() {
        if let drawingRightClickMonitor {
            NSEvent.removeMonitor(drawingRightClickMonitor)
        }
        drawingRightClickMonitor = nil
        if let drawingGlobalRightClickMonitor {
            NSEvent.removeMonitor(drawingGlobalRightClickMonitor)
        }
        drawingGlobalRightClickMonitor = nil
    }

    /// When typing mode ends, keep the system cursor at the last mouse position
    /// tracked while typing, or at the text caret once text has locked it.
    private func anchorCursorAfterTyping() {
        if annotationController.isTypingLocked, let caret = annotationController.typingCaret() {
            anchorCursor(toContentPoint: caret.origin, reason: "anchor after typing caret")
            return
        }
        syncPointerViewPointFromMouse()
        latestCursorLocation = NSEvent.mouseLocation
    }

    private func finishLockedTypingAtCaret(reason: String) {
        let insertion = annotationController.typingCaret()?.origin ?? contentPoint(forViewPoint: pointerViewPoint)
        endTextEditingSession()
        anchorCursor(toContentPoint: insertion, reason: reason)
        annotationController.setInsertionPoint(insertion)
        beginTextEditingSession()
    }

    private func anchorCursor(toContentPoint point: CGPoint, reason: String) {
        let source = viewportController.sourceRect(for: bounds, cursorLocation: latestCursorLocation)
        pointerViewPoint = viewPoint(forContentPoint: point, source: source)
        if let global = screenLocation(forViewPoint: pointerViewPoint) {
            warpCursor(toGlobal: global)
            if interactionMode == .drawOnly {
                latestCursorLocation = global
                postTypingCursorAnchorOffset = nil
            } else if let anchor = latestCursorLocation {
                postTypingCursorAnchorOffset = CGPoint(x: anchor.x - global.x, y: anchor.y - global.y)
            }
        }
    }

    private func updateLatestCursorLocationFromMouse() {
        let mouse = NSEvent.mouseLocation
        if let offset = postTypingCursorAnchorOffset {
            latestCursorLocation = CGPoint(x: mouse.x + offset.x, y: mouse.y + offset.y)
        } else {
            latestCursorLocation = mouse
        }
    }

    private func syncPointerViewPointFromMouse() {
        guard let window else { return }
        let windowPoint = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        pointerViewPoint = convert(windowPoint, from: nil)
    }

    private func warpCursor(toGlobal point: CGPoint) {
        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return }
        // NSEvent.mouseLocation uses a bottom-left origin on the primary screen;
        // CGWarpMouseCursorPosition expects a top-left origin, so flip Y.
        CGWarpMouseCursorPosition(CGPoint(x: point.x, y: primaryHeight - point.y))
    }

    private func viewPoint(forContentPoint point: CGPoint, source: CGRect) -> CGPoint {
        CGPoint(
            x: ((point.x - source.minX) / source.width) * bounds.width,
            y: ((point.y - source.minY) / source.height) * bounds.height
        )
    }

    private func screenLocation(forViewPoint viewPoint: CGPoint) -> CGPoint? {
        guard let window else { return nil }
        let windowPoint = convert(viewPoint, to: nil)
        return window.convertPoint(toScreen: windowPoint)
    }

    private func hideSystemCursor() {
        guard !cursorHidden else { return }
        NSCursor.hide()
        cursorHidden = true
    }

    private func showSystemCursor() {
        guard cursorHidden else { return }
        NSCursor.unhide()
        cursorHidden = false
    }

    func prepareForClose() {
        endTextEditingSession()
        stopLiveMouseTracking()
        stopDrawingRightClickMonitor()
        showSystemCursor()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Keep the system cursor hidden the whole time the overlay is on screen so
        // it is invisible while panning and drawing; the pen indicator is drawn
        // separately in drawing mode.
        if window != nil {
            syncPointerViewPointFromMouse()
            hideSystemCursor()
            updateLiveZoomInteractivity()
        } else {
            stopLiveMouseTracking()
            stopDrawingRightClickMonitor()
            showSystemCursor()
        }
    }

    private func updateLiveZoomInteractivity() {
        guard let window else { return }
        let presentation = LiveZoomInteractionPolicy.presentation(
            interactionMode: interactionMode,
            isDrawingMode: isDrawingMode,
            isSelectingRegion: isSelectingRegion
        )
        let interactive = presentation.mouseRouting == .passThroughToUnderlyingApp
        guard interactive != liveZoomClickThrough else { return }
        liveZoomClickThrough = interactive
        switch presentation.mouseRouting {
        case .passThroughToUnderlyingApp:
            // Pass mouse events through to the apps underneath and show the real
            // cursor; a global monitor keeps the magnified view tracking it and
            // routes wheel/trackpad scrolling back into the zoom controller.
            window.ignoresMouseEvents = true
            showSystemCursor()
            startLiveMouseTracking(events: presentation.globalTrackingEvents)
        case .captureInOverlay:
            // Reclaim input so the overlay can draw/pan modally.
            stopLiveMouseTracking()
            window.ignoresMouseEvents = false
            hideSystemCursor()
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(self)
        }
    }

    private func startLiveMouseTracking(events: [LiveZoomGlobalTrackingEvent]) {
        guard liveMouseMonitor == nil else { return }
        var eventMask: NSEvent.EventTypeMask = []
        if events.contains(.pointerMovement) {
            eventMask.formUnion([
                .mouseMoved,
                .leftMouseDragged,
                .rightMouseDragged,
                .otherMouseDragged
            ])
        }
        if events.contains(.scrollWheel) {
            eventMask.insert(.scrollWheel)
        }
        guard !eventMask.isEmpty else { return }

        liveMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: eventMask
        ) { [weak self] event in
            MainActor.assumeIsolated {
                if event.type == .scrollWheel {
                    self?.handleZoomScroll(
                        delta: event.scrollingDeltaY,
                        isPrecise: event.hasPreciseScrollingDeltas
                    )
                } else {
                    self?.handleGlobalMouseMove()
                }
            }
        }
    }

    private func stopLiveMouseTracking() {
        if let liveMouseMonitor {
            NSEvent.removeMonitor(liveMouseMonitor)
        }
        liveMouseMonitor = nil
    }

    private func handleGlobalMouseMove() {
        // Follow the real cursor so the magnified region recenters on it. The
        // source-rect math anchors the point under the cursor to itself, so the
        // content beneath the cursor stays aligned for accurate clicks.
        latestCursorLocation = NSEvent.mouseLocation
        needsDisplay = true
    }

    /// Renders the current viewport (magnified image plus annotations) to a
    /// bitmap and copies it to the clipboard.
    private func copyViewport() {
        guard let image = captureViewportImage() else { return }
        let changeCount = ImageExporter.copyToPasteboard(image)
        onPasteboardOutput?(.image(changeCount: changeCount))
    }

    /// Renders the current viewport and presents a Save dialog to write it as
    /// PNG.
    private func saveViewport() {
        guard let image = captureViewportImage() else { return }
        presentSavePanelOverOverlay(image)
    }

    /// Presents a Save dialog above the overlay (whose `.screenSaver` level would
    /// otherwise hide it) with the cursor visible, then restores both. Honors the
    /// snip preferences: also copies to the clipboard when configured, and writes
    /// directly to the configured directory instead of showing a dialog.
    private func presentSavePanelOverOverlay(_ image: CGImage) {
        let settings = UserDefaultsSettingsStore().load()
        if settings.copySnipToClipboardOnSave {
            ImageExporter.copyToPasteboard(image)
        }
        if settings.saveSnipToDirectory {
            ImageExporter.writeToDirectory(image, directoryPath: settings.snipSaveDirectory)
            return
        }
        let savedLevel = window?.level
        let wasCursorHidden = cursorHidden
        window?.level = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue - 1)
        if wasCursorHidden { showSystemCursor() }
        ImageExporter.presentSavePanel(for: image)
        if let savedLevel { window?.level = savedLevel }
        if wasCursorHidden { hideSystemCursor() }
    }

    private func presentSavePanelOnlyOverOverlay(_ image: CGImage) {
        let savedLevel = window?.level
        let wasCursorHidden = cursorHidden
        window?.level = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue - 1)
        if wasCursorHidden { showSystemCursor() }
        ImageExporter.presentSavePanel(for: image)
        if let savedLevel { window?.level = savedLevel }
        if wasCursorHidden { hideSystemCursor() }
    }

    /// Snapshots exactly what the overlay is displaying (magnified image plus
    /// annotations) at the view's backing resolution.
    private func captureViewportImage() -> CGImage? {
        let nativeEditorWasActive = textEditingSession.isActive
        if nativeEditorWasActive {
            textEditingSession.inputClient.isHidden = true
            annotationController.isTypingDraftPresentedByNativeEditor = false
        }
        isCapturingPrivacyBase = true
        defer {
            isCapturingPrivacyBase = false
            if nativeEditorWasActive {
                annotationController.isTypingDraftPresentedByNativeEditor = true
                textEditingSession.inputClient.isHidden = false
            }
            needsDisplay = true
        }
        guard let rep = bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
        cacheDisplay(in: bounds, to: rep)
        guard let baseImage = rep.cgImage else { return nil }
        let privacyOperations = annotationController.privacyRenderPlanSnapshot
        guard !privacyOperations.isEmpty else { return baseImage }

        let source = viewportController.sourceRect(for: bounds, cursorLocation: latestCursorLocation)
        let contentToView = viewportController.contentToDestinationTransform(
            source: source,
            destinationBounds: bounds
        )
        let viewToImage = CGAffineTransform(
            a: CGFloat(baseImage.width) / bounds.width,
            b: 0,
            c: 0,
            d: CGFloat(baseImage.height) / bounds.height,
            tx: -bounds.minX * CGFloat(baseImage.width) / bounds.width,
            ty: -bounds.minY * CGFloat(baseImage.height) / bounds.height
        )
        return PrivacyAnnotationCompositor.composite(
            source: baseImage,
            operations: privacyOperations,
            contentToImageTransform: contentToView.concatenating(viewToImage)
        )
    }

    /// Snapshots the visible overlay for the recorder. `sourceRect` is a region
    /// recording crop in display points with a top-left origin.
    func captureRecordingImage(sourceRect: CGRect?) -> CGImage? {
        displayIfNeeded()
        guard let image = captureViewportImage() else { return nil }
        guard let sourceRect else { return image }

        let scale = window?.backingScaleFactor ?? capturedFrame.display.scaleFactor
        let pixelRect = CGRect(
            x: sourceRect.minX * scale,
            y: sourceRect.minY * scale,
            width: sourceRect.width * scale,
            height: sourceRect.height * scale
        ).integral
        return image.cropping(to: pixelRect)
    }

    // MARK: - Region snip

    /// Begins selecting a rectangle of the current viewport to copy or save.
    func beginRegionSnip(
        action: SnipAction,
        onPasteboardOutput: ((SnipPasteboardOutput) -> Void)? = nil,
        onFinished: @escaping () -> Void
    ) {
        regionAction = action
        onRegionSnipFinished = onFinished
        onRegionPasteboardOutput = onPasteboardOutput
        regionAnchor = nil
        regionRect = .zero
        isSelectingRegion = true
        // In live zoom this drops click-through so the canvas captures the drag.
        if interactionMode == .liveZoom {
            updateLiveZoomInteractivity()
        }
        showSystemCursor()
        pushRegionCursor()
        needsDisplay = true
    }

    private func updateRegionRect(to point: CGPoint) {
        guard let anchor = regionAnchor else { return }
        regionRect = CGRect(
            x: min(anchor.x, point.x),
            y: min(anchor.y, point.y),
            width: abs(point.x - anchor.x),
            height: abs(point.y - anchor.y)
        )
    }

    private func finishRegionSnip() {
        let rect = regionRect
        let action = regionAction
        isSelectingRegion = false
        regionRect = .zero
        regionAnchor = nil
        popRegionCursor()

        if rect.width >= 3, rect.height >= 3, let full = captureViewportImage() {
            let scale = window?.backingScaleFactor ?? capturedFrame.display.scaleFactor
            let pixelRect = CGRect(
                x: rect.minX * scale,
                y: rect.minY * scale,
                width: rect.width * scale,
                height: rect.height * scale
            ).integral
            if let cropped = full.cropping(to: pixelRect) {
                let outputHandler = onRegionPasteboardOutput
                let settings = UserDefaultsSettingsStore().load()
                let executor = SnipExportExecutor<CGImage>(
                    copyToPasteboard: { ImageExporter.copyToPasteboard($0) },
                    writeToDirectory: { ImageExporter.writeToDirectory($0, directoryPath: settings.snipSaveDirectory) },
                    presentSavePanel: { [weak self] in self?.presentSavePanelOnlyOverOverlay($0) },
                    copyOCR: { OcrService.recognizeAndCopy($0, completion: $1) }
                )
                executor.execute(
                    image: cropped,
                    operations: SnipExportPlan.operations(for: action, settings: settings),
                    onPasteboardOutput: { outputHandler?($0) }
                )
            }
        }
        endRegionSnip()
    }

    private func cancelRegionSnip() {
        isSelectingRegion = false
        regionRect = .zero
        regionAnchor = nil
        popRegionCursor()
        endRegionSnip()
    }

    private func endRegionSnip() {
        needsDisplay = true
        if interactionMode == .liveZoom {
            updateLiveZoomInteractivity()
        } else {
            hideSystemCursor()
        }
        let callback = onRegionSnipFinished
        onRegionSnipFinished = nil
        onRegionPasteboardOutput = nil
        callback?()
    }

    private func pushRegionCursor() {
        guard regionCursorLease == nil, let window else { return }
        let cursorLease = CrosshairCursorLease(window: window, purpose: regionAction.pointerPurpose)
        cursorLease.activate()
        regionCursorLease = cursorLease
    }

    private func popRegionCursor() {
        regionCursorLease?.invalidate()
        regionCursorLease = nil
    }

    private func drawRegionSelection(in context: CGContext) {
        let dim = NSColor(white: 0, alpha: 0.45).cgColor
        context.setFillColor(dim)
        guard regionRect.width > 0, regionRect.height > 0 else {
            context.fill(bounds)
            return
        }
        // Dim everything except the selected region (four surrounding rects).
        let b = bounds
        context.fill(CGRect(x: 0, y: 0, width: b.width, height: regionRect.minY))
        context.fill(CGRect(x: 0, y: regionRect.maxY, width: b.width, height: b.height - regionRect.maxY))
        context.fill(CGRect(x: 0, y: regionRect.minY, width: regionRect.minX, height: regionRect.height))
        context.fill(CGRect(x: regionRect.maxX, y: regionRect.minY, width: b.width - regionRect.maxX, height: regionRect.height))

        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(1)
        context.stroke(regionRect.insetBy(dx: 0.5, dy: 0.5))
        drawRegionSelectionFeedback()
    }

    private func drawRegionSelectionFeedback() {
        guard let feedback = RegionSelectionFeedback.presentation(
            selection: regionRect,
            scale: window?.backingScaleFactor ?? capturedFrame.display.scaleFactor,
            container: bounds
        ) else { return }

        NSColor(white: 0, alpha: 0.72).setFill()
        NSBezierPath(roundedRect: feedback.frame, xRadius: 4, yRadius: 4).fill()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        NSString(string: feedback.text).draw(
            in: feedback.frame.insetBy(dx: 8, dy: 3),
            withAttributes: attributes
        )
    }

    private func drawPenRing(
        in context: CGContext,
        source: CGRect,
        color: AnnotationColor,
        diameter: CGFloat,
        highContrast: Bool
    ) {
        let zoomScale = source.width > 0 ? bounds.width / source.width : 1
        let radius = max(4, diameter * zoomScale / 2)
        let center = pointerViewPoint
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)

        context.saveGState()
        context.setLineWidth(highContrast ? 4 : 3)
        context.setStrokeColor(highContrast ? NSColor.labelColor.cgColor : NSColor(white: 0, alpha: 0.78).cgColor)
        context.strokeEllipse(in: rect)
        context.setLineWidth(2)
        context.setStrokeColor(color.nsColor.cgColor)
        context.strokeEllipse(in: rect)
        context.restoreGState()
    }

    private func drawHighlighterNib(
        in context: CGContext,
        source: CGRect,
        color: AnnotationColor,
        width: CGFloat,
        highContrast: Bool
    ) {
        let zoomScale = source.width > 0 ? bounds.width / source.width : 1
        let nibWidth = max(10, width * zoomScale * 1.8)
        let nibHeight = max(4, width * zoomScale * 0.55)
        let rect = CGRect(
            x: pointerViewPoint.x - nibWidth / 2,
            y: pointerViewPoint.y - nibHeight / 2,
            width: nibWidth,
            height: nibHeight
        )
        context.saveGState()
        context.setFillColor(color.nsColor.withAlphaComponent(0.5).cgColor)
        context.fill(rect)
        context.setLineWidth(highContrast ? 2 : 1)
        context.setStrokeColor(highContrast ? NSColor.labelColor.cgColor : color.nsColor.cgColor)
        context.stroke(rect)
        context.restoreGState()
    }

    private func drawToolCrosshair(
        in context: CGContext,
        tool: AnnotationTool,
        color: AnnotationColor,
        highContrast: Bool
    ) {
        let center = pointerViewPoint
        let length: CGFloat = 9
        context.saveGState()
        context.setLineCap(.round)
        context.setLineWidth(highContrast ? 4 : 3)
        context.setStrokeColor(highContrast ? NSColor.labelColor.cgColor : NSColor(white: 0, alpha: 0.78).cgColor)
        context.move(to: CGPoint(x: center.x - length, y: center.y))
        context.addLine(to: CGPoint(x: center.x + length, y: center.y))
        context.move(to: CGPoint(x: center.x, y: center.y - length))
        context.addLine(to: CGPoint(x: center.x, y: center.y + length))
        context.strokePath()
        context.setLineWidth(1.5)
        context.setStrokeColor(color.nsColor.cgColor)
        drawToolBadge(
            tool,
            color: color,
            origin: CGPoint(x: center.x + 7, y: center.y + 7),
            in: context
        )
        context.restoreGState()
    }

    private func drawToolBadge(
        _ tool: AnnotationTool,
        color: AnnotationColor,
        origin: CGPoint,
        in context: CGContext
    ) {
        let rect = CGRect(x: origin.x, y: origin.y, width: 10, height: 8)
        switch tool {
        case .line:
            context.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            context.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        case .rectangle:
            context.addRect(rect)
        case .ellipse:
            context.addEllipse(in: rect)
        case .arrow:
            context.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            context.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            context.move(to: CGPoint(x: rect.maxX - 4, y: rect.minY))
            context.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            context.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + 4))
        case .blur:
            context.addEllipse(in: rect.insetBy(dx: 1, dy: 1))
            context.move(to: CGPoint(x: rect.minX + 2, y: rect.midY))
            context.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.midY))
        case .redact:
            context.addRect(rect)
            context.saveGState()
            context.setFillColor(NSColor.black.cgColor)
            context.fill(rect.insetBy(dx: 1, dy: 1))
            context.restoreGState()
        case .numberedCallout:
            context.addEllipse(in: rect)
            let number = NSString(string: "1")
            number.draw(
                at: CGPoint(x: rect.midX - 2.5, y: rect.midY - 4.5),
                withAttributes: [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 7, weight: .bold),
                    .foregroundColor: color.nsColor
                ]
            )
        default:
            return
        }
        context.strokePath()
    }

    private func drawPointerTextCaret(in context: CGContext, highContrast: Bool) {
        let center = pointerViewPoint
        context.saveGState()
        context.setLineWidth(highContrast ? 3 : 2)
        context.setStrokeColor(highContrast ? NSColor.labelColor.cgColor : NSColor.white.cgColor)
        context.move(to: CGPoint(x: center.x, y: center.y - 9))
        context.addLine(to: CGPoint(x: center.x, y: center.y + 9))
        context.strokePath()
        context.restoreGState()
    }

    private func drawZoomPointerIndicator(in context: CGContext) {
        let center = pointerViewPoint
        let length: CGFloat = 9
        let radius: CGFloat = 3

        context.saveGState()
        context.setLineCap(.round)
        context.setLineWidth(3)
        context.setStrokeColor(NSColor(white: 0, alpha: 0.78).cgColor)
        strokeZoomPointer(center: center, length: length, radius: radius, in: context)
        context.setLineWidth(1.4)
        context.setStrokeColor(NSColor.white.cgColor)
        strokeZoomPointer(center: center, length: length, radius: radius, in: context)
        context.restoreGState()
    }

    private func strokeZoomPointer(center: CGPoint, length: CGFloat, radius: CGFloat, in context: CGContext) {
        context.strokeEllipse(in: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        context.move(to: CGPoint(x: center.x - length, y: center.y))
        context.addLine(to: CGPoint(x: center.x - radius - 2, y: center.y))
        context.move(to: CGPoint(x: center.x + radius + 2, y: center.y))
        context.addLine(to: CGPoint(x: center.x + length, y: center.y))
        context.move(to: CGPoint(x: center.x, y: center.y - length))
        context.addLine(to: CGPoint(x: center.x, y: center.y - radius - 2))
        context.move(to: CGPoint(x: center.x, y: center.y + radius + 2))
        context.addLine(to: CGPoint(x: center.x, y: center.y + length))
        context.strokePath()
    }
}
