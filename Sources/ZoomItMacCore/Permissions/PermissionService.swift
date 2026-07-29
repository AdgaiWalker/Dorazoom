import AppKit
import AVFoundation

struct PermissionStatus: Equatable {
    var isGranted: Bool
}

/// Tri-state microphone permission, matching the system's authorization states.
enum MicrophonePermission: Equatable {
    case granted
    case denied
    case notDetermined
}

struct PermissionState: Equatable {
    var screenCapture: PermissionStatus
}

protocol PermissionService {
    func currentState() -> PermissionState
    func requestScreenCaptureAccess() -> Bool
    func openSystemSettings()
    func microphoneStatus() -> MicrophonePermission
    func requestMicrophoneAccess(completion: (@MainActor @Sendable () -> Void)?)
    func openMicrophoneSettings()
    func cameraStatus() -> MicrophonePermission
    func requestCameraAccess(completion: (@MainActor @Sendable () -> Void)?)
    func openCameraSettings()
}

final class SystemPermissionService: PermissionService {
    func currentState() -> PermissionState {
        PermissionState(
            screenCapture: PermissionStatus(isGranted: CGPreflightScreenCaptureAccess())
        )
    }

    func requestScreenCaptureAccess() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }

    func microphoneStatus() -> MicrophonePermission {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .granted
        case .notDetermined:
            return .notDetermined
        default:
            return .denied
        }
    }

    func requestMicrophoneAccess(completion: (@MainActor @Sendable () -> Void)? = nil) {
        // Safe because the executable embeds an NSMicrophoneUsageDescription.
        AVCaptureDevice.requestAccess(for: .audio) { _ in
            guard let completion else { return }
            Task { @MainActor in completion() }
        }
    }

    func openMicrophoneSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else { return }
        NSWorkspace.shared.open(url)
    }

    func cameraStatus() -> MicrophonePermission {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .granted
        case .notDetermined:
            return .notDetermined
        default:
            return .denied
        }
    }

    func requestCameraAccess(completion: (@MainActor @Sendable () -> Void)? = nil) {
        // Safe because the executable embeds an NSCameraUsageDescription.
        AVCaptureDevice.requestAccess(for: .video) { _ in
            guard let completion else { return }
            Task { @MainActor in completion() }
        }
    }

    func openCameraSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else { return }
        NSWorkspace.shared.open(url)
    }
}

enum ScreenRecordingPermissionPromptChoice: Equatable, Sendable {
    case continueToSystemPrompt
    case cancel
}

enum ScreenRecordingPermissionAction: Equatable, Sendable {
    case granted
    case promptForAuthorization
    case waitForRelaunch
}

/// Keeps the Screen Recording explanation one-shot for the app run while macOS
/// is still applying a newly granted permission.
@MainActor
final class ScreenRecordingPermissionSession {
    private var didPromptForAuthorization = false

    func action(isGranted: Bool) -> ScreenRecordingPermissionAction {
        if isGranted {
            return .granted
        }
        guard !didPromptForAuthorization else {
            return .waitForRelaunch
        }
        didPromptForAuthorization = true
        return .promptForAuthorization
    }
}

@MainActor
protocol ScreenRecordingPermissionPrompting: AnyObject {
    func promptForScreenRecordingAccess() -> ScreenRecordingPermissionPromptChoice
}

@MainActor
final class SystemScreenRecordingPermissionPrompter: ScreenRecordingPermissionPrompting {
    func promptForScreenRecordingAccess() -> ScreenRecordingPermissionPromptChoice {
        let alert = NSAlert()
        alert.messageText = "DoraZoom 需要屏幕录制权限"
        alert.informativeText = """
        Zoom、绘画、截图、录制和全景截图都需要 macOS 允许 DoraZoom 读取屏幕内容。

        授权后 macOS 可能会要求 DoraZoom 退出；DoraZoom 会自动重新打开。然后再按 Control+1、Control+2 或 Control+6 测试。
        """
        alert.addButton(withTitle: "继续授权")
        alert.addButton(withTitle: "稍后")
        return alert.runModal() == .alertFirstButtonReturn ? .continueToSystemPrompt : .cancel
    }
}

/// Shared gate for the required Screen Recording permission. Capture hotkeys use
/// a lightweight explanatory prompt before the macOS permission prompt so a
/// hotkey never appears to do nothing.
@MainActor
enum ScreenRecordingPrompt {
    /// Returns true if Screen Recording is granted. Otherwise it asks macOS to
    /// request/register the permission and returns false.
    @discardableResult
    static func ensureGranted(
        _ service: PermissionService,
        permissionRelaunchCoordinator: PermissionRelaunchCoordinator? = nil,
        permissionSession: ScreenRecordingPermissionSession = ScreenRecordingPermissionSession(),
        prompter: ScreenRecordingPermissionPrompting = SystemScreenRecordingPermissionPrompter(),
        now: Date = Date()
    ) -> Bool {
        switch permissionSession.action(isGranted: service.currentState().screenCapture.isGranted) {
        case .granted:
            return true
        case .waitForRelaunch:
            return false
        case .promptForAuthorization:
            break
        }
        guard prompter.promptForScreenRecordingAccess() == .continueToSystemPrompt else { return false }

        permissionRelaunchCoordinator?.notePermissionFlowMayRequireRelaunch(now: now)
        let granted = service.requestScreenCaptureAccess()
        if !granted {
            service.openSystemSettings()
        }
        return false
    }
}
