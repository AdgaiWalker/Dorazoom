import Foundation

@MainActor
final class PermissionRelaunchCoordinator {
    private let relaunchWindowSeconds: TimeInterval
    private var relaunchUntil: Date?

    init(relaunchWindowSeconds: TimeInterval = 120) {
        self.relaunchWindowSeconds = relaunchWindowSeconds
    }

    func notePermissionFlowMayRequireRelaunch(now: Date = Date()) {
        relaunchUntil = now.addingTimeInterval(relaunchWindowSeconds)
    }

    func noteExplicitQuit() {
        relaunchUntil = nil
    }

    func consumeRelaunchRequest(now: Date = Date()) -> Bool {
        guard let deadline = relaunchUntil else { return false }
        relaunchUntil = nil
        return now <= deadline
    }
}
