import Foundation

enum PermissionCenterGrantState: Equatable, Sendable {
    case granted
    case notDetermined
    case denied
    case requiresRelaunch
}

struct PermissionCenterInput: Equatable, Sendable {
    var screenCapture: PermissionCenterGrantState
    var inputPosting: PermissionCenterGrantState
    var inputListeningFallback: PermissionCenterGrantState
    var microphone: PermissionCenterGrantState
    var camera: PermissionCenterGrantState
    var controlVPasteEnabled: Bool
    var inputListeningFallbackNeeded: Bool
    var microphoneEnabled: Bool
    var cameraEnabled: Bool
}

enum PermissionCenterKind: Equatable, Hashable, Sendable {
    case screenCapture
    case inputPosting
    case inputListeningFallback
    case microphone
    case camera
}

enum PermissionCenterRowState: Equatable, Sendable {
    case ready
    case notRequested
    case optionalNotRequested
    case needsSettings
    case restartRequired
}

enum PermissionCenterAction: Equatable, Sendable {
    case none
    case requestPermission
    case openSystemSettings
    case restartApp
}

struct PermissionCenterRow: Equatable, Sendable {
    var kind: PermissionCenterKind
    var purpose: String
    var state: PermissionCenterRowState
    var action: PermissionCenterAction
    var isOptional: Bool
}

struct PermissionCenterPlan: Equatable, Sendable {
    var rows: [PermissionCenterRow]
    var platformBoundary: AutomationPlatformBoundary

    func row(for kind: PermissionCenterKind) -> PermissionCenterRow? {
        rows.first { $0.kind == kind }
    }
}

enum PermissionCenterLifecycleEvent: Equatable, Sendable {
    case userOpenedPermissionCenter
    case applicationBecameActive
}

struct PermissionCenterLifecyclePlan: Equatable, Sendable {
    var presentsWindow: Bool
    var refreshesRows: Bool
    var requestsSystemPermission: Bool
}

/// The optional capabilities that raise a permission requirement. Kept as a
/// pure function rather than an inline closure at the composition root so the
/// set of demand sources is reviewable and testable: a feature that is compiled
/// out of a build must not leave a demand behind.
struct PermissionCapabilityDemands: Equatable, Sendable {
    var needsInputListening: Bool
}

enum PermissionCapabilityDemandModel {
    /// Input Monitoring is only needed by capabilities that actually observe
    /// input in this build: the recording click/keystroke overlay, and the
    /// event-tap fallback for shortcuts Carbon refused. DemoType also observed
    /// input, and is deliberately absent here as well as from the binary — the
    /// App Store target compiles it out, so it must not contribute a demand.
    static func demands(
        settings: AppSettings,
        hotkeyFallbackNeeded: Bool
    ) -> PermissionCapabilityDemands {
        PermissionCapabilityDemands(
            needsInputListening: hotkeyFallbackNeeded
                || settings.recordMouseClicks
                || settings.recordShortcutKeys
        )
    }
}

enum PermissionCenterModel {
    static func plan(for input: PermissionCenterInput) -> PermissionCenterPlan {
        PermissionCenterPlan(
            rows: [
                row(
                    kind: .screenCapture,
                    purpose: AppLocalization.string(
                        "permission_center.purpose.screen_capture",
                        defaultValue: "Used for zoom, drawing, screenshots, and screen recording"
                    ),
                    grant: input.screenCapture,
                    isOptional: false,
                    isEnabled: true
                ),
                row(
                    kind: .inputPosting,
                    purpose: AppLocalization.string(
                        "permission_center.purpose.input_posting",
                        defaultValue: "Used to convert ⌃V after a screenshot to native ⌘V"
                    ),
                    grant: input.inputPosting,
                    isOptional: !input.controlVPasteEnabled,
                    isEnabled: input.controlVPasteEnabled
                ),
                row(
                    kind: .inputListeningFallback,
                    purpose: AppLocalization.string(
                        "permission_center.purpose.input_listening",
                        defaultValue: "Used to show clicks and shortcuts in recordings, or listen for fallback hotkeys"
                    ),
                    grant: input.inputListeningFallback,
                    isOptional: true,
                    isEnabled: input.inputListeningFallbackNeeded
                ),
                row(
                    kind: .microphone,
                    purpose: AppLocalization.string(
                        "permission_center.purpose.microphone",
                        defaultValue: "Used to record your voice"
                    ),
                    grant: input.microphone,
                    isOptional: true,
                    isEnabled: input.microphoneEnabled
                ),
                row(
                    kind: .camera,
                    purpose: AppLocalization.string(
                        "permission_center.purpose.camera",
                        defaultValue: "Used to record camera picture-in-picture"
                    ),
                    grant: input.camera,
                    isOptional: true,
                    isEnabled: input.cameraEnabled
                )
            ],
            platformBoundary: .simulatedOnly
        )
    }

    static func lifecyclePlan(for event: PermissionCenterLifecycleEvent) -> PermissionCenterLifecyclePlan {
        switch event {
        case .userOpenedPermissionCenter:
            return PermissionCenterLifecyclePlan(
                presentsWindow: true,
                refreshesRows: true,
                requestsSystemPermission: false
            )
        case .applicationBecameActive:
            return PermissionCenterLifecyclePlan(
                presentsWindow: false,
                refreshesRows: true,
                requestsSystemPermission: false
            )
        }
    }

    private static func row(
        kind: PermissionCenterKind,
        purpose: String,
        grant: PermissionCenterGrantState,
        isOptional: Bool,
        isEnabled: Bool
    ) -> PermissionCenterRow {
        let state: PermissionCenterRowState
        let action: PermissionCenterAction

        switch grant {
        case .granted:
            state = .ready
            action = .none
        case .requiresRelaunch:
            state = .restartRequired
            action = .restartApp
        case .notDetermined:
            if isOptional && !isEnabled {
                state = .optionalNotRequested
                action = .none
            } else {
                state = .notRequested
                action = .requestPermission
            }
        case .denied:
            if isOptional && !isEnabled {
                state = .optionalNotRequested
                action = .none
            } else {
                state = .needsSettings
                action = .openSystemSettings
            }
        }

        return PermissionCenterRow(
            kind: kind,
            purpose: purpose,
            state: state,
            action: action,
            isOptional: isOptional
        )
    }
}
