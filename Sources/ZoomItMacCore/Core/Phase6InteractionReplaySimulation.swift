import Foundation

enum BreakTimerSimulationEvent: Equatable, Sendable {
    case start
    case advance(seconds: Int)
    case exit
}

enum BreakTimerSimulationSoundEvent: Equatable, Sendable {
    case beepAtZero
    case playSoundFileAtZero(String)
}

enum BreakTimerSimulationLifecycleEvent: Equatable, Sendable {
    case started
    case idleSleepAssertionBegan
    case expired
    case closedByUser
    case idleSleepAssertionEnded
}

enum TransientFeedbackRecordingVisibility: Equatable, Sendable {
    case excludedFromRecording
}

struct BreakTimerSimulationSnapshot: Equatable, Sendable {
    var remainingSeconds: Int
    var visibleText: String
    var expiredText: String?
}

struct BreakTimerSimulationResult: Equatable, Sendable {
    var snapshots: [BreakTimerSimulationSnapshot]
    var soundEvents: [BreakTimerSimulationSoundEvent]
    var lifecycleEvents: [BreakTimerSimulationLifecycleEvent]
    var recordingVisibility: TransientFeedbackRecordingVisibility
    var platformBoundary: AutomationPlatformBoundary
    var touchesRealTimer: Bool
    var touchesRealSound: Bool
    var touchesRealWindow: Bool
}

enum BreakTimerSimulation {
    static func run(settings: AppSettings, events: [BreakTimerSimulationEvent]) -> BreakTimerSimulationResult {
        let initialSeconds = max(1, min(settings.breakDurationMinutes, 99)) * 60
        var remainingSeconds = initialSeconds
        var hasStarted = false
        var hasExpired = false
        var hasPlayedSound = false
        var snapshots: [BreakTimerSimulationSnapshot] = []
        var soundEvents: [BreakTimerSimulationSoundEvent] = []
        var lifecycleEvents: [BreakTimerSimulationLifecycleEvent] = []

        func appendSnapshot() {
            snapshots.append(.init(
                remainingSeconds: remainingSeconds,
                visibleText: BreakTimerLayout.timerText(for: remainingSeconds)
                    .trimmingCharacters(in: .whitespaces),
                expiredText: settings.breakShowExpiredTime && remainingSeconds < 0
                    ? BreakTimerLayout.expiredText(for: remainingSeconds)
                    : nil
            ))
        }

        for event in events {
            switch event {
            case .start:
                hasStarted = true
                remainingSeconds = initialSeconds
                lifecycleEvents.append(.started)
                lifecycleEvents.append(.idleSleepAssertionBegan)
                appendSnapshot()

            case .advance(let seconds):
                guard hasStarted else { continue }
                let previous = remainingSeconds
                remainingSeconds -= max(0, seconds)
                if previous > 0, remainingSeconds <= 0, !hasExpired {
                    hasExpired = true
                    lifecycleEvents.append(.expired)
                    if settings.breakPlaySound, !hasPlayedSound {
                        hasPlayedSound = true
                        if settings.breakSoundFile.isEmpty {
                            soundEvents.append(.beepAtZero)
                        } else {
                            soundEvents.append(.playSoundFileAtZero(settings.breakSoundFile))
                        }
                    }
                }
                appendSnapshot()

            case .exit:
                guard hasStarted else { continue }
                lifecycleEvents.append(.closedByUser)
                lifecycleEvents.append(.idleSleepAssertionEnded)
                hasStarted = false
            }
        }

        return BreakTimerSimulationResult(
            snapshots: snapshots,
            soundEvents: soundEvents,
            lifecycleEvents: lifecycleEvents,
            recordingVisibility: .excludedFromRecording,
            platformBoundary: .simulatedOnly,
            touchesRealTimer: false,
            touchesRealSound: false,
            touchesRealWindow: false
        )
    }
}

enum DemoTypeReplayMode: Equatable, Sendable {
    case automatic
    case userDriven
}

enum DemoTypeReplayCommand: Equatable, Sendable {
    case start
    case previousSegment
    case exit
}

enum DemoTypeReplayKey: Equatable, Sendable {
    case enter
    case up
    case down
    case left
    case right
}

enum DemoTypeReplayOutput: Equatable, Sendable {
    case typeText(String)
    case pressKey(DemoTypeReplayKey)
    case copyTextToPasteboard(String)
    case postCommandV
}

enum DemoTypeReplayStatus: Equatable, Sendable {
    case running
    case segmentEnded
    case rewound
    case stopped
}

enum DemoTypeReplayFeedback: Equatable, Sendable {
    case hud(segmentIndex: Int, status: DemoTypeReplayStatus)
}

struct DemoTypeReplayResult: Equatable, Sendable {
    var outputs: [DemoTypeReplayOutput]
    var feedback: [DemoTypeReplayFeedback]
    var cursorOffset: Int
    var platformBoundary: AutomationPlatformBoundary
    var touchesRealKeyboard: Bool
    var touchesRealPasteboard: Bool
    var touchesTargetApp: Bool
}

struct DemoTypeReplaySimulation: Equatable, Sendable {
    private var script: String
    private var mode: DemoTypeReplayMode
    private var cursorOffset: Int
    private var segmentStarts: [Int]

    init(script: String, mode: DemoTypeReplayMode) {
        self.script = script
        self.mode = mode
        self.cursorOffset = 0
        self.segmentStarts = Self.segmentStarts(in: script)
    }

    mutating func apply(_ command: DemoTypeReplayCommand) -> DemoTypeReplayResult {
        switch command {
        case .start:
            return runCurrentSegment()
        case .previousSegment:
            cursorOffset = previousSegmentStart(before: cursorOffset)
            return makeResult(
                outputs: [],
                feedback: [.hud(segmentIndex: segmentIndex(for: cursorOffset), status: .rewound)]
            )
        case .exit:
            return makeResult(
                outputs: [],
                feedback: [.hud(segmentIndex: segmentIndex(for: cursorOffset), status: .stopped)]
            )
        }
    }

    private mutating func runCurrentSegment() -> DemoTypeReplayResult {
        if cursorOffset >= script.count {
            cursorOffset = 0
        }

        let startingSegment = segmentIndex(for: cursorOffset)
        var outputs: [DemoTypeReplayOutput] = []
        var feedback: [DemoTypeReplayFeedback] = [.hud(segmentIndex: startingSegment, status: .running)]
        var cursor = script.index(script.startIndex, offsetBy: cursorOffset)

        while cursor < script.endIndex {
            if let token = nextToken(startingAt: cursor) {
                cursor = token.nextIndex
                switch token.value {
                case .text(let string):
                    outputs.append(.typeText(string))
                case .key(let key):
                    outputs.append(.pressKey(key))
                case .paste(let string):
                    outputs.append(.copyTextToPasteboard(string))
                    outputs.append(.postCommandV)
                case .pause:
                    break
                case .end:
                    cursorOffset = script.distance(from: script.startIndex, to: cursor)
                    feedback.append(.hud(segmentIndex: startingSegment, status: .segmentEnded))
                    return makeResult(outputs: outputs, feedback: feedback)
                }

                if mode == .userDriven {
                    cursorOffset = script.distance(from: script.startIndex, to: cursor)
                    return makeResult(outputs: outputs, feedback: feedback)
                }
            } else {
                cursor = script.index(after: cursor)
            }
        }

        cursorOffset = 0
        feedback.append(.hud(segmentIndex: startingSegment, status: .segmentEnded))
        return makeResult(outputs: outputs, feedback: feedback)
    }

    private enum Token: Equatable {
        case text(String)
        case key(DemoTypeReplayKey)
        case pause(Int)
        case paste(String)
        case end
    }

    private func nextToken(startingAt cursor: String.Index) -> (value: Token, nextIndex: String.Index)? {
        guard cursor < script.endIndex else { return nil }
        guard script[cursor] == "[" else {
            let next = script.index(after: cursor)
            return (.text(String(script[cursor])), next)
        }

        guard let close = script[cursor...].firstIndex(of: "]") else {
            let next = script.index(after: cursor)
            return (.text(String(script[cursor])), next)
        }
        let afterClose = script.index(after: close)
        let control = String(script[cursor..<afterClose]).lowercased()
        switch control {
        case "[end]":
            return (.end, afterClose)
        case "[enter]":
            return (.key(.enter), afterClose)
        case "[up]":
            return (.key(.up), afterClose)
        case "[down]":
            return (.key(.down), afterClose)
        case "[left]":
            return (.key(.left), afterClose)
        case "[right]":
            return (.key(.right), afterClose)
        case "[paste]":
            guard let endRange = script.range(of: "[/paste]", range: afterClose..<script.endIndex) else {
                return (.text(String(script[cursor])), script.index(after: cursor))
            }
            return (.paste(String(script[afterClose..<endRange.lowerBound])), endRange.upperBound)
        default:
            if control.hasPrefix("[pause:"), control.hasSuffix("]") {
                let value = control.dropFirst(7).dropLast()
                if let seconds = Int(value) {
                    return (.pause(seconds), afterClose)
                }
            }
            return (.text(String(script[cursor])), script.index(after: cursor))
        }
    }

    private func previousSegmentStart(before offset: Int) -> Int {
        let bounded = min(max(offset, 0), script.count)
        let currentIndex = segmentIndex(for: bounded)
        guard currentIndex > 0 else { return 0 }
        return segmentStarts[currentIndex - 1]
    }

    private func segmentIndex(for offset: Int) -> Int {
        let bounded = min(max(offset, 0), script.count)
        if bounded == script.count, segmentStarts.count > 1 {
            return segmentStarts.count - 2
        }
        var index = 0
        for (candidateIndex, start) in segmentStarts.enumerated() where start <= bounded {
            index = candidateIndex
        }
        return index
    }

    private static func segmentStarts(in script: String) -> [Int] {
        var starts = [0]
        var searchStart = script.startIndex
        while let range = script.range(of: "[end]", range: searchStart..<script.endIndex) {
            starts.append(script.distance(from: script.startIndex, to: range.upperBound))
            searchStart = range.upperBound
        }
        return starts
    }

    private func makeResult(
        outputs: [DemoTypeReplayOutput],
        feedback: [DemoTypeReplayFeedback]
    ) -> DemoTypeReplayResult {
        DemoTypeReplayResult(
            outputs: outputs,
            feedback: feedback,
            cursorOffset: cursorOffset,
            platformBoundary: .simulatedOnly,
            touchesRealKeyboard: false,
            touchesRealPasteboard: false,
            touchesTargetApp: false
        )
    }
}
