import Foundation

struct AppLifecycleSimulationLock: Equatable, Sendable {
    private(set) var isClaimed = false
    var touchesFilesystem = false
    var postsDistributedNotifications = false

    mutating func claim() -> Bool {
        guard !isClaimed else { return false }
        isClaimed = true
        return true
    }

    mutating func release() {
        isClaimed = false
    }
}

enum AppLifecycleNotification: Equatable, Hashable, Sendable {
    case showSettings
}

enum AppLifecycleSingleInstanceDecision: Equatable, Sendable {
    case continueLaunch
    case activateExistingAndTerminate
    case released
}

struct AppLifecycleSingleInstanceResult: Equatable, Sendable {
    var decision: AppLifecycleSingleInstanceDecision
    var postedNotifications: [AppLifecycleNotification]
    var platformBoundary: AutomationPlatformBoundary
}

enum AppLifecycleMenuIcon: Equatable, Sendable {
    case templateIdle
    case templateActive
    case recordingRed
}

struct AppLifecycleMenuBarPlan: Equatable, Sendable {
    var feedback: MenuBarFeedback
    var icon: AppLifecycleMenuIcon
    var menu: StatusMenuPlan
    var platformBoundary: AutomationPlatformBoundary
    var createsRealStatusItem: Bool
}

enum AppLifecycleSimulationLoginItemStatus: Equatable, Sendable {
    case notRegistered
    case enabled
    case requiresApproval

    var isEnabledOrPending: Bool {
        self == .enabled || self == .requiresApproval
    }
}

enum AppLifecycleSimulationLoginItemOperation: Equatable, Sendable {
    case register
    case unregister
}

enum AppLifecycleSimulationLoginItemAlert: Equatable, Sendable {
    case requiresAppBundle
}

struct AppLifecycleSimulationLoginItemService: Equatable, Sendable {
    var status: AppLifecycleSimulationLoginItemStatus
    var isAppBundle: Bool
    var touchesServiceManagement = false
}

struct AppLifecycleLaunchAtLoginResult: Equatable, Sendable {
    var preference: Bool
    var projectedStatus: AppLifecycleSimulationLoginItemStatus
    var operations: [AppLifecycleSimulationLoginItemOperation]
    var alert: AppLifecycleSimulationLoginItemAlert?
    var platformBoundary: AutomationPlatformBoundary
}

enum AppLifecycleLaunchMigrationReason: Equatable, Sendable {
    case savedPreferencePresent
    case systemEnabledOrPending
    case unchanged
}

struct AppLifecycleLaunchMigrationResult: Equatable {
    var settings: AppSettings
    var reason: AppLifecycleLaunchMigrationReason
    var platformBoundary: AutomationPlatformBoundary
}

enum AppLifecycleManagementSimulation {
    static func claimSingleInstance(lock: inout AppLifecycleSimulationLock) -> AppLifecycleSingleInstanceResult {
        if lock.claim() {
            return .init(decision: .continueLaunch, postedNotifications: [], platformBoundary: .simulatedOnly)
        }

        return .init(
            decision: .activateExistingAndTerminate,
            postedNotifications: [.showSettings],
            platformBoundary: .simulatedOnly
        )
    }

    static func releaseSingleInstance(lock: inout AppLifecycleSimulationLock) -> AppLifecycleSingleInstanceResult {
        lock.release()
        return .init(decision: .released, postedNotifications: [], platformBoundary: .simulatedOnly)
    }

    static func menuBarPlan(
        for state: AppSessionState,
        permissions: PermissionCenterPlan,
        settings: AppSettings
    ) -> AppLifecycleMenuBarPlan {
        let feedback = InteractionPresentationSnapshot.derive(from: state).menuBar
        return AppLifecycleMenuBarPlan(
            feedback: feedback,
            icon: icon(for: feedback),
            menu: StatusMenuPlan.make(
                status: runtimeStatus(for: feedback),
                permissions: permissions,
                settings: settings
            ),
            platformBoundary: .simulatedOnly,
            createsRealStatusItem: false
        )
    }

    static func setLaunchAtLoginPreference(
        _ enabled: Bool,
        service: inout AppLifecycleSimulationLoginItemService
    ) -> AppLifecycleLaunchAtLoginResult {
        guard service.isAppBundle else {
            return .init(
                preference: enabled,
                projectedStatus: service.status,
                operations: [],
                alert: .requiresAppBundle,
                platformBoundary: .simulatedOnly
            )
        }

        if enabled {
            if service.status != .enabled {
                service.status = .enabled
                return .init(
                    preference: true,
                    projectedStatus: service.status,
                    operations: [.register],
                    alert: nil,
                    platformBoundary: .simulatedOnly
                )
            }
        } else if service.status != .notRegistered {
            service.status = .notRegistered
            return .init(
                preference: false,
                projectedStatus: service.status,
                operations: [.unregister],
                alert: nil,
                platformBoundary: .simulatedOnly
            )
        }

        return .init(
            preference: enabled,
            projectedStatus: service.status,
            operations: [],
            alert: nil,
            platformBoundary: .simulatedOnly
        )
    }

    static func migrateLaunchAtLoginPreferenceIfNeeded(
        hasSavedPreference: Bool,
        currentSettings: AppSettings,
        service: AppLifecycleSimulationLoginItemService
    ) -> AppLifecycleLaunchMigrationResult {
        guard !hasSavedPreference else {
            return .init(settings: currentSettings, reason: .savedPreferencePresent, platformBoundary: .simulatedOnly)
        }

        guard service.isAppBundle, service.status.isEnabledOrPending else {
            return .init(settings: currentSettings, reason: .unchanged, platformBoundary: .simulatedOnly)
        }

        var migrated = currentSettings
        migrated.launchAtLogin = true
        return .init(settings: migrated, reason: .systemEnabledOrPending, platformBoundary: .simulatedOnly)
    }

    private static func icon(for feedback: MenuBarFeedback) -> AppLifecycleMenuIcon {
        switch feedback {
        case .idle:
            return .templateIdle
        case .active:
            return .templateActive
        case .recording:
            return .recordingRed
        }
    }

    private static func runtimeStatus(for feedback: MenuBarFeedback) -> StatusMenuRuntimeStatus {
        switch feedback {
        case .idle:
            .idle
        case .active:
            .active
        case .recording:
            .recording
        }
    }
}
