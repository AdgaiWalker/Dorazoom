 #if !DORAZOOM_APP_STORE
import AppKit
import Carbon.HIToolbox

enum PasteCompatibilityHotkey: Equatable, Sendable {
    case controlV
}

@MainActor
protocol ControlVPasteHotkeyRegistering: AnyObject {
    func register(_ hotkey: PasteCompatibilityHotkey, handler: @escaping () -> Void) -> Bool
    func unregister()
}

@MainActor
protocol PasteboardChangeCountProviding: AnyObject {
    var changeCount: Int { get }
}

@MainActor
final class SystemPasteboardChangeCountProvider: PasteboardChangeCountProviding {
    var changeCount: Int { NSPasteboard.general.changeCount }
}

/// Native fallback for the Windows habit of pressing Control+V after a DoraZoom
/// screenshot. Carbon receives the exact global shortcut without Input
/// Monitoring permission; Accessibility/Post Event access is still required to
/// synthesize the native Command+V that the target Mac app understands.
@MainActor
final class ControlVPasteHotkeyService {
    private let permissionRequester: InputCompatibilityPermissionRequester
    private let registrar: ControlVPasteHotkeyRegistering
    private let poster: KeyboardEventPoster
    private let pasteboard: PasteboardChangeCountProviding
    private var armedChangeCount: Int?
    private var pasteboardMonitor: Timer?
    private var isTextEditingActive = false

    init(
        permissionRequester: InputCompatibilityPermissionRequester,
        registrar: ControlVPasteHotkeyRegistering = CarbonControlVPasteHotkeyRegistrar(),
        poster: KeyboardEventPoster,
        pasteboard: PasteboardChangeCountProviding = SystemPasteboardChangeCountProvider()
    ) {
        self.permissionRequester = permissionRequester
        self.registrar = registrar
        self.poster = poster
        self.pasteboard = pasteboard
    }

    func screenshotCopied(changeCount: Int) {
        stop()
        guard permissionRequester.currentAccess().canPost else { return }

        armedChangeCount = changeCount
        pasteboardMonitor = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.disarmIfPasteboardChanged()
            }
        }
        registerIfAvailable()
    }

    func setTextEditingActive(_ isActive: Bool) {
        guard isTextEditingActive != isActive else { return }
        isTextEditingActive = isActive
        if isActive {
            registrar.unregister()
        } else {
            registerIfAvailable()
        }
    }

    func stop() {
        pasteboardMonitor?.invalidate()
        pasteboardMonitor = nil
        registrar.unregister()
        armedChangeCount = nil
    }

    private func pasteScreenshot() {
        guard !isTextEditingActive,
              let armedChangeCount,
              pasteboard.changeCount == armedChangeCount else {
            stop()
            return
        }
        poster.post(.commandV)
    }

    private func registerIfAvailable() {
        guard !isTextEditingActive,
              let armedChangeCount,
              pasteboard.changeCount == armedChangeCount,
              permissionRequester.currentAccess().canPost else {
            return
        }
        _ = registrar.register(.controlV, handler: { [weak self] in
            self?.pasteScreenshot()
        })
    }

    private func disarmIfPasteboardChanged() {
        guard let armedChangeCount else { return }
        if pasteboard.changeCount != armedChangeCount {
            stop()
        }
    }
}

@MainActor
final class CarbonControlVPasteHotkeyRegistrar: ControlVPasteHotkeyRegistering {
    private static let signature = fourCharacterCode("DZPV")
    private static let hotkeyID = EventHotKeyID(signature: signature, id: 1)

    private var eventHandlerRef: EventHandlerRef?
    private var hotkeyRef: EventHotKeyRef?
    private var handler: (() -> Void)?

    func register(_ hotkey: PasteCompatibilityHotkey, handler: @escaping () -> Void) -> Bool {
        installEventHandlerIfNeeded()
        unregister()
        self.handler = handler

        let keyCode: UInt32
        let modifiers: UInt32
        switch hotkey {
        case .controlV:
            keyCode = UInt32(kVK_ANSI_V)
            modifiers = UInt32(controlKey)
        }

        var newRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            Self.hotkeyID,
            GetApplicationEventTarget(),
            0,
            &newRef
        )
        guard status == noErr, let newRef else {
            self.handler = nil
            return false
        }
        hotkeyRef = newRef
        return true
    }

    func unregister() {
        if let hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
        }
        hotkeyRef = nil
        handler = nil
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
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var hotkeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotkeyID
                )
                guard status == noErr,
                      hotkeyID.signature == CarbonControlVPasteHotkeyRegistrar.signature,
                      hotkeyID.id == CarbonControlVPasteHotkeyRegistrar.hotkeyID.id else {
                    return OSStatus(eventNotHandledErr)
                }

                let registrar = Unmanaged<CarbonControlVPasteHotkeyRegistrar>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in registrar.handler?() }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef
        )
    }
}

#endif
