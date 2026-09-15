import AppKit
import PasteTapBridge

enum EventTapHandlingDecision: Equatable, Sendable {
    case passThrough
    case suppressOriginal
}

enum KeyboardPostCommand: Equatable, Sendable {
    case commandV
}

@MainActor
protocol KeyboardEventPoster: AnyObject {
    func post(_ command: KeyboardPostCommand)
}

@MainActor
final class PasteCompatibilityEventTapController {
    private let coordinator: PasteCompatibilityCoordinator
    private let poster: KeyboardEventPoster

    init(coordinator: PasteCompatibilityCoordinator, poster: KeyboardEventPoster) {
        self.coordinator = coordinator
        self.poster = poster
    }

    func handle(_ event: KeyboardEvent) -> EventTapHandlingDecision {
        switch coordinator.handle(event) {
        case .passThrough:
            return .passThrough
        case .convertToCommandV:
            poster.post(.commandV)
            return .suppressOriginal
        }
    }

}

@MainActor
protocol PasteCompatibilityEventTapInstalling: AnyObject {
    func install() -> Bool
    func stop()
}

@MainActor
final class SystemPasteCompatibilityEventTap {
    private let permissionRequester: InputCompatibilityPermissionRequester
    private let installer: PasteCompatibilityEventTapInstalling
    private let controller: PasteCompatibilityEventTapController
    private var isRunning = false

    init(
        coordinator: PasteCompatibilityCoordinator,
        poster: KeyboardEventPoster,
        permissionRequester: InputCompatibilityPermissionRequester,
        installer: PasteCompatibilityEventTapInstalling? = nil
    ) {
        self.permissionRequester = permissionRequester
        let controller = PasteCompatibilityEventTapController(coordinator: coordinator, poster: poster)
        self.controller = controller
        self.installer = installer ?? CGPasteCompatibilityEventTapInstaller(controller: controller)
    }

    @discardableResult
    func start() -> Bool {
        guard permissionRequester.currentAccess().isComplete else { return false }
        guard !isRunning else { return true }
        let installed = installer.install()
        isRunning = installed
        return installed
    }

    func stop() {
        guard isRunning else { return }
        installer.stop()
        isRunning = false
    }
}

@MainActor
final class SystemKeyboardEventPoster: KeyboardEventPoster {
    private static let injectedEventMarker: Int64 = 0x445A5056

    func post(_ command: KeyboardPostCommand) {
        switch command {
        case .commandV:
            postCommandV()
        }
    }

    private func postCommandV() {
        DZPastePostCommandV(Self.injectedEventMarker)
    }
}

@MainActor
final class CGPasteCompatibilityEventTapInstaller: PasteCompatibilityEventTapInstalling {
    private static let injectedEventMarker: Int64 = 0x445A5056

    private let controller: PasteCompatibilityEventTapController
    private var handle: OpaquePointer?

    init(controller: PasteCompatibilityEventTapController) {
        self.controller = controller
    }

    func install() -> Bool {
        stop()

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        guard let handle = DZPasteTapStart(DoraZoomPasteCompatibilityHandleEvent, selfPointer, Self.injectedEventMarker) else {
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
        let key = keyCode == DZPasteKeyANSI_V ? "v" : "key-\(keyCode)"
        return controller.handle(.keyDown(
            key: key,
            modifiers: Self.keyboardModifiers(from: rawModifiers),
            isSynthetic: isSynthetic
        ))
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

@_cdecl("DoraZoomPasteCompatibilityHandleEvent")
func DoraZoomPasteCompatibilityHandleEvent(
    keyCode: Int64,
    modifiers: UInt32,
    isSynthetic: Bool,
    context: UnsafeMutableRawPointer?
) -> DZPasteTapDecision {
    guard let context else { return DZPasteTapDecisionPassThrough }
    let installer = Unmanaged<CGPasteCompatibilityEventTapInstaller>.fromOpaque(context).takeUnretainedValue()
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
