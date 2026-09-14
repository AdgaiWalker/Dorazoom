import CoreGraphics

#if DORAZOOM_APP_STORE

/// The Mac App Store build intentionally does not synthesize keyboard events.
/// Screenshots and OCR results are still copied to the clipboard by the shared
/// capture code; users paste them with the target app's normal shortcut.
struct KeyboardEventAccess: Equatable, Sendable {
    var canListen: Bool = false
    var canPost: Bool = false

    var isComplete: Bool { false }
    var missingRequirements: Set<KeyboardEventAccessRequirement> { [.listen, .post] }
}

enum KeyboardEventAccessRequirement: Equatable, Hashable, Sendable {
    case listen
    case post
}

enum PasteCompatibilitySettingStatus: Equatable, Sendable {
    case ready
    case waitingForAuthorization(missing: Set<KeyboardEventAccessRequirement>)
}

enum KeyboardModifier: Equatable, Hashable, Sendable {
    case control
    case command
    case shift
    case option
}

protocol InputCompatibilityPermissionRequester: AnyObject {
    func currentAccess() -> KeyboardEventAccess
}

final class SystemInputCompatibilityPermissionRequester: InputCompatibilityPermissionRequester {
    func currentAccess() -> KeyboardEventAccess { KeyboardEventAccess() }
}

final class PasteCompatibilityCoordinator {
    var onAccessBecameComplete: (() -> Void)?
    var onScreenshotCopied: ((Int) -> Void)?
    var onInputPostingPermissionNeeded: (() -> Void)?

    init(permissionRequester: InputCompatibilityPermissionRequester) {}
    var settingStatus: PasteCompatibilitySettingStatus {
        .waitingForAuthorization(missing: [.listen, .post])
    }
    func screenshotCopied(changeCount: Int) {}
    func pasteboardDidChange(changeCount: Int) {}
    func setTextEditingActive(_ isActive: Bool) {}
}

#else

struct KeyboardEventAccess: Equatable, Sendable {
    var canListen: Bool
    var canPost: Bool

    var isComplete: Bool { canListen && canPost }

    var missingRequirements: Set<KeyboardEventAccessRequirement> {
        var missing: Set<KeyboardEventAccessRequirement> = []
        if !canListen { missing.insert(.listen) }
        if !canPost { missing.insert(.post) }
        return missing
    }
}

enum KeyboardEventAccessRequirement: Equatable, Hashable, Sendable {
    case listen
    case post
}

enum PasteCompatibilitySettingStatus: Equatable, Sendable {
    case ready
    case waitingForAuthorization(missing: Set<KeyboardEventAccessRequirement>)
}

enum KeyboardModifier: Equatable, Hashable, Sendable {
    case control
    case command
    case shift
    case option
}

enum KeyboardEvent: Equatable, Sendable {
    case keyDown(key: String, modifiers: Set<KeyboardModifier>, isSynthetic: Bool = false)
}

enum PasteCompatibilityDecision: Equatable, Sendable {
    case passThrough
    case convertToCommandV
}

final class PasteCompatibilityService {
    private var access: KeyboardEventAccess
    private var armedPasteboardChangeCount: Int?

    init(access: KeyboardEventAccess) {
        self.access = access
    }

    func updateAccess(_ access: KeyboardEventAccess) {
        self.access = access
        if !access.isComplete {
            armedPasteboardChangeCount = nil
        }
    }

    func screenshotCopied(changeCount: Int) {
        armedPasteboardChangeCount = access.isComplete ? changeCount : nil
    }

    func pasteboardDidChange(changeCount: Int) {
        guard let armedPasteboardChangeCount else { return }
        if changeCount != armedPasteboardChangeCount {
            self.armedPasteboardChangeCount = nil
        }
    }

    func handle(_ event: KeyboardEvent) -> PasteCompatibilityDecision {
        guard access.isComplete, armedPasteboardChangeCount != nil else { return .passThrough }

        switch event {
        case let .keyDown(key, modifiers, isSynthetic):
            guard !isSynthetic else { return .passThrough }
            guard key.lowercased() == "v", modifiers == [.control] else { return .passThrough }
            return .convertToCommandV
        }
    }
}

protocol InputCompatibilityPermissionRequester: AnyObject {
    func currentAccess() -> KeyboardEventAccess
}

final class PasteCompatibilityCoordinator {
    private let permissionRequester: InputCompatibilityPermissionRequester
    private let service: PasteCompatibilityService
    private var didPresentInputPostingPermission = false
    private var didNotifyAccessComplete = false
    private var isTextEditingActive = false
    var onAccessBecameComplete: (() -> Void)?
    var onScreenshotCopied: ((Int) -> Void)?
    var onInputPostingPermissionNeeded: (() -> Void)?

    init(permissionRequester: InputCompatibilityPermissionRequester) {
        self.permissionRequester = permissionRequester
        self.service = PasteCompatibilityService(access: permissionRequester.currentAccess())
    }

    var settingStatus: PasteCompatibilitySettingStatus {
        let access = permissionRequester.currentAccess()
        return access.canPost ? .ready : .waitingForAuthorization(missing: [.post])
    }

    @MainActor
    func screenshotCopied(changeCount: Int) {
        refreshAccess()
        if !permissionRequester.currentAccess().canPost, !didPresentInputPostingPermission {
            didPresentInputPostingPermission = true
            onInputPostingPermissionNeeded?()
            refreshAccess()
        }
        notifyAccessCompleteIfNeeded()
        service.screenshotCopied(changeCount: changeCount)
        onScreenshotCopied?(changeCount)
    }

    func pasteboardDidChange(changeCount: Int) {
        service.pasteboardDidChange(changeCount: changeCount)
    }

    func setTextEditingActive(_ isActive: Bool) {
        isTextEditingActive = isActive
    }

    func handle(_ event: KeyboardEvent) -> PasteCompatibilityDecision {
        guard !isTextEditingActive else { return .passThrough }
        refreshAccess()
        return service.handle(event)
    }

    private func refreshAccess() {
        service.updateAccess(permissionRequester.currentAccess())
    }

    private func notifyAccessCompleteIfNeeded() {
        guard !didNotifyAccessComplete, permissionRequester.currentAccess().isComplete else { return }
        didNotifyAccessComplete = true
        onAccessBecameComplete?()
    }
}

final class SystemInputCompatibilityPermissionRequester: InputCompatibilityPermissionRequester {
    func currentAccess() -> KeyboardEventAccess {
        KeyboardEventAccess(
            canListen: CGPreflightListenEventAccess(),
            canPost: CGPreflightPostEventAccess()
        )
    }

}

#endif
