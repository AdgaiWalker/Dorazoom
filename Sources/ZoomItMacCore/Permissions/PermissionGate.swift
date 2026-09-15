import Foundation

/// A capability DoraZoom can ask macOS for. The flow differs per kind because
/// macOS reports different amounts of information about each one.
enum PermissionKind: String, CaseIterable, Sendable {
    case screenCapture
    case microphone
    case camera
}

/// What macOS actually told us, with no application-side inference.
///
/// Screen Recording is intentionally `inconclusive` when the preflight check
/// fails: `CGPreflightScreenCaptureAccess()` returns only a boolean, so a
/// `false` result cannot be read as "the user denied this". Microphone and
/// camera come from `AVCaptureDevice.authorizationStatus`, which does report
/// denial explicitly.
enum PermissionSystemReport: Equatable, Sendable {
    /// macOS reports the capability as authorized.
    case granted
    /// macOS reports the app has never asked.
    case notDetermined
    /// macOS explicitly reports the user denied (or policy blocked) access.
    case denied
    /// The system does not distinguish "never asked" from "denied".
    case inconclusive

    static func screenCapture(isGranted: Bool) -> PermissionSystemReport {
        isGranted ? .granted : .inconclusive
    }

    static func media(_ permission: MicrophonePermission) -> PermissionSystemReport {
        switch permission {
        case .granted:
            return .granted
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        }
    }
}

/// The recoverable states of one permission flow. This is an application-flow
/// state, not a macOS state: every value here has to be reachable from
/// something the system actually tells us, or from an action we took.
enum PermissionGateState: Equatable, Sendable {
    /// Authorized and effective right now; the feature may run.
    case available
    /// The app has never asked. Asking is the user's decision, not ours.
    case needsUserAction
    /// macOS explicitly refused. Asking again will not produce a prompt.
    case denied
    /// A system authorization request is currently outstanding.
    case requesting
    /// We handed off to System Settings and are waiting for the user to return.
    case waitingForSettings
    /// Authorized, but macOS needs the app restarted before it takes effect.
    case requiresRestart
    /// This capability is not used by the current build, so it is never asked for.
    case unavailable

    /// Only a fully effective authorization lets a feature run.
    var canProceed: Bool {
        self == .available
    }

    /// Whether a new system prompt may be raised from this state. States that
    /// already consumed the user's attention must not prompt again.
    var canRequestAuthorization: Bool {
        self == .needsUserAction
    }
}

/// Everything the gate needs to know, assembled by the caller from the system
/// and from the application's own flow tracking.
struct PermissionGateSnapshot: Equatable, Sendable {
    var kind: PermissionKind
    var systemReport: PermissionSystemReport
    /// The build actually ships this capability.
    var isAvailableInBuild: Bool
    /// A system authorization request for this flow is outstanding.
    var isRequestInFlight: Bool
    /// The user has already been sent to System Settings for this flow.
    var isWaitingForSettings: Bool
    /// The app asked for a restart because this authorization could not apply
    /// in the current process. Only meaningful while authorization is still
    /// pending — once macOS reports `granted`, the permission is in effect and
    /// this flag must not hold the feature back.
    var restartRequired: Bool
    /// The user has already been prompted for this flow during this app run.
    /// Needed because an `inconclusive` report is the same before and after
    /// asking, so the prompt history has to disambiguate.
    var hasUserBeenPrompted: Bool

    init(
        kind: PermissionKind,
        systemReport: PermissionSystemReport,
        isAvailableInBuild: Bool = true,
        isRequestInFlight: Bool = false,
        isWaitingForSettings: Bool = false,
        restartRequired: Bool = false,
        hasUserBeenPrompted: Bool = false
    ) {
        self.kind = kind
        self.systemReport = systemReport
        self.isAvailableInBuild = isAvailableInBuild
        self.isRequestInFlight = isRequestInFlight
        self.isWaitingForSettings = isWaitingForSettings
        self.restartRequired = restartRequired
        self.hasUserBeenPrompted = hasUserBeenPrompted
    }
}

/// Turns a snapshot into a state. Deliberately pure so the whole permission
/// matrix is testable without touching macOS.
enum PermissionGate {
    static func state(for snapshot: PermissionGateSnapshot) -> PermissionGateState {
        guard snapshot.isAvailableInBuild else { return .unavailable }

        switch snapshot.systemReport {
        case .granted:
            // macOS reports authorization, so the permission is in effect.
            // A pending restart must not override a granted report: the
            // preflight check only returns true once it actually applies.
            return .available

        case .denied:
            return .denied

        case .notDetermined:
            if snapshot.isRequestInFlight { return .requesting }
            return .needsUserAction

        case .inconclusive:
            if snapshot.isRequestInFlight { return .requesting }
            if snapshot.isWaitingForSettings {
                return snapshot.restartRequired ? .requiresRestart : .waitingForSettings
            }
            // Before the user has been asked, an inconclusive report means the
            // capability was simply never requested. After they have been
            // asked, the same report means authorization is still pending.
            return snapshot.hasUserBeenPrompted
                ? (snapshot.restartRequired ? .requiresRestart : .waitingForSettings)
                : .needsUserAction
        }
    }
}

/// Enforces "one authorization flow at a time" and remembers which flows
/// already consumed a prompt during this app run, so repeated clicks on a
/// feature cannot stack system prompts.
@MainActor
final class PermissionFlowArbiter {
    private(set) var inFlight: PermissionKind?
    private var prompted: Set<PermissionKind> = []
    private var restartPending: Set<PermissionKind> = []

    /// Starts a flow. Returns false when another flow is already running, so
    /// the caller must not raise a second prompt.
    func beginFlow(_ kind: PermissionKind) -> Bool {
        guard inFlight == nil else { return false }
        inFlight = kind
        prompted.insert(kind)
        return true
    }

    /// Marks the flow as handed off to System Settings; the request is no
    /// longer outstanding but the user has not returned yet.
    func waitForSettings(_ kind: PermissionKind) {
        if inFlight == kind { inFlight = nil }
    }

    /// Ends the current flow, whether it was granted, denied, or cancelled.
    /// A cancel is recoverable: the user can click the feature again.
    func endFlow() {
        inFlight = nil
    }

    func hasPrompted(_ kind: PermissionKind) -> Bool {
        prompted.contains(kind)
    }

    /// Records that macOS asked the app to restart before this authorization
    /// can apply, so the next check reports `requiresRestart` instead of
    /// silently looking like "never asked".
    func markRestartPending(_ kind: PermissionKind) {
        restartPending.insert(kind)
    }

    func isRestartPending(_ kind: PermissionKind) -> Bool {
        restartPending.contains(kind)
    }

    /// Called once the authorization is actually in effect.
    func clearRestartPending(_ kind: PermissionKind) {
        restartPending.remove(kind)
    }

    /// Used when the app is about to quit and restart, so the new process does
    /// not inherit stale flow state. The prompt history is kept so the user is
    /// not re-asked immediately after a relaunch that macOS triggered.
    func prepareForRelaunch() {
        inFlight = nil
    }

    func reset() {
        inFlight = nil
        prompted.removeAll()
        restartPending.removeAll()
    }
}
