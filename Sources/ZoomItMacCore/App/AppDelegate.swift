import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var appController: AppController?
#if !DORAZOOM_APP_STORE
    private var pasteCompatibilityEventTap: SystemPasteCompatibilityEventTap?
    private var controlVPasteHotkeyService: ControlVPasteHotkeyService?
#endif
    private var recordingRecoveryCoordinator: RecordingRecoveryCoordinator?
    private let permissionCenterRestartIntent = PermissionCenterRestartIntent()
    private var permissionPlanProvider: (() -> PermissionCenterPlan)?
    private var settingsProvider: (() -> AppSettings)?
    private var statusMenuRuntimeStatus: StatusMenuRuntimeStatus = .idle

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        guard SingleInstance.claimOrActivateExisting() else {
            NSApplication.shared.terminate(nil)
            return
        }

        DoraZoomAppIcon.apply()

        let settingsStore = UserDefaultsSettingsStore()
        let savedSettings = settingsStore.load()
        if settingsStore.hasLaunchAtLoginPreference {
            LaunchAtLogin.applySavedPreference(savedSettings.launchAtLogin)
        } else if LaunchAtLogin.isEnabledOrPending {
            var migratedSettings = savedSettings
            migratedSettings.launchAtLogin = true
            settingsStore.save(migratedSettings)
        }
        let permissionService = SystemPermissionService()
        let displayManager = SystemDisplayManager()
        let captureService = ScreenCaptureKitCaptureService(displayManager: displayManager)
        let overlayController = OverlayWindowController()
        let annotationController = AnnotationController()
        let viewportController = ZoomViewportController()
        let interactionFeedback = InteractionFeedback()
        let feedbackAdapter = FeedbackPresentationAdapter(
            feedback: interactionFeedback,
            scheduler: RunLoopFeedbackDismissalScheduler(),
            presenter: TransientFeedbackWindowController(),
            environmentProvider: {
                FeedbackPresentationEnvironment(
                    reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
                    reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
                    increaseContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
                )
            }
        )
        let inputCompatibilityRequester = SystemInputCompatibilityPermissionRequester()
        let pasteCompatibilityCoordinator = PasteCompatibilityCoordinator(permissionRequester: inputCompatibilityRequester)
        let recordingRecoveryStore = FileRecordingRecoveryStore()

        let modeCoordinator = ModeCoordinator(
            settingsStore: settingsStore,
            permissionService: permissionService,
            displayManager: displayManager,
            captureService: captureService,
            windowCaptureService: ScreenCaptureKitWindowCaptureService(),
            overlayController: overlayController,
            annotationController: annotationController,
            viewportController: viewportController,
            feedbackAdapter: feedbackAdapter,
            recordingRecoveryStore: recordingRecoveryStore,
            pasteCompatibilityCoordinator: pasteCompatibilityCoordinator
        )
#if !DORAZOOM_APP_STORE
        let keyboardEventPoster = SystemKeyboardEventPoster()
        let pasteCompatibilityEventTap = SystemPasteCompatibilityEventTap(
            coordinator: pasteCompatibilityCoordinator,
            poster: keyboardEventPoster,
            permissionRequester: inputCompatibilityRequester
        )
        pasteCompatibilityCoordinator.onAccessBecameComplete = { [weak pasteCompatibilityEventTap] in
            _ = pasteCompatibilityEventTap?.start()
        }
        _ = pasteCompatibilityEventTap.start()
        self.pasteCompatibilityEventTap = pasteCompatibilityEventTap

        let controlVPasteHotkeyService = ControlVPasteHotkeyService(
            permissionRequester: inputCompatibilityRequester,
            poster: keyboardEventPoster
        )
        pasteCompatibilityCoordinator.onScreenshotCopied = { [weak controlVPasteHotkeyService] changeCount in
            controlVPasteHotkeyService?.screenshotCopied(changeCount: changeCount)
        }
        modeCoordinator.onTextEditingStateChanged = { [weak controlVPasteHotkeyService] isActive in
            controlVPasteHotkeyService?.setTextEditingActive(isActive)
        }
        self.controlVPasteHotkeyService = controlVPasteHotkeyService
#endif

        let hotkeyService = HotkeyService(
            settingsStore: settingsStore
        ) { command in
            Task { @MainActor in
                modeCoordinator.handle(command)
            }
        }

        // Register Control+Up/Down zoom hotkeys only while live zoom is active.
        modeCoordinator.onBeginLiveZoomNavigation = { [weak hotkeyService] in
            hotkeyService?.beginLiveZoomNavigation()
        }
        modeCoordinator.onEndLiveZoomNavigation = { [weak hotkeyService] in
            hotkeyService?.endLiveZoomNavigation()
        }

        let permissionPlatformAccess = SystemPermissionCenterPlatformAccess(
            permissionService: permissionService,
            inputPermissionRequester: inputCompatibilityRequester
        )
        var permissionCenterCoordinator: PermissionCenterCoordinator!
        let permissionAdapter = PermissionCenterSystemAdapter(
            platformAccess: permissionPlatformAccess,
            restarter: permissionCenterRestartIntent,
            settingsProvider: { settingsStore.load() },
            inputListeningFallbackNeeded: {
                let settings = settingsStore.load()
                return hotkeyService.requiresInputListeningFallback
                    || settings.recordMouseClicks
                    || settings.recordShortcutKeys
            },
            onStateChanged: { [weak self] in
                permissionCenterCoordinator?.applicationBecameActive()
                self?.rebuildStatusMenu()
            }
        )
        let permissionWindowController = PermissionCenterWindowController { kind in
            permissionCenterCoordinator?.performAction(for: kind)
        }
        permissionCenterCoordinator = PermissionCenterCoordinator(
            planProvider: { permissionAdapter.plan() },
            presenter: permissionWindowController,
            actionHandler: { kind, action in permissionAdapter.perform(kind, action: action) }
        )
        permissionPlanProvider = { permissionAdapter.plan() }
        settingsProvider = { settingsStore.load() }
#if !DORAZOOM_APP_STORE
        pasteCompatibilityCoordinator.onInputPostingPermissionNeeded = { [weak permissionCenterCoordinator] in
            permissionCenterCoordinator?.show()
        }
#endif

        appController = AppController(
            settingsStore: settingsStore,
            permissionService: permissionService,
            hotkeyService: hotkeyService,
            modeCoordinator: modeCoordinator,
            permissionCenterCoordinator: permissionCenterCoordinator,
            onMenuNeedsUpdate: { [weak self] in self?.rebuildStatusMenu() }
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(showSettingsFromOtherInstance(_:)),
            name: SingleInstance.showSettingsNotification,
            object: nil
        )

        statusItem = makeStatusItem(
            controller: appController!,
            plan: StatusMenuPlan.make(
                status: statusMenuRuntimeStatus,
                permissions: permissionAdapter.plan(),
                settings: settingsStore.load()
            )
        )
        modeCoordinator.onRecordingStateChanged = { [weak self] recording in
            self?.updateRecordingIndicator(recording)
            self?.statusMenuRuntimeStatus = recording ? .recording : .idle
            self?.rebuildStatusMenu()
        }
        hotkeyService.start()

        let recordingRecoveryCoordinator = RecordingRecoveryCoordinator(store: recordingRecoveryStore)
        self.recordingRecoveryCoordinator = recordingRecoveryCoordinator
        DispatchQueue.main.async {
            recordingRecoveryCoordinator.presentPendingIfNeeded()
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        let shouldRelaunch = permissionCenterRestartIntent.consume()
#if !DORAZOOM_APP_STORE
        controlVPasteHotkeyService?.stop()
        pasteCompatibilityEventTap?.stop()
#endif
        DistributedNotificationCenter.default().removeObserver(self)
        SingleInstance.release()
        if shouldRelaunch {
            relaunchCurrentApplication()
        }
    }

    public func applicationDidBecomeActive(_ notification: Notification) {
        appController?.applicationBecameActive()
        rebuildStatusMenu()
    }

    private func relaunchCurrentApplication() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration)
    }

    @objc private func showSettingsFromOtherInstance(_ notification: Notification) {
        appController?.showSettings()
    }

    /// Swaps the menu-bar icon for a red record indicator while recording.
    private func updateRecordingIndicator(_ recording: Bool) {
        guard let button = statusItem?.button else { return }
        if recording {
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
            let image = NSImage(
                systemSymbolName: "record.circle.fill",
                accessibilityDescription: AppLocalization.string(
                    "accessibility.recording_indicator",
                    defaultValue: "Recording"
                )
            )?
                .withSymbolConfiguration(config)
            image?.size = NSSize(width: Self.menuBarIconGlyph, height: Self.menuBarIconGlyph)
            button.image = image
        } else {
            button.image = Self.menuBarIcon()
        }
    }

    private func makeStatusItem(
        controller: AppController,
        plan: StatusMenuPlan
    ) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = NSStatusItem.AutosaveName("com.duola.DoraZoom.statusItem")
        // Use the Windows ZoomIt icon (document with a magnifying glass) rendered
        // as a black template image so it tints to match the menu bar, following
        // the macOS convention for menu-bar icons.
        if let button = item.button {
            if let image = Self.menuBarIcon() {
                button.image = image
            } else {
                button.title = AppInfo.productName
            }
        }

        item.menu = makeMenu(plan.topLevelItems, controller: controller)
        return item
    }

    private func rebuildStatusMenu() {
        guard
            let statusItem,
            let appController,
            let permissionPlanProvider,
            let settingsProvider
        else {
            return
        }

        let plan = StatusMenuPlan.make(
            status: statusMenuRuntimeStatus,
            permissions: permissionPlanProvider(),
            settings: settingsProvider()
        )
        statusItem.menu = makeMenu(plan.topLevelItems, controller: appController)
    }

    private func makeMenu(
        _ plans: [StatusMenuItemPlan],
        controller: AppController
    ) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        for plan in plans {
            guard !plan.isSeparator else {
                menu.addItem(.separator())
                continue
            }

            let shortcut = plan.shortcut
            let item = NSMenuItem(
                title: plan.title,
                action: Self.actionSelector(for: plan.id),
                keyEquivalent: shortcut?.key ?? ""
            )
            item.target = controller
            item.isEnabled = plan.isEnabled
            if let shortcut {
                item.keyEquivalentModifierMask = modifierFlags(shortcut.modifiers)
            }
            if !plan.children.isEmpty {
                item.submenu = makeMenu(plan.children, controller: controller)
            }
            menu.addItem(item)
        }

        return menu
    }

    static func actionSelector(for id: StatusMenuItemID) -> Selector? {
        switch id {
        case .draw:
            #selector(AppController.activateDrawWithoutZoom)
        case .staticZoom:
            #selector(AppController.activateStaticZoom)
        case .liveZoom:
            #selector(AppController.activateLiveZoom)
        case .snipRegion:
            #selector(AppController.snipRegion)
        case .snipOCR:
            #selector(AppController.snipOCR)
        case .snipPreviousRegion:
            #selector(AppController.snipPreviousRegion)
        case .snipWindow:
            #selector(AppController.snipWindowAtPointer)
        case .recordScreen:
            #selector(AppController.toggleRecording)
        case .toggleRecordingPause:
            #selector(AppController.toggleRecordingPause)
        case .panorama:
            #selector(AppController.startPanorama)
        case .demoType:
            #selector(AppController.startDemoType)
        case .breakTimer:
            #selector(AppController.toggleBreakTimer)
        case .advancedEditor:
            #selector(AppController.openAdvancedEditor)
        case .permissions:
            #selector(AppController.checkPermissions)
        case .settings:
            #selector(AppController.showSettings)
        case .quit:
            #selector(AppController.quit)
        case .status,
             .screenshot,
             .coreSeparator,
             .moreFeatures,
             .managementSeparator,
             .quitSeparator:
            nil
        }
    }

    private func modifierFlags(
        _ modifiers: Set<StatusMenuShortcutModifier>
    ) -> NSEvent.ModifierFlags {
        modifiers.reduce(into: NSEvent.ModifierFlags()) { flags, modifier in
            switch modifier {
            case .control:
                flags.insert(.control)
            case .option:
                flags.insert(.option)
            case .shift:
                flags.insert(.shift)
            case .command:
                flags.insert(.command)
            }
        }
    }

    /// Loads the bundled black template version of the Windows ZoomIt icon and
    /// sizes it for the menu bar. As a template image it is tinted by the system
    /// (black on a light menu bar, white on a dark one).
    private static func menuBarIcon() -> NSImage? {
        guard let source = loadDoraZoomIcon() else { return nil }
        return Self.menuBarImage(from: source)
    }

    /// The square point size of the menu-bar item's image slot.
    static let menuBarIconCanvas: CGFloat = 18
    /// The glyph is drawn smaller than the canvas so ZoomIt's icon carries the
    /// same interior padding as system menu-bar icons; a full-bleed image made
    /// it look oversized and misaligned next to them.
    static let menuBarIconGlyph: CGFloat = 15

    /// Renders `source` centered inside a padded, square template image so it
    /// matches the size and vertical alignment of other menu-bar icons.
    static func menuBarImage(from source: NSImage) -> NSImage {
        let canvas = NSSize(width: menuBarIconCanvas, height: menuBarIconCanvas)
        let image = NSImage(size: canvas)
        image.lockFocus()
        let rect = NSRect(
            x: (canvas.width - menuBarIconGlyph) / 2,
            y: (canvas.height - menuBarIconGlyph) / 2,
            width: menuBarIconGlyph,
            height: menuBarIconGlyph
        )
        source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private static func loadDoraZoomIcon() -> NSImage? {
        DoraZoomAppIcon.loadTemplateIcon()
    }
}
