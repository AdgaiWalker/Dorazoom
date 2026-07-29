import AppKit
import Carbon.HIToolbox

@MainActor
final class HotkeyService {
    private let settingsStore: SettingsStore
    private let commandHandler: (AppCommand) -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var drawHotKeyRef: EventHotKeyRef?
    private var liveHotKeyRef: EventHotKeyRef?
    private var snipCopyHotKeyRef: EventHotKeyRef?
    private var snipSaveHotKeyRef: EventHotKeyRef?
    private var snipOcrHotKeyRef: EventHotKeyRef?
    private var recordHotKeyRef: EventHotKeyRef?
    private var recordRegionHotKeyRef: EventHotKeyRef?
    private var demoTypeHotKeyRef: EventHotKeyRef?
    private var demoTypeResetHotKeyRef: EventHotKeyRef?
    private var panoramaCopyHotKeyRef: EventHotKeyRef?
    private var panoramaSaveHotKeyRef: EventHotKeyRef?
    private var breakHotKeyRef: EventHotKeyRef?
    private var zoomInNavRef: EventHotKeyRef?
    private var zoomOutNavRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var fallbackEventTap: SystemHotkeyFallbackEventTap?
    private let fallbackPermissionSession = HotkeyFallbackPermissionSession()
    private let permissionRelaunchCoordinator: PermissionRelaunchCoordinator?

    init(
        settingsStore: SettingsStore,
        permissionRelaunchCoordinator: PermissionRelaunchCoordinator? = nil,
        commandHandler: @escaping (AppCommand) -> Void
    ) {
        self.settingsStore = settingsStore
        self.permissionRelaunchCoordinator = permissionRelaunchCoordinator
        self.commandHandler = commandHandler
    }

    func start() {
        installEventHandlerIfNeeded()
        registerHotKey()
    }

    /// Re-registers the global hotkey from the latest saved settings. Call this
    /// after the user changes the shortcut in the settings dialog.
    func reloadHotkey() {
        registerHotKey()
    }

    func stop() {
        unregisterHotKey()
        endLiveZoomNavigation()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
        eventHandlerRef = nil
    }

    /// Registers Option+Up / Option+Down as global hotkeys for the duration of
    /// live zoom so they zoom in and out. They are registered globally (rather
    /// than handled by the overlay) so they fire even though the overlay is the
    /// key window. Option+arrows is used instead of Control+arrows because macOS
    /// reserves Control+Up/Down for Mission Control / App Exposé and will not
    /// yield them to a registered hotkey.
    func beginLiveZoomNavigation() {
        installEventHandlerIfNeeded()
        let target = GetApplicationEventTarget()
        let signature = fourCharacterCode("ZITM")

        endLiveZoomNavigation()
        RegisterEventHotKey(
            UInt32(kVK_UpArrow),
            UInt32(optionKey),
            EventHotKeyID(signature: signature, id: 4),
            target,
            0,
            &zoomInNavRef
        )
        RegisterEventHotKey(
            UInt32(kVK_DownArrow),
            UInt32(optionKey),
            EventHotKeyID(signature: signature, id: 5),
            target,
            0,
            &zoomOutNavRef
        )
    }

    func endLiveZoomNavigation() {
        if let zoomInNavRef {
            UnregisterEventHotKey(zoomInNavRef)
        }
        zoomInNavRef = nil
        if let zoomOutNavRef {
            UnregisterEventHotKey(zoomOutNavRef)
        }
        zoomOutNavRef = nil
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }

                var hotKeyID = EventHotKeyID()
                let parameterStatus = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard parameterStatus == noErr else { return parameterStatus }
                guard hotKeyID.signature == fourCharacterCode("ZITM") else { return OSStatus(eventNotHandledErr) }

                let command: AppCommand
                switch hotKeyID.id {
                case 1: command = .activateStaticZoom
                case 2: command = .activateDrawWithoutZoom
                case 3: command = .activateLiveZoom
                case 4: command = .zoomIn
                case 5: command = .zoomOutOrExit
                case 6: command = .snipRegion(save: false)
                case 7: command = .snipRegion(save: true)
                case 8: command = .toggleRecording(region: false)
                case 9: command = .toggleRecording(region: true)
                case 10: command = .startPanorama(save: false)
                case 11: command = .startPanorama(save: true)
                case 12: command = .toggleBreakTimer
                case 13: command = .snipOcr
                case 14: command = .startDemoType
                case 15: command = .resetDemoType
                default: return OSStatus(eventNotHandledErr)
                }

                let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in
                    service.commandHandler(command)
                }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef
        )
    }

    private func registerHotKey() {
        unregisterHotKey()

        let settings = settingsStore.load()
        let target = GetApplicationEventTarget()
        let signature = fourCharacterCode("ZITM")
        var fallbackBindings: [HotkeyFallbackBinding] = []

        let zoomModifiers = NSEvent.ModifierFlags(rawValue: settings.hotKeyModifiers)
        register(
            command: .activateStaticZoom,
            keyCode: settings.hotKeyCode,
            modifiers: zoomModifiers,
            hotKeyID: EventHotKeyID(signature: signature, id: 1),
            target: target,
            ref: &hotKeyRef,
            fallbackBindings: &fallbackBindings
        )

        let drawModifiers = NSEvent.ModifierFlags(rawValue: settings.drawHotKeyModifiers)
        register(
            command: .activateDrawWithoutZoom,
            keyCode: settings.drawHotKeyCode,
            modifiers: drawModifiers,
            hotKeyID: EventHotKeyID(signature: signature, id: 2),
            target: target,
            ref: &drawHotKeyRef,
            fallbackBindings: &fallbackBindings
        )

        let liveModifiers = NSEvent.ModifierFlags(rawValue: settings.liveHotKeyModifiers)
        register(
            command: .activateLiveZoom,
            keyCode: settings.liveHotKeyCode,
            modifiers: liveModifiers,
            hotKeyID: EventHotKeyID(signature: signature, id: 3),
            target: target,
            ref: &liveHotKeyRef,
            fallbackBindings: &fallbackBindings
        )

        // Region snip: the base shortcut copies the region; the same shortcut
        // with Shift toggled saves it to a file.
        let snipModifiers = NSEvent.ModifierFlags(rawValue: settings.snipHotKeyModifiers)
        register(
            command: .snipRegion(save: false),
            keyCode: settings.snipHotKeyCode,
            modifiers: snipModifiers,
            hotKeyID: EventHotKeyID(signature: signature, id: 6),
            target: target,
            ref: &snipCopyHotKeyRef,
            fallbackBindings: &fallbackBindings
        )

        let snipSaveModifiers = NSEvent.ModifierFlags(rawValue: settings.snipHotKeyModifiers ^ NSEvent.ModifierFlags.shift.rawValue)
        register(
            command: .snipRegion(save: true),
            keyCode: settings.snipHotKeyCode,
            modifiers: snipSaveModifiers,
            hotKeyID: EventHotKeyID(signature: signature, id: 7),
            target: target,
            ref: &snipSaveHotKeyRef,
            fallbackBindings: &fallbackBindings
        )

        // OCR snip: recognizes text in the selected region and copies it to the
        // clipboard. A key code of 0 disables the hotkey, matching ZoomIt.
        if settings.snipOcrHotKeyCode != 0 {
            let snipOcrModifiers = NSEvent.ModifierFlags(rawValue: settings.snipOcrHotKeyModifiers)
            register(
                command: .snipOcr,
                keyCode: settings.snipOcrHotKeyCode,
                modifiers: snipOcrModifiers,
                hotKeyID: EventHotKeyID(signature: signature, id: 13),
                target: target,
                ref: &snipOcrHotKeyRef,
                fallbackBindings: &fallbackBindings
            )
        }

        // Recording: the base shortcut records the whole screen; the same
        // shortcut with Shift toggled records a selected region.
        let recordModifiers = NSEvent.ModifierFlags(rawValue: settings.recordHotKeyModifiers)
        register(
            command: .toggleRecording(region: false),
            keyCode: settings.recordHotKeyCode,
            modifiers: recordModifiers,
            hotKeyID: EventHotKeyID(signature: signature, id: 8),
            target: target,
            ref: &recordHotKeyRef,
            fallbackBindings: &fallbackBindings
        )

        let recordRegionModifiers = NSEvent.ModifierFlags(rawValue: settings.recordHotKeyModifiers ^ NSEvent.ModifierFlags.shift.rawValue)
        register(
            command: .toggleRecording(region: true),
            keyCode: settings.recordHotKeyCode,
            modifiers: recordRegionModifiers,
            hotKeyID: EventHotKeyID(signature: signature, id: 9),
            target: target,
            ref: &recordRegionHotKeyRef,
            fallbackBindings: &fallbackBindings
        )

        if settings.demoTypeHotKeyCode != 0 {
            let demoTypeModifiers = NSEvent.ModifierFlags(rawValue: settings.demoTypeHotKeyModifiers)
            register(
                command: .startDemoType,
                keyCode: settings.demoTypeHotKeyCode,
                modifiers: demoTypeModifiers,
                hotKeyID: EventHotKeyID(signature: signature, id: 14),
                target: target,
                ref: &demoTypeHotKeyRef,
                fallbackBindings: &fallbackBindings
            )

            let demoTypeResetModifiers = NSEvent.ModifierFlags(rawValue: settings.demoTypeHotKeyModifiers ^ NSEvent.ModifierFlags.shift.rawValue)
            register(
                command: .resetDemoType,
                keyCode: settings.demoTypeHotKeyCode,
                modifiers: demoTypeResetModifiers,
                hotKeyID: EventHotKeyID(signature: signature, id: 15),
                target: target,
                ref: &demoTypeResetHotKeyRef,
                fallbackBindings: &fallbackBindings
            )
        }

        // Panorama: the base shortcut copies the stitched panorama to the
        // clipboard; the same shortcut with Shift toggled saves it to a file.
        let panoramaModifiers = NSEvent.ModifierFlags(rawValue: settings.panoramaHotKeyModifiers)
        register(
            command: .startPanorama(save: false),
            keyCode: settings.panoramaHotKeyCode,
            modifiers: panoramaModifiers,
            hotKeyID: EventHotKeyID(signature: signature, id: 10),
            target: target,
            ref: &panoramaCopyHotKeyRef,
            fallbackBindings: &fallbackBindings
        )

        let panoramaSaveModifiers = NSEvent.ModifierFlags(rawValue: settings.panoramaHotKeyModifiers ^ NSEvent.ModifierFlags.shift.rawValue)
        register(
            command: .startPanorama(save: true),
            keyCode: settings.panoramaHotKeyCode,
            modifiers: panoramaSaveModifiers,
            hotKeyID: EventHotKeyID(signature: signature, id: 11),
            target: target,
            ref: &panoramaSaveHotKeyRef,
            fallbackBindings: &fallbackBindings
        )

        let breakModifiers = NSEvent.ModifierFlags(rawValue: settings.breakHotKeyModifiers)
        register(
            command: .toggleBreakTimer,
            keyCode: settings.breakHotKeyCode,
            modifiers: breakModifiers,
            hotKeyID: EventHotKeyID(signature: signature, id: 12),
            target: target,
            ref: &breakHotKeyRef,
            fallbackBindings: &fallbackBindings
        )

        startFallbackEventTapIfNeeded(for: fallbackBindings)
    }

    private func unregisterHotKey() {
        fallbackEventTap?.stop()
        fallbackEventTap = nil

        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
        if let drawHotKeyRef {
            UnregisterEventHotKey(drawHotKeyRef)
        }
        drawHotKeyRef = nil
        if let liveHotKeyRef {
            UnregisterEventHotKey(liveHotKeyRef)
        }
        liveHotKeyRef = nil
        if let snipCopyHotKeyRef {
            UnregisterEventHotKey(snipCopyHotKeyRef)
        }
        snipCopyHotKeyRef = nil
        if let snipSaveHotKeyRef {
            UnregisterEventHotKey(snipSaveHotKeyRef)
        }
        snipSaveHotKeyRef = nil
        if let snipOcrHotKeyRef {
            UnregisterEventHotKey(snipOcrHotKeyRef)
        }
        snipOcrHotKeyRef = nil
        if let recordHotKeyRef {
            UnregisterEventHotKey(recordHotKeyRef)
        }
        recordHotKeyRef = nil
        if let recordRegionHotKeyRef {
            UnregisterEventHotKey(recordRegionHotKeyRef)
        }
        recordRegionHotKeyRef = nil
        if let demoTypeHotKeyRef {
            UnregisterEventHotKey(demoTypeHotKeyRef)
        }
        demoTypeHotKeyRef = nil
        if let demoTypeResetHotKeyRef {
            UnregisterEventHotKey(demoTypeResetHotKeyRef)
        }
        demoTypeResetHotKeyRef = nil
        if let panoramaCopyHotKeyRef {
            UnregisterEventHotKey(panoramaCopyHotKeyRef)
        }
        panoramaCopyHotKeyRef = nil
        if let panoramaSaveHotKeyRef {
            UnregisterEventHotKey(panoramaSaveHotKeyRef)
        }
        panoramaSaveHotKeyRef = nil
        if let breakHotKeyRef {
            UnregisterEventHotKey(breakHotKeyRef)
        }
        breakHotKeyRef = nil
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        return carbon
    }

    private func register(
        command: AppCommand,
        keyCode: Int,
        modifiers: NSEvent.ModifierFlags,
        hotKeyID: EventHotKeyID,
        target: EventTargetRef?,
        ref: inout EventHotKeyRef?,
        fallbackBindings: inout [HotkeyFallbackBinding]
    ) {
        var newRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            carbonModifiers(from: modifiers),
            hotKeyID,
            target,
            0,
            &newRef
        )

        if status == noErr {
            ref = newRef
            return
        }

        ref = nil
        let fallbackBinding = HotkeyFallbackBinding(
            command: command,
            keyCode: keyCode,
            modifiers: keyboardModifiers(from: modifiers)
        )
        fallbackBindings.append(fallbackBinding)
        NSLog(
            "DoraZoom Carbon hotkey registration failed; command=%@ keyCode=%d modifiers=%@ status=%d. Falling back to event tap.",
            String(describing: command),
            keyCode,
            String(describing: fallbackBinding.modifiers),
            status
        )
    }

    private func startFallbackEventTapIfNeeded(for bindings: [HotkeyFallbackBinding]) {
        guard !bindings.isEmpty else { return }
        let fallbackEventTap = SystemHotkeyFallbackEventTap(
            bindings: bindings,
            permissionRelaunchCoordinator: permissionRelaunchCoordinator,
            permissionSession: fallbackPermissionSession,
            commandHandler: commandHandler
        )
        self.fallbackEventTap = fallbackEventTap
        _ = fallbackEventTap.start()
    }

    private func keyboardModifiers(from flags: NSEvent.ModifierFlags) -> Set<KeyboardModifier> {
        var modifiers: Set<KeyboardModifier> = []
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.option) { modifiers.insert(.option) }
        return modifiers
    }
}

func fourCharacterCode(_ string: String) -> OSType {
    string.utf8.reduce(0) { code, character in
        (code << 8) + OSType(character)
    }
}
