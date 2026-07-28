import Foundation

enum FeedbackChannel: Equatable, Hashable, Sendable {
    case cursor
    case hud
    case recordingStatus
    case menuBar
    case palette
}

enum FeedbackContent: Equatable, Sendable {
    case cursor(PointerFeedback)
    case hud(String)
    case recordingStatus(RecordingStatusFeedback)
    case menuBar(MenuBarFeedback)
    case palette(PaletteFeedback)
}

final class FeedbackLease {
    private var onEnd: (() -> Void)?

    init(onEnd: @escaping () -> Void) {
        self.onEnd = onEnd
    }

    func end() {
        guard let onEnd else { return }
        self.onEnd = nil
        onEnd()
    }
}

final class InteractionFeedback {
    private struct Entry {
        var id: Int
        var content: FeedbackContent
    }

    private var nextID = 0
    private var entries: [FeedbackChannel: Entry] = [:]

    func begin(channel: FeedbackChannel, content: FeedbackContent) -> FeedbackLease {
        nextID += 1
        let id = nextID
        entries[channel] = Entry(id: id, content: content)

        return FeedbackLease { [weak self] in
            self?.end(channel: channel, id: id)
        }
    }

    func content(for channel: FeedbackChannel) -> FeedbackContent? {
        entries[channel]?.content
    }

    private func end(channel: FeedbackChannel, id: Int) {
        guard entries[channel]?.id == id else { return }
        entries[channel] = nil
    }
}
