import Foundation

@MainActor
final class HotkeyCaptureSession {
    enum State: Equatable, Sendable {
        case idle
        case recording
    }

    private let suspendHotkeys: () -> Void
    private let resumeHotkeys: () -> Void
    private(set) var state = State.idle

    init(
        suspendHotkeys: @escaping () -> Void,
        resumeHotkeys: @escaping () -> Void
    ) {
        self.suspendHotkeys = suspendHotkeys
        self.resumeHotkeys = resumeHotkeys
    }

    func begin() {
        guard state == .idle else { return }
        state = .recording
        suspendHotkeys()
    }

    func finish() {
        guard state == .recording else { return }
        state = .idle
        resumeHotkeys()
    }
}
