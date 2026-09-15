import AppKit
import AVFoundation
import CoreGraphics

enum PermissionCenterPlatformAction: Equatable, Sendable {
    case requestScreenCapture
    case requestInputPosting
    case requestInputListening
    case requestMicrophone
    case requestCamera
    case openSettings(PermissionCenterKind)
}

@MainActor
protocol PermissionCenterPlatformAccess: AnyObject {
    func isScreenCaptureGranted() -> Bool
    func currentInputAccess() -> KeyboardEventAccess
    func microphoneStatus() -> MicrophonePermission
    func cameraStatus() -> MicrophonePermission
    func requestScreenCapture() -> Bool
    func requestInputPosting() -> Bool
    func requestInputListening() -> Bool
    func requestMicrophone(completion: @escaping @MainActor @Sendable () -> Void)
    func requestCamera(completion: @escaping @MainActor @Sendable () -> Void)
    func openSystemSettings(for kind: PermissionCenterKind)
}

@MainActor
protocol PermissionCenterRestarting: AnyObject {
    func restart()
}

@MainActor
final class PermissionCenterRestartIntent: PermissionCenterRestarting {
    private let terminate: () -> Void
    private(set) var isRequested = false

    init(terminate: @escaping () -> Void = { NSApplication.shared.terminate(nil) }) {
        self.terminate = terminate
    }

    func restart() {
        isRequested = true
        terminate()
    }

    func consume() -> Bool {
        defer { isRequested = false }
        return isRequested
    }
}

@MainActor
final class PermissionCenterSystemAdapter {
    private let platformAccess: PermissionCenterPlatformAccess
    private let restarter: PermissionCenterRestarting
    private let settingsProvider: () -> AppSettings
    private let inputListeningFallbackNeeded: () -> Bool
    private let onStateChanged: () -> Void
    private var requestedKinds: Set<PermissionCenterKind> = []
    private var relaunchKinds: Set<PermissionCenterKind> = []

    init(
        platformAccess: PermissionCenterPlatformAccess,
        restarter: PermissionCenterRestarting,
        settingsProvider: @escaping () -> AppSettings,
        inputListeningFallbackNeeded: @escaping () -> Bool,
        onStateChanged: @escaping () -> Void = {}
    ) {
        self.platformAccess = platformAccess
        self.restarter = restarter
        self.settingsProvider = settingsProvider
        self.inputListeningFallbackNeeded = inputListeningFallbackNeeded
        self.onStateChanged = onStateChanged
    }

    func plan() -> PermissionCenterPlan {
        let settings = settingsProvider()
        let inputAccess = platformAccess.currentInputAccess()
        let controlVPasteEnabled = true
        return PermissionCenterModel.plan(for: PermissionCenterInput(
            screenCapture: grantState(
                kind: .screenCapture,
                isGranted: platformAccess.isScreenCaptureGranted()
            ),
            inputPosting: grantState(kind: .inputPosting, isGranted: inputAccess.canPost),
            inputListeningFallback: grantState(
                kind: .inputListeningFallback,
                isGranted: inputAccess.canListen
            ),
            microphone: mediaGrantState(kind: .microphone, status: platformAccess.microphoneStatus()),
            camera: mediaGrantState(kind: .camera, status: platformAccess.cameraStatus()),
            controlVPasteEnabled: controlVPasteEnabled,
            inputListeningFallbackNeeded: inputListeningFallbackNeeded(),
            microphoneEnabled: settings.recordMicrophone,
            cameraEnabled: settings.webcamEnabled
        ))
    }

    func perform(_ kind: PermissionCenterKind, action: PermissionCenterAction) {
        switch action {
        case .none:
            return
        case .openSystemSettings:
            platformAccess.openSystemSettings(for: kind)
        case .restartApp:
            restarter.restart()
        case .requestPermission:
            request(kind)
        }
    }

    private func request(_ kind: PermissionCenterKind) {
        requestedKinds.insert(kind)
        switch kind {
        case .screenCapture:
            if platformAccess.requestScreenCapture() {
                relaunchKinds.insert(kind)
            }
            onStateChanged()
        case .inputPosting:
            if platformAccess.requestInputPosting() {
                relaunchKinds.insert(kind)
            }
            onStateChanged()
        case .inputListeningFallback:
            if platformAccess.requestInputListening() {
                relaunchKinds.insert(kind)
            }
            onStateChanged()
        case .microphone:
            platformAccess.requestMicrophone { [weak self] in
                self?.onStateChanged()
            }
        case .camera:
            platformAccess.requestCamera { [weak self] in
                self?.onStateChanged()
            }
        }
    }

    private func grantState(kind: PermissionCenterKind, isGranted: Bool) -> PermissionCenterGrantState {
        if isGranted { return .granted }
        if relaunchKinds.contains(kind) { return .requiresRelaunch }
        return requestedKinds.contains(kind) ? .denied : .notDetermined
    }

    private func mediaGrantState(
        kind: PermissionCenterKind,
        status: MicrophonePermission
    ) -> PermissionCenterGrantState {
        switch status {
        case .granted:
            return .granted
        case .notDetermined:
            return requestedKinds.contains(kind) ? .denied : .notDetermined
        case .denied:
            return .denied
        }
    }
}

@MainActor
final class SystemPermissionCenterPlatformAccess: PermissionCenterPlatformAccess {
    private let permissionService: PermissionService
    private let inputPermissionRequester: InputCompatibilityPermissionRequester

    init(
        permissionService: PermissionService,
        inputPermissionRequester: InputCompatibilityPermissionRequester
    ) {
        self.permissionService = permissionService
        self.inputPermissionRequester = inputPermissionRequester
    }

    func isScreenCaptureGranted() -> Bool {
        permissionService.currentState().screenCapture.isGranted
    }

    func currentInputAccess() -> KeyboardEventAccess {
        inputPermissionRequester.currentAccess()
    }

    func microphoneStatus() -> MicrophonePermission {
        permissionService.microphoneStatus()
    }

    func cameraStatus() -> MicrophonePermission {
        permissionService.cameraStatus()
    }

    func requestScreenCapture() -> Bool {
        permissionService.requestScreenCaptureAccess()
    }

    func requestInputPosting() -> Bool {
        CGRequestPostEventAccess()
    }

    func requestInputListening() -> Bool {
        CGRequestListenEventAccess()
    }

    func requestMicrophone(completion: @escaping @MainActor @Sendable () -> Void) {
        permissionService.requestMicrophoneAccess(completion: completion)
    }

    func requestCamera(completion: @escaping @MainActor @Sendable () -> Void) {
        permissionService.requestCameraAccess(completion: completion)
    }

    func openSystemSettings(for kind: PermissionCenterKind) {
        switch kind {
        case .screenCapture:
            permissionService.openSystemSettings()
        case .inputPosting:
            openPrivacySettings(anchor: "Privacy_Accessibility")
        case .inputListeningFallback:
            openPrivacySettings(anchor: "Privacy_ListenEvent")
        case .microphone:
            permissionService.openMicrophoneSettings()
        case .camera:
            permissionService.openCameraSettings()
        }
    }

    private func openPrivacySettings(anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
