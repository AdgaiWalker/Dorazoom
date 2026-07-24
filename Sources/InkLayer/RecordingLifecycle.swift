struct RecordingLifecycle {
    enum State: Equatable {
        case idle
        case starting
        case recording
        case stopping
    }

    private(set) var state: State = .idle

    mutating func requestStart() -> Bool {
        guard state == .idle else { return false }
        state = .starting
        return true
    }

    mutating func didStart() -> Bool {
        guard state == .starting else { return false }
        state = .recording
        return true
    }

    mutating func requestStop() -> Bool {
        guard state == .recording else { return false }
        state = .stopping
        return true
    }

    mutating func didFinish() {
        state = .idle
    }
}
