import Foundation

enum RecordingPauseState: Equatable, Sendable {
    case recording
    case paused
}

enum RecordingPauseTransition: Equatable, Sendable {
    case paused
    case resumed
    case unchanged
}

struct RecordingPauseTimeline: Equatable, Sendable {
    private(set) var state: RecordingPauseState = .recording
    private(set) var totalPausedDuration: TimeInterval = 0
    private var sourceStartTime: TimeInterval?
    private var pauseStartTime: TimeInterval?
    private var lastSourceTime: TimeInterval?

    mutating func pause(atSourceTime time: TimeInterval) -> RecordingPauseTransition {
        guard state == .recording else { return .unchanged }
        state = .paused
        pauseStartTime = time
        lastSourceTime = max(lastSourceTime ?? time, time)
        return .paused
    }

    mutating func resume(atSourceTime time: TimeInterval) -> RecordingPauseTransition {
        guard state == .paused, let pauseStartTime else { return .unchanged }
        totalPausedDuration += max(0, time - pauseStartTime)
        self.pauseStartTime = nil
        state = .recording
        lastSourceTime = max(lastSourceTime ?? time, time)
        return .resumed
    }

    mutating func presentationTime(
        forSourceTime time: TimeInterval
    ) throws -> TimeInterval? {
        // Audio and video callbacks share the host clock but can arrive a few
        // milliseconds out of order. Keep the furthest observed source time
        // for pause commands without rejecting a valid lagging media sample.
        lastSourceTime = max(lastSourceTime ?? time, time)
        if sourceStartTime == nil {
            sourceStartTime = time
        }
        guard state == .recording, let sourceStartTime else { return nil }
        return max(0, time - sourceStartTime - totalPausedDuration)
    }
}

enum RecordingRuntimeState: Equatable, Sendable {
    case preparing
    case recording
    case paused
    case finalizing
}

enum RecordingPauseCommandEffect: Equatable, Sendable {
    case pause
    case resume
    case reject
}

enum RecordingPauseCommandPolicy {
    static func effect(state: RecordingRuntimeState) -> RecordingPauseCommandEffect {
        switch state {
        case .recording: .pause
        case .paused: .resume
        case .preparing, .finalizing: .reject
        }
    }
}
