#if DORAZOOM_APP_STORE
import AppKit

struct HotkeyFallbackBinding: Equatable, Sendable {
    var command: AppCommand
    var keyCode: Int
    var modifiers: Set<KeyboardModifier>
}

enum HotkeyFallbackPermissionAction: Equatable, Sendable {
    case installEventTap
    case promptForAuthorization
    case waitForRelaunch
}

/// The sandboxed store build does not install a global event tap. Carbon
/// hotkeys remain available when macOS accepts them; this fallback is a
/// deliberate no-op because it would require Input Monitoring.
@MainActor
final class HotkeyFallbackPermissionSession {
    func action(hasListenAccess: Bool) -> HotkeyFallbackPermissionAction {
        hasListenAccess ? .installEventTap : .waitForRelaunch
    }
}

@MainActor
final class SystemHotkeyFallbackEventTap {
    init(
        bindings: [HotkeyFallbackBinding],
        permissionRelaunchCoordinator: PermissionRelaunchCoordinator?,
        permissionSession: HotkeyFallbackPermissionSession = HotkeyFallbackPermissionSession(),
        commandHandler: @escaping (AppCommand) -> Void,
        installer: AnyObject? = nil
    ) {}

    func start() -> Bool { false }
    func stop() {}
}

#else
import AppKit
import PasteTapBridge

struct HotkeyFallbackBinding: Equatable, Sendable {
    var command: AppCommand
    var keyCode: Int
    var modifiers: Set<KeyboardModifier>
}

enum HotkeyFallbackPermissionAction: Equatable, Sendable {
    case installEventTap
    case promptForAuthorization
    case waitForRelaunch
}

/// Keeps the keyboard-listen permission prompt one-shot for the lifetime of the
/// app. Settings changes recreate the fallback event tap, so the prompt state
/// must live above an individual tap instance.
@MainActor
final class HotkeyFallbackPermissionSession {
    private var didPromptForAuthorization = false

    func action(hasListenAccess: Bool) -> HotkeyFallbackPermissionAction {
        if hasListenAccess {
            return .installEventTap
        }
        guard !didPromptForAuthorization else {
            return .waitForRelaunch
        }
        didPromptForAuthorization = true
        return .promptForAuthorization
    }
}

@MainActor
final class HotkeyFallbackEventTapController {
    private let bindings: [HotkeyFallbackBinding]
    private let commandHandler: (AppCommand) -> Void

    init(bindings: [HotkeyFallbackBinding], commandHandler: @escaping (AppCommand) -> Void) {
        self.bindings = bindings
        self.commandHandler = commandHandler
    }

    func handle(keyCode: Int64, modifiers: Set<KeyboardModifier>, isSynthetic: Bool) -> EventTapHandlingDecision {
        guard !isSynthetic else { return .passThrough }
        guard let binding = bindings.first(where: { $0.keyCode == Int(keyCode) && $0.modifiers == modifiers }) else {
            return .passThrough
        }

        commandHandler(binding.command)
        return .suppressOriginal
    }
}

@MainActor
protocol HotkeyFallbackEventTapInstalling: AnyObject {
    func install() -> Bool
    func stop()
}

@MainActor
final class SystemHotkeyFallbackEventTap {
    private let bindings: [HotkeyFallbackBinding]
    private let permissionRelaunchCoordinator: PermissionRelaunchCoordinator?
    private let permissionSession: HotkeyFallbackPermissionSession
    private let installer: HotkeyFallbackEventTapInstalling
    private var isRunning = false

    init(
        bindings: [HotkeyFallbackBinding],
        permissionRelaunchCoordinator: PermissionRelaunchCoordinator?,
        permissionSession: HotkeyFallbackPermissionSession = HotkeyFallbackPermissionSession(),
        commandHandler: @escaping (AppCommand) -> Void,
        installer: HotkeyFallbackEventTapInstalling? = nil
    ) {
        self.bindings = bindings
        self.permissionRelaunchCoordinator = permissionRelaunchCoordinator
        self.permissionSession = permissionSession
        let controller = HotkeyFallbackEventTapController(bindings: bindings, commandHandler: commandHandler)
        self.installer = installer ?? CGHotkeyFallbackEventTapInstaller(controller: controller)
    }

    @discardableResult
    func start() -> Bool {
        guard !bindings.isEmpty else { return true }
        guard !isRunning else { return true }
        guard ensureListenAccess() else { return false }

        let installed = installer.install()
        isRunning = installed
        if !installed {
            NSLog("DoraZoom hotkey fallback event tap could not be installed.")
        }
        return installed
    }

    func stop() {
        guard isRunning else { return }
        installer.stop()
        isRunning = false
    }

    private func ensureListenAccess() -> Bool {
        switch permissionSession.action(hasListenAccess: CGPreflightListenEventAccess()) {
        case .installEventTap:
            return true
        case .waitForRelaunch:
            return false
        case .promptForAuthorization:
            break
        }

        let alert = NSAlert()
        alert.messageText = AppLocalization.string(
            "hotkey_fallback.permission.title",
            defaultValue: "Enable DoraZoom Shortcuts"
        )
        alert.informativeText = AppLocalization.string(
            "hotkey_fallback.permission.message",
            defaultValue: """
            macOS reserves some Control+number shortcuts. DoraZoom needs permission to monitor keyboard input so it can use fallback shortcuts that match ZoomIt.

            If DoraZoom is already enabled in System Settings but the shortcuts still do not work, quit and reopen DoraZoom. You will not be asked again during this session.
            """
        )
        alert.addButton(withTitle: AppLocalization.string(
            "permission_prompt.continue",
            defaultValue: "Continue"
        ))
        alert.addButton(withTitle: AppLocalization.string(
            "permission_prompt.not_now",
            defaultValue: "Not Now"
        ))
        guard alert.runModal() == .alertFirstButtonReturn else { return false }

        permissionRelaunchCoordinator?.notePermissionFlowMayRequireRelaunch()
        _ = CGRequestListenEventAccess()
        return CGPreflightListenEventAccess()
    }
}

@MainActor
final class CGHotkeyFallbackEventTapInstaller: HotkeyFallbackEventTapInstalling {
    private static let injectedEventMarker: Int64 = 0x445A484B

    private let controller: HotkeyFallbackEventTapController
    private var handle: OpaquePointer?

    init(controller: HotkeyFallbackEventTapController) {
        self.controller = controller
    }

    func install() -> Bool {
        stop()

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        guard let handle = DZPasteTapStart(DoraZoomHotkeyFallbackHandleEvent, selfPointer, Self.injectedEventMarker) else {
            return false
        }
        self.handle = handle
        return true
    }

    func stop() {
        if let handle {
            DZPasteTapStop(handle)
        }
        handle = nil
    }

    fileprivate func handle(keyCode: Int64, modifiers rawModifiers: UInt32, isSynthetic: Bool) -> EventTapHandlingDecision {
        controller.handle(
            keyCode: keyCode,
            modifiers: Self.keyboardModifiers(from: rawModifiers),
            isSynthetic: isSynthetic
        )
    }

    private static func keyboardModifiers(from rawModifiers: UInt32) -> Set<KeyboardModifier> {
        var modifiers: Set<KeyboardModifier> = []
        if (rawModifiers & UInt32(DZPasteModifierControl.rawValue)) != 0 { modifiers.insert(.control) }
        if (rawModifiers & UInt32(DZPasteModifierCommand.rawValue)) != 0 { modifiers.insert(.command) }
        if (rawModifiers & UInt32(DZPasteModifierShift.rawValue)) != 0 { modifiers.insert(.shift) }
        if (rawModifiers & UInt32(DZPasteModifierOption.rawValue)) != 0 { modifiers.insert(.option) }
        return modifiers
    }
}

@_cdecl("DoraZoomHotkeyFallbackHandleEvent")
func DoraZoomHotkeyFallbackHandleEvent(
    keyCode: Int64,
    modifiers: UInt32,
    isSynthetic: Bool,
    context: UnsafeMutableRawPointer?
) -> DZPasteTapDecision {
    guard let context else { return DZPasteTapDecisionPassThrough }
    let installer = Unmanaged<CGHotkeyFallbackEventTapInstaller>.fromOpaque(context).takeUnretainedValue()
    let decision = MainActor.assumeIsolated {
        installer.handle(keyCode: keyCode, modifiers: modifiers, isSynthetic: isSynthetic)
    }
    switch decision {
    case .passThrough:
        return DZPasteTapDecisionPassThrough
    case .suppressOriginal:
        return DZPasteTapDecisionSuppressOriginal
    }
}

#endif
