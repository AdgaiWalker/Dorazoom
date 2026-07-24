import Foundation

struct ActivationLifecycle {
    enum State: Equatable {
        case idle
        case loading(UUID)
        case active
    }

    private(set) var state: State = .idle

    var isActive: Bool { state == .active }
    var requiresDeactivation: Bool { state != .idle }

    mutating func beginLoading() -> UUID? {
        guard state == .idle else { return nil }
        let token = UUID()
        state = .loading(token)
        return token
    }

    mutating func activate(_ token: UUID) -> Bool {
        guard state == .loading(token) else { return false }
        state = .active
        return true
    }

    mutating func fail(_ token: UUID) -> Bool {
        guard state == .loading(token) else { return false }
        state = .idle
        return true
    }

    mutating func deactivate() -> Bool {
        guard state != .idle else { return false }
        state = .idle
        return true
    }
}
