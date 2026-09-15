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

@MainActor
protocol ScreenRecordingPermissionPrompting: AnyObject {
    func promptForScreenRecordingAccess() -> ScreenRecordingPermissionPromptChoice
}

@MainActor
final class SystemScreenRecordingPermissionPrompter: ScreenRecordingPermissionPrompting {
    func promptForScreenRecordingAccess() -> ScreenRecordingPermissionPromptChoice {
        let alert = NSAlert()
        alert.messageText = AppLocalization.string(
            "screen_recording_permission.title",
            defaultValue: "DoraZoom Needs Screen Recording Access"
        )
        alert.informativeText = AppLocalization.string(
            "screen_recording_permission.message",
            defaultValue: """
            Zoom, drawing, screenshots, screen recording, and panorama capture require macOS to let DoraZoom read screen content.

            After you grant access, macOS may ask DoraZoom to quit. DoraZoom will reopen automatically. Then try Control+1, Control+2, or Control+6 again.
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
    ///
    /// The decision is made by `PermissionGate`, so a failed preflight check is
    /// never presented as a denial — `CGPreflightScreenCaptureAccess()` returns
    /// only a boolean and cannot distinguish "never asked" from "denied". The
    /// arbiter supplies the application-side facts the system does not report:
    /// whether the user has already been prompted, and whether a restart is
    /// still pending.
    @discardableResult
    static func ensureGranted(
        _ service: PermissionService,
        permissionRelaunchCoordinator: PermissionRelaunchCoordinator? = nil,
        permissionArbiter: PermissionFlowArbiter = PermissionFlowArbiter(),
        prompter: ScreenRecordingPermissionPrompting = SystemScreenRecordingPermissionPrompter(),
        now: Date = Date()
    ) -> Bool {
        let hasBeenPrompted = permissionArbiter.hasPrompted(.screenCapture)
        let state = PermissionGate.state(for: PermissionGateSnapshot(
            kind: .screenCapture,
            systemReport: .screenCapture(
                isGranted: service.currentState().screenCapture.isGranted
            ),
            isRequestInFlight: permissionArbiter.inFlight == .screenCapture,
            isWaitingForSettings: hasBeenPrompted,
            restartRequired: permissionArbiter.isRestartPending(.screenCapture),
            hasUserBeenPrompted: hasBeenPrompted
        ))

        if state.canProceed {
            // Authorization is in effect now; nothing is left to wait for.
            permissionArbiter.clearRestartPending(.screenCapture)
            return true
        }

        // Already asked, already refused, or a request is outstanding. Asking
        // again here is what produced stacked prompts before.
        guard state.canRequestAuthorization else { return false }
        guard permissionArbiter.beginFlow(.screenCapture) else { return false }

        guard prompter.promptForScreenRecordingAccess() == .continueToSystemPrompt else {
            // Cancelling ends this attempt only; clicking the feature again
            // still raises the explanation, matching "取消后仍能继续".
            permissionArbiter.endFlow()
            return false
        }

        permissionRelaunchCoordinator?.notePermissionFlowMayRequireRelaunch(now: now)
        permissionArbiter.markRestartPending(.screenCapture)
        permissionArbiter.waitForSettings(.screenCapture)
        // macOS owns the system prompt and its Settings link. A false return
        // also occurs while authorization is pending; do not open a second UI.
        _ = service.requestScreenCaptureAccess()
        return false
    }
}
