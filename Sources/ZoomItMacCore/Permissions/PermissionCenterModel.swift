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

enum PermissionCenterModel {
    static func plan(for input: PermissionCenterInput) -> PermissionCenterPlan {
        PermissionCenterPlan(
            rows: [
                row(
                    kind: .screenCapture,
                    purpose: "用于缩放、圈画、截图和录制屏幕内容",
                    grant: input.screenCapture,
                    isOptional: false,
                    isEnabled: true
                ),
                row(
                    kind: .inputPosting,
                    purpose: "用于把截图后的 ⌃V 转换为原生 ⌘V",
                    grant: input.inputPosting,
                    isOptional: !input.controlVPasteEnabled,
                    isEnabled: input.controlVPasteEnabled
                ),
                row(
                    kind: .inputListeningFallback,
                    purpose: "用于显示录制中的点击/快捷键，或监听备用热键",
                    grant: input.inputListeningFallback,
                    isOptional: true,
                    isEnabled: input.inputListeningFallbackNeeded
                ),
                row(
                    kind: .microphone,
                    purpose: "用于录制你的声音",
                    grant: input.microphone,
                    isOptional: true,
                    isEnabled: input.microphoneEnabled
                ),
                row(
                    kind: .camera,
                    purpose: "用于录制摄像头画中画",
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
