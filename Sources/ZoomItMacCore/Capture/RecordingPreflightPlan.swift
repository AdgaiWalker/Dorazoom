import Foundation

struct RecordingPreflightAudioSelection: Equatable, Sendable {
    var systemAudio: Bool
    var microphone: Bool

    init(settings: AppSettings) {
        systemAudio = settings.recordSystemAudio
        microphone = settings.recordMicrophone
    }

    func apply(to settings: inout AppSettings) {
        settings.recordSystemAudio = systemAudio
        settings.recordMicrophone = microphone
    }
}

enum RecordingPreflightPermission: Equatable, Sendable {
    case notRequested
    case allowed
    case denied
}

enum RecordingPreflightAvailability: Equatable, Sendable {
    case available
    case unavailable
}

enum RecordingPreflightLevel: Equatable, Sendable {
    case audible(Float)
    case silent
    case unknown
    case notApplicable
}

enum RecordingPreflightSource: Equatable, Sendable {
    case disabled
    case enabled(
        permission: RecordingPreflightPermission,
        availability: RecordingPreflightAvailability,
        level: RecordingPreflightLevel
    )
}

struct RecordingPreflightInput: Equatable, Sendable {
    var targetName: String
    var targetAvailable: Bool
    var availableDiskBytes: Int64
    var requiredDiskBytes: Int64
    var systemAudio: RecordingPreflightSource
    var microphone: RecordingPreflightSource
    var camera: RecordingPreflightSource
}

enum RecordingPreflightDecision: Equatable, Sendable {
    case ready
    case requiresConfirmation
    case blocked
}

enum RecordingPreflightIssue: Equatable, Sendable {
    case targetUnavailable
    case insufficientDisk(requiredBytes: Int64, availableBytes: Int64)
    case systemAudioPermissionRequired
    case systemAudioUnavailable
    case systemAudioSilent
    case microphonePermissionRequired
    case microphoneUnavailable
    case microphoneSilent
    case cameraPermissionRequired
    case cameraUnavailable
}

enum RecordingPreflightRowKind: Equatable, Sendable {
    case target
    case disk
    case systemAudio
    case microphone
    case camera
}

enum RecordingPreflightRowStatus: Equatable, Sendable {
    case ready
    case disabled
    case warning
    case blocked
}

struct RecordingPreflightRow: Equatable, Sendable {
    var kind: RecordingPreflightRowKind
    var status: RecordingPreflightRowStatus
    var detail: String
}

struct RecordingPreflightPlan: Equatable, Sendable {
    var decision: RecordingPreflightDecision
    var issues: [RecordingPreflightIssue]
    var rows: [RecordingPreflightRow]
    var requestsOptionalPermission: Bool
    var platformBoundary: AutomationPlatformBoundary

    func row(for kind: RecordingPreflightRowKind) -> RecordingPreflightRow? {
        rows.first(where: { $0.kind == kind })
    }
}

enum RecordingPreflightPlanner {
    static func plan(_ input: RecordingPreflightInput) -> RecordingPreflightPlan {
        var issues: [RecordingPreflightIssue] = []
        var rows: [RecordingPreflightRow] = []

        if input.targetAvailable {
            rows.append(.init(kind: .target, status: .ready, detail: input.targetName))
        } else {
            issues.append(.targetUnavailable)
            rows.append(.init(kind: .target, status: .blocked, detail: "录制目标已不可用"))
        }

        if input.availableDiskBytes >= input.requiredDiskBytes {
            rows.append(.init(kind: .disk, status: .ready, detail: "空间充足"))
        } else {
            issues.append(.insufficientDisk(
                requiredBytes: input.requiredDiskBytes,
                availableBytes: input.availableDiskBytes
            ))
            rows.append(.init(kind: .disk, status: .blocked, detail: "可用空间不足"))
        }

        rows.append(sourceRow(
            kind: .systemAudio,
            source: input.systemAudio,
            issues: &issues
        ))
        rows.append(sourceRow(
            kind: .microphone,
            source: input.microphone,
            issues: &issues
        ))
        rows.append(sourceRow(
            kind: .camera,
            source: input.camera,
            issues: &issues
        ))

        let hasBlocker = rows.contains(where: { $0.status == .blocked })
        let hasWarning = rows.contains(where: { $0.status == .warning })
        let decision: RecordingPreflightDecision = hasBlocker
            ? .blocked
            : (hasWarning ? .requiresConfirmation : .ready)
        let requestsOptionalPermission = issues.contains(.microphonePermissionRequired)
            || issues.contains(.cameraPermissionRequired)

        return RecordingPreflightPlan(
            decision: decision,
            issues: issues,
            rows: rows,
            requestsOptionalPermission: requestsOptionalPermission,
            platformBoundary: .simulatedOnly
        )
    }

    private static func sourceRow(
        kind: RecordingPreflightRowKind,
        source: RecordingPreflightSource,
        issues: inout [RecordingPreflightIssue]
    ) -> RecordingPreflightRow {
        guard case let .enabled(permission, availability, level) = source else {
            return .init(kind: kind, status: .disabled, detail: "未启用")
        }
        guard permission == .allowed else {
            issues.append(permissionIssue(for: kind))
            return .init(kind: kind, status: .blocked, detail: "需要权限")
        }
        guard availability == .available else {
            issues.append(unavailableIssue(for: kind))
            return .init(kind: kind, status: .blocked, detail: "输入不可用")
        }
        switch level {
        case .silent:
            if let issue = silentIssue(for: kind) {
                issues.append(issue)
            }
            return .init(kind: kind, status: .warning, detail: "未检测到声音")
        case .unknown:
            return .init(kind: kind, status: .warning, detail: "无法确认当前电平")
        case .audible(let level):
            return .init(kind: kind, status: .ready, detail: "电平 \(Int(level * 100))%")
        case .notApplicable:
            return .init(kind: kind, status: .ready, detail: "已就绪")
        }
    }

    private static func permissionIssue(for kind: RecordingPreflightRowKind) -> RecordingPreflightIssue {
        switch kind {
        case .systemAudio: .systemAudioPermissionRequired
        case .microphone: .microphonePermissionRequired
        case .camera: .cameraPermissionRequired
        case .target, .disk: .targetUnavailable
        }
    }

    private static func unavailableIssue(for kind: RecordingPreflightRowKind) -> RecordingPreflightIssue {
        switch kind {
        case .systemAudio: .systemAudioUnavailable
        case .microphone: .microphoneUnavailable
        case .camera: .cameraUnavailable
        case .target, .disk: .targetUnavailable
        }
    }

    private static func silentIssue(for kind: RecordingPreflightRowKind) -> RecordingPreflightIssue? {
        switch kind {
        case .systemAudio: .systemAudioSilent
        case .microphone: .microphoneSilent
        case .camera, .target, .disk: nil
        }
    }
}
