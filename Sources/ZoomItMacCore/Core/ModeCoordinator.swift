import AppKit

@MainActor
final class ModeCoordinator {
    private let settingsStore: SettingsStore
    private let permissionService: PermissionService
    private let displayManager: DisplayManager
    private let captureService: ScreenCaptureService
    private let windowCaptureService: WindowCaptureService
    private let overlayController: OverlayWindowController
    private let annotationController: AnnotationController
    private let viewportController: ZoomViewportController
    private let feedbackAdapter: FeedbackPresentationAdapter
    private let pasteCompatibilityCoordinator: PasteCompatibilityCoordinator
    private let permissionRelaunchCoordinator: PermissionRelaunchCoordinator?
    private let screenRecordingPermissionSession: ScreenRecordingPermissionSession
    private let recordingRecoveryStore: RecordingRecoveryStoring

    private(set) var mode: AppMode = .idle {
        didSet {
            let wasTextEditing = oldValue == .typing
            let isTextEditing = mode == .typing
            guard wasTextEditing != isTextEditing else { return }
            pasteCompatibilityCoordinator.setTextEditingActive(isTextEditing)
            onTextEditingStateChanged?(isTextEditing)
        }
    }
    private var isExiting = false
    /// The mode to restore when leaving typing mode (zoom vs. draw-without-zoom).
    private var modeBeforeTyping: AppMode = .staticZoom
    /// The live screen-capture stream that feeds frames while in live zoom.
    private var liveCaptureSession: LiveCaptureSession?
    /// Drives the region snip (Control+6 / Control+Shift+6).
    private lazy var snipController = SnipController(
        captureService: captureService,
        displayManager: displayManager,
        permissionService: permissionService,
        settingsStore: settingsStore,
        permissionRelaunchCoordinator: permissionRelaunchCoordinator,
        screenRecordingPermissionSession: screenRecordingPermissionSession,
        windowCaptureService: windowCaptureService,
        onPasteboardOutput: { [weak self] output in
            self?.handleSnipPasteboardOutput(output)
        }
    )
    private var isSnipping = false
    /// Drives screen recording (Control+5 / Control+Shift+5).
    private lazy var recordingController = RecordingController(
        captureService: captureService,
        displayManager: displayManager,
        permissionService: permissionService,
        settingsStore: settingsStore,
        permissionRelaunchCoordinator: permissionRelaunchCoordinator,
        screenRecordingPermissionSession: screenRecordingPermissionSession,
        preflightProvider: SystemRecordingPreflightProvider(permissionService: permissionService),
        preflightWindowController: RecordingPreflightWindowController(),
        recoveryStore: recordingRecoveryStore
    )
    /// Drives panorama (scrolling) capture (Control+8 / Control+Shift+8).
    private lazy var panoramaController = PanoramaController(
        displayManager: displayManager,
        permissionService: permissionService,
        settingsStore: settingsStore,
        permissionRelaunchCoordinator: permissionRelaunchCoordinator,
        screenRecordingPermissionSession: screenRecordingPermissionSession
    )
    /// Drives DemoType text synthesis from a file or [start]-prefixed clipboard.
    private lazy var demoTypeController = DemoTypeController(settingsStore: settingsStore)
        /// Drives the full-screen break timer (Control+3).
        private lazy var breakTimerController = BreakTimerController(
            displayManager: displayManager,
            captureService: captureService,
            settingsStore: settingsStore
        )
    /// Notified when recording starts/stops so the UI (menu-bar icon) can react.
    var onRecordingStateChanged: ((Bool) -> Void)?
    /// Invoked when live zoom starts/stops so global Control+Up/Down zoom
    /// hotkeys can be registered only while live zoom is active.
    var onBeginLiveZoomNavigation: (() -> Void)?
    var onEndLiveZoomNavigation: (() -> Void)?
    var onTextEditingStateChanged: ((Bool) -> Void)?

    init(
        settingsStore: SettingsStore,
        permissionService: PermissionService,
        displayManager: DisplayManager,
        captureService: ScreenCaptureService,
        windowCaptureService: WindowCaptureService,
        overlayController: OverlayWindowController,
        annotationController: AnnotationController,
        viewportController: ZoomViewportController,
        feedbackAdapter: FeedbackPresentationAdapter,
        recordingRecoveryStore: RecordingRecoveryStoring,
        permissionRelaunchCoordinator: PermissionRelaunchCoordinator? = nil,
        screenRecordingPermissionSession: ScreenRecordingPermissionSession = ScreenRecordingPermissionSession(),
        pasteCompatibilityCoordinator: PasteCompatibilityCoordinator = PasteCompatibilityCoordinator(
            permissionRequester: SystemInputCompatibilityPermissionRequester()
        )
    ) {
        self.settingsStore = settingsStore
        self.permissionService = permissionService
        self.displayManager = displayManager
        self.captureService = captureService
        self.windowCaptureService = windowCaptureService
        self.overlayController = overlayController
        self.annotationController = annotationController
        self.viewportController = viewportController
        self.feedbackAdapter = feedbackAdapter
        self.recordingRecoveryStore = recordingRecoveryStore
        self.permissionRelaunchCoordinator = permissionRelaunchCoordinator
        self.screenRecordingPermissionSession = screenRecordingPermissionSession
        self.pasteCompatibilityCoordinator = pasteCompatibilityCoordinator
    }

    func handle(_ command: AppCommand) {
        if isSnipping {
            // Ignore activation and snip hotkeys while a region selection is on
            // screen so a second trigger can't stack overlays.
            switch command {
            case .activateStaticZoom, .activateLiveZoom, .activateDrawWithoutZoom, .snipRegion, .snipPreviousRegion, .snipWindowAtPointer, .snipOcr, .zoomIn, .zoomOut, .adjustZoomFromScroll:
                return
            default:
                break
            }
        }

        switch LiveZoomCommandPolicy.effect(mode: mode, command: command) {
        case .toggleDrawingWithinLiveZoom:
            toggleLiveZoomDrawing()
            return
        case .normalCommandHandling:
            break
        }

        switch command {
        case .activateStaticZoom:
            activateStaticZoom()
        case .activateLiveZoom:
            activateLiveZoom()
        case .activateDrawWithoutZoom:
            activateDrawWithoutZoom()
        case .zoomIn:
            zoomIn()
        case .zoomOut:
            zoomOut()
        case let .adjustZoomFromScroll(scrollingDeltaY, isPrecise):
            adjustZoomFromScroll(
                scrollingDeltaY: scrollingDeltaY,
                isPrecise: isPrecise
            )
        case .exit:
            if mode == .breakTimer {
                stopBreakTimer()
            } else {
                animateExit()
            }
        case .undo:
            annotationController.undo()
            overlayController.requestRedraw()
        case .clear:
            annotationController.clear()
            overlayController.requestRedraw()
        case .snipRegion(let save):
            startSnip(action: save ? .saveImage : .copyImage)
        case .snipPreviousRegion:
            startPreviousRegionSnip()
        case .snipWindowAtPointer:
            startWindowSnip()
        case .snipOcr:
            startSnip(action: .recognizeText)
        case .toggleRecording(let region):
            toggleRecording(region: region)
        case .toggleRecordingPause:
            switch recordingController.togglePause() {
            case .pause:
                feedbackAdapter.present(.warning(AppLocalization.string(
                    "recording_feedback.paused",
                    defaultValue: "Recording paused"
                )))
            case .resume:
                feedbackAdapter.present(.warning(AppLocalization.string(
                    "recording_feedback.resumed",
                    defaultValue: "Recording resumed"
                )))
            case .reject:
                break
            }
        case .startPanorama(let save):
            togglePanorama(save: save)
        case .startDemoType:
            demoTypeController.startOrStop()
        case .resetDemoType:
            demoTypeController.reset()
        case .toggleBreakTimer:
            toggleBreakTimer()
        case .setTool(let tool):
            annotationController.currentTool = tool
            if tool == .redact {
                annotationController.currentStyle.color = .black
                annotationController.currentStyle.alpha = 1
            } else if tool == .blur {
                annotationController.currentStyle.alpha = 1
            }
            presentToolFeedback(tool: tool)
        case .setColor(let color):
            annotationController.currentStyle.color = color
            annotationController.currentStyle.alpha = 1
            presentToolFeedback(tool: annotationController.currentTool)
        case .setHighlightColor(let color):
            // Shift+color: translucent highlighter of that color.
            annotationController.currentStyle.color = color
            annotationController.currentStyle.alpha = AnnotationStyle.highlightAlpha
            presentToolFeedback(tool: .highlighter)
        case .setCanvas(let background):
            annotationController.setCanvasBackground(background)
            overlayController.requestRedraw()
            presentToolFeedback(tool: annotationController.currentTool)
        case .increasePenWidth:
            annotationController.currentStyle.rootWidth += 1
            presentToolFeedback(tool: annotationController.currentTool)
        case .decreasePenWidth:
            annotationController.currentStyle.rootWidth = max(1, annotationController.currentStyle.rootWidth - 1)
            presentToolFeedback(tool: annotationController.currentTool)
        case .toggleTyping(let rightAligned):
            if mode == .typing {
                mode = modeBeforeTyping
            } else {
                modeBeforeTyping = mode
                mode = .typing
                annotationController.beginTypingSession(rightAligned: rightAligned)
            }
            overlayController.updateInteractionMode(mode)
            overlayController.requestRedraw()
            feedbackAdapter.present(.modeEntered(.typing(rightAligned: rightAligned)))
        case .increaseFontSize:
            annotationController.increaseFontSize()
            saveCurrentTypingFontSize()
            overlayController.requestRedraw()
        case .decreaseFontSize:
            annotationController.decreaseFontSize()
            saveCurrentTypingFontSize()
            overlayController.requestRedraw()
        }
    }

    private func saveCurrentTypingFontSize() {
        var settings = settingsStore.load()
        settings.typingFontSize = annotationController.typingFontSize
        settingsStore.save(settings)
    }

    private func presentToolFeedback(tool: AnnotationTool) {
        feedbackAdapter.present(.toolChanged(
            tool: tool,
            color: annotationController.currentStyle.color,
            width: annotationController.currentStyle.rootWidth,
            canvas: annotationController.canvasBackground
        ))
    }

    private func activateStaticZoom() {
        guard mode == .idle else {
            animateExit()
            return
        }

        guard ScreenRecordingPrompt.ensureGranted(
            permissionService,
            permissionRelaunchCoordinator: permissionRelaunchCoordinator,
            permissionSession: screenRecordingPermissionSession
        ) else {
            return
        }

        guard let display = displayManager.activeDisplay() else {
            NSSound.beep()
            return
        }

        feedbackAdapter.present(.modeEntered(.staticZoom))

        Task { @MainActor in
            do {
                let frame = try await captureDisplayForOverlay(display)
                let settings = settingsStore.load()
                viewportController.configure(for: frame, initialZoom: settings.defaultZoomFactor)
                annotationController.reset()
                // Apply persisted drawing/typing defaults from the settings dialog.
                annotationController.currentStyle.rootWidth = settings.rootPenWidth
                annotationController.typingFontName = settings.typingFontName
                annotationController.typingFontSize = settings.typingFontSize
                if settings.animateZoom {
                    // Start fully zoomed out so the overlay telescopes in to the
                    // target zoom, matching Windows ZoomIt.
                    viewportController.beginZoomInAnimation(
                        reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                    )
                }
                overlayController.show(
                    frame: frame,
                    viewportController: viewportController,
                    annotationController: annotationController,
                    smoothImage: settings.smoothImage,
                    commandSink: { [weak self] command in self?.handle(command) },
                    onPasteboardOutput: { [weak self] output in
                        self?.handleSnipPasteboardOutput(output)
                    }
                )
                mode = .staticZoom
                if settings.animateZoom {
                    overlayController.runZoomAnimation()
                }
            } catch {
                presentError(error)
            }
        }
    }

    private func activateLiveZoom() {
        guard mode == .idle else {
            animateExit()
            return
        }

        guard ScreenRecordingPrompt.ensureGranted(
            permissionService,
            permissionRelaunchCoordinator: permissionRelaunchCoordinator,
            permissionSession: screenRecordingPermissionSession
        ) else {
            return
        }

        guard let display = displayManager.activeDisplay() else {
            NSSound.beep()
            return
        }

        feedbackAdapter.present(.modeEntered(.liveZoom))

        Task { @MainActor in
            do {
                // Capture one still frame for the initial display, then let the
                // live stream keep refreshing the magnified content.
                let frame = try await captureDisplayForOverlay(display)
                let settings = settingsStore.load()
                viewportController.configure(for: frame, initialZoom: settings.defaultZoomFactor)
                annotationController.reset()
                annotationController.currentStyle.rootWidth = settings.rootPenWidth
                annotationController.typingFontName = settings.typingFontName
                annotationController.typingFontSize = settings.typingFontSize
                if settings.animateZoom {
                    viewportController.beginZoomInAnimation(
                        reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                    )
                }
                overlayController.show(
                    frame: frame,
                    viewportController: viewportController,
                    annotationController: annotationController,
                    smoothImage: settings.smoothImage,
                    excludeFromScreenCapture: true,
                    commandSink: { [weak self] command in self?.handle(command) },
                    onPasteboardOutput: { [weak self] output in
                        self?.handleSnipPasteboardOutput(output)
                    }
                )
                mode = .liveZoom
                overlayController.updateInteractionMode(.liveZoom)

                // Start streaming live frames into the overlay. The stream
                // excludes the overlay window so it is never captured back
                // into itself.
                let session = LiveCaptureSession { [weak self] image in
                    guard let self, self.mode == .liveZoom || self.isExiting else { return }
                    self.overlayController.updateLiveImage(image)
                }
                liveCaptureSession = session
                let excludedWindowNumbers = [
                    overlayController.overlayWindowNumber,
                    recordingController.webcamWindowNumberForScreenCaptureExclusion
                ].compactMap { $0 }
                try await session.start(display: display, excludingWindowNumbers: excludedWindowNumbers)

                // Enable Control+Up/Down zoom while live zoom is on screen.
                onBeginLiveZoomNavigation?()

                if settings.animateZoom {
                    overlayController.runZoomAnimation()
                }
            } catch {
                stopLiveCapture()
                presentError(error)
            }
        }
    }

    /// While live zoomed, the draw/zoom hotkeys toggle drawing on the live view
    /// without changing magnification or exiting. Annotations live in stable
    /// screen-content coordinates, so the live image keeps updating beneath them.
    private func toggleLiveZoomDrawing() {
        guard mode == .liveZoom else { return }
        overlayController.toggleDrawingMode()
    }

    private func activateDrawWithoutZoom() {
        guard mode == .idle else {
            animateExit()
            return
        }

        guard ScreenRecordingPrompt.ensureGranted(
            permissionService,
            permissionRelaunchCoordinator: permissionRelaunchCoordinator,
            permissionSession: screenRecordingPermissionSession
        ) else {
            return
        }

        guard let display = displayManager.activeDisplay() else {
            NSSound.beep()
            return
        }

        feedbackAdapter.present(.modeEntered(.drawing(live: false)))

        Task { @MainActor in
            do {
                let frame = try await captureDisplayForOverlay(display)
                let settings = settingsStore.load()
                // Draw-without-zoom freezes the screen at 1x and goes straight
                // into drawing mode; there is no magnification or animation.
                viewportController.configure(for: frame, initialZoom: 1)
                annotationController.reset()
                annotationController.currentStyle.rootWidth = settings.rootPenWidth
                annotationController.typingFontName = settings.typingFontName
                annotationController.typingFontSize = settings.typingFontSize
                overlayController.show(
                    frame: frame,
                    viewportController: viewportController,
                    annotationController: annotationController,
                    smoothImage: settings.smoothImage,
                    commandSink: { [weak self] command in self?.handle(command) }
                )
                mode = .drawOnly
                // Arm drawing mode immediately so the first click starts a stroke.
                overlayController.updateInteractionMode(.drawOnly)
            } catch {
                presentError(error)
            }
        }
    }

    /// Reaching 1x is a boundary, not an exit gesture. The user retains control
    /// of dismissal through Escape, right-click, or the active mode hotkey.
    static func exitsOnZoomOutFloor(mode _: AppMode) -> Bool {
        false
    }

    private func zoomIn() {
        guard mode == .staticZoom || mode == .liveZoom || mode == .typing, !isExiting else { return }
        let settings = settingsStore.load()
        let current = viewportController.targetZoomFactor
        guard current < settings.maximumZoomFactor else { return }

        // ZoomIt's mouse-wheel zoom-in steps: snap to 2x, then keep doubling.
        let target = current < 2 ? 2 : min(settings.maximumZoomFactor, current * 2)
        applyZoom(to: target, animate: settings.animateZoom)
    }

    private func zoomOut() {
        guard mode == .staticZoom || mode == .liveZoom || mode == .typing, !isExiting else { return }
        let settings = settingsStore.load()
        let current = viewportController.targetZoomFactor
        // At 1x there is nothing left to zoom out of.
        guard current > settings.minimumZoomFactor else {
            if Self.exitsOnZoomOutFloor(mode: mode) {
                animateExit()
            }
            return
        }

        // ZoomIt's zoom-out steps: halve while above 2x, then ease out by 0.75
        // down to the 1x minimum.
        let target = current <= 2
            ? max(settings.minimumZoomFactor, current * 0.75)
            : current / 2
        applyZoom(to: target, animate: settings.animateZoom)
    }

    private func adjustZoomFromScroll(
        scrollingDeltaY: CGFloat,
        isPrecise: Bool
    ) {
        guard mode == .staticZoom || mode == .liveZoom || mode == .typing,
              !isExiting else {
            return
        }

        let settings = settingsStore.load()
        let current = viewportController.targetZoomFactor
        let target = ZoomScrollInputPolicy.targetZoomFactor(
            current: current,
            scrollingDeltaY: scrollingDeltaY,
            isPrecise: isPrecise,
            minimum: settings.minimumZoomFactor,
            maximum: settings.maximumZoomFactor
        )
        guard abs(target - current) > 0.0001 else { return }
        applyZoom(to: target, animate: settings.animateZoom)
    }

    private func applyZoom(to target: CGFloat, animate: Bool) {
        feedbackAdapter.present(.zoomChanged(factor: target))
        if animate {
            viewportController.animateZoom(
                to: target,
                reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            )
            overlayController.runZoomAnimation()
        } else {
            viewportController.setZoomFactor(target)
            overlayController.requestRedraw()
        }
    }

    private func captureDisplayForOverlay(_ display: DisplayDescriptor) async throws -> CapturedFrame {
        let excludedWindowNumbers = recordingController.webcamWindowNumberForScreenCaptureExclusion.map { [$0] } ?? []
        return try await captureService.captureDisplay(display, excludingWindowNumbers: excludedWindowNumbers)
    }

    private func animateExit() {
        guard mode != .idle, !isExiting else { return }
        isExiting = true
        // Telescope back out to 1x before tearing down the overlay.
        viewportController.animateZoom(
            to: 1,
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        )
        overlayController.runZoomAnimation { [weak self] in
            self?.exitActiveMode()
        }
    }

    private func exitActiveMode() {
        if mode == .breakTimer {
            stopBreakTimer()
            return
        }
        stopLiveCapture()
        overlayController.close()
        annotationController.reset()
        mode = .idle
        isExiting = false
    }

    /// Starts a region snip. From idle it captures the screen; while zoomed it
    /// selects within the current viewport so ZoomIt's own overlay is reused
    /// rather than captured.
    private func startSnip(action: SnipAction) {
        guard !isSnipping else {
            NSSound.beep()
            return
        }
        switch action {
        case .copyImage:
            feedbackAdapter.present(.modeEntered(.regionSelection(.screenshotToClipboard)))
        case .saveImage:
            feedbackAdapter.present(.modeEntered(.regionSelection(.screenshotToFile)))
        case .recognizeText:
            feedbackAdapter.present(.modeEntered(.regionSelection(.ocrToClipboard)))
        }
        switch mode {
        case .idle:
            isSnipping = true
            snipController.begin(action: action) { [weak self] in
                self?.isSnipping = false
            }
        case .staticZoom, .liveZoom, .drawOnly, .typing:
            isSnipping = true
            overlayController.beginRegionSnip(
                action: action,
                onPasteboardOutput: { [weak self] output in
                    self?.handleSnipPasteboardOutput(output)
                }
            ) { [weak self] in
                self?.isSnipping = false
            }
        default:
            NSSound.beep()
        }
    }

    private func startPreviousRegionSnip() {
        guard mode == .idle else {
            startSnip(action: .copyImage)
            return
        }
        guard !isSnipping else {
            NSSound.beep()
            return
        }
        feedbackAdapter.present(.modeEntered(.regionSelection(.screenshotToClipboard)))
        isSnipping = true
        snipController.beginPreviousRegion { [weak self] in
            self?.isSnipping = false
        }
    }

    private func startWindowSnip() {
        guard !isSnipping else {
            NSSound.beep()
            return
        }
        feedbackAdapter.present(.modeEntered(.regionSelection(.screenshotToClipboard)))
        isSnipping = true
        snipController.beginWindowAtPointer { [weak self] in
            self?.isSnipping = false
        }
    }

    private func handleSnipPasteboardOutput(_ output: SnipPasteboardOutput) {
        pasteCompatibilityCoordinator.screenshotCopied(changeCount: output.changeCount)
        feedbackAdapter.present(.completed(output.feedbackCompletion))
    }

    /// Opens an existing video in the clip editor (trim/append/save) without
    /// recording, mirroring ZoomIt's standalone Trim workflow.
    func openTrimEditor() {
        recordingController.openForTrim()
    }

    /// Starts/stops screen recording. Recording runs independently of the zoom
    /// overlay so the user can zoom and draw (and have those captured) while a
    /// recording is in progress.
    private func toggleRecording(region: Bool) {
        // Make sure the Save dialog (shown after stopping) isn't hidden behind a
        // zoom overlay by dismissing any active overlay first.
        recordingController.overlayFrameProvider = { [weak self] sourceRect in
            self?.overlayController.captureFrameForRecording(sourceRect: sourceRect)
        }
        recordingController.onWillShowSaveDialog = { [weak self] in
            self?.overlayController.prepareForPresentedWindow()
            self?.exitActiveMode()
        }
        recordingController.toggle(region: region) { [weak self] recording in
            self?.onRecordingStateChanged?(recording)
        }
    }

    /// Starts/stops panorama (scrolling) capture. Like recording, it runs
    /// independently of the zoom overlay so the Save dialog isn't hidden behind
    /// an active overlay.
    private func togglePanorama(save: Bool) {
        feedbackAdapter.present(.modeEntered(.panorama(save: save)))
        panoramaController.onWillShowSaveDialog = { [weak self] in
            guard let self, self.mode != .idle else { return }
            self.exitActiveMode()
        }
        panoramaController.toggle(save: save) { _ in }
    }

    private func toggleBreakTimer() {
        if mode == .breakTimer {
            stopBreakTimer()
            return
        }

        guard mode == .idle else {
            animateExit()
            return
        }

        let settings = settingsStore.load()
        feedbackAdapter.present(.modeEntered(.timer))
        Task { @MainActor in
            do {
                try await breakTimerController.begin(settings: settings) { [weak self] in
                    self?.mode = .idle
                }
                mode = .breakTimer
            } catch {
                presentError(error)
            }
        }
    }

    private func stopBreakTimer() {
        breakTimerController.close()
        mode = .idle
        isExiting = false
    }

    /// Tears down the live capture stream, if any, when leaving live zoom.
    private func stopLiveCapture() {
        onEndLiveZoomNavigation?()
        guard let session = liveCaptureSession else { return }
        liveCaptureSession = nil
        Task { await session.stop() }
    }

    private func presentError(_ error: Error) {
        feedbackAdapter.present(.error(error.localizedDescription))
    }
}
