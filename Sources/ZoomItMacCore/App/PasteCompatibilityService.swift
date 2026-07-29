import CoreGraphics
import AppKit

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

struct InputCompatibilityAccessExplanation: Equatable, Sendable {
    let title: String
    let message: String

    static let controlVPaste = InputCompatibilityAccessExplanation(
        title: "启用 ⌃V 粘贴截图",
        message: "DoraZoom 可以把刚截取的图片用 ⌃V 粘贴。macOS 需要在“辅助功能”中允许 DoraZoom 发送原生 ⌘V；DoraZoom 不读取你的按键内容。未授权时仍可直接使用 ⌘V。"
    )
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
    @MainActor
    func explainAndRequestInputCompatibilityAccess()
}

final class PasteCompatibilityCoordinator {
    private let permissionRequester: InputCompatibilityPermissionRequester
    private let service: PasteCompatibilityService
    private var didRequestInputCompatibility = false
    private var didNotifyAccessComplete = false
    var onAccessBecameComplete: (() -> Void)?
    var onScreenshotCopied: ((Int) -> Void)?

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
        if !permissionRequester.currentAccess().canPost, !didRequestInputCompatibility {
            didRequestInputCompatibility = true
            permissionRequester.explainAndRequestInputCompatibilityAccess()
            refreshAccess()
        }
        notifyAccessCompleteIfNeeded()
        service.screenshotCopied(changeCount: changeCount)
        onScreenshotCopied?(changeCount)
    }

    func pasteboardDidChange(changeCount: Int) {
        service.pasteboardDidChange(changeCount: changeCount)
    }

    func handle(_ event: KeyboardEvent) -> PasteCompatibilityDecision {
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
    private let permissionRelaunchCoordinator: PermissionRelaunchCoordinator?

    init(permissionRelaunchCoordinator: PermissionRelaunchCoordinator? = nil) {
        self.permissionRelaunchCoordinator = permissionRelaunchCoordinator
    }

    func currentAccess() -> KeyboardEventAccess {
        KeyboardEventAccess(
            canListen: CGPreflightListenEventAccess(),
            canPost: CGPreflightPostEventAccess()
        )
    }

    @MainActor
    func explainAndRequestInputCompatibilityAccess() {
        let explanation = InputCompatibilityAccessExplanation.controlVPaste
        let alert = NSAlert()
        alert.messageText = explanation.title
        alert.informativeText = explanation.message
        alert.addButton(withTitle: "继续")
        alert.addButton(withTitle: "稍后")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        if !CGPreflightPostEventAccess() {
            permissionRelaunchCoordinator?.notePermissionFlowMayRequireRelaunch()
        }
        if !CGPreflightPostEventAccess() {
            _ = CGRequestPostEventAccess()
        }
    }
}
