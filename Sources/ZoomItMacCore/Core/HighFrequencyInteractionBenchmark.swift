import CoreGraphics

enum AutomationPlatformBoundary: Equatable, Sendable {
    case simulatedOnly
}

struct HighFrequencyInteractionBenchmarkReport: Equatable, Sendable {
    var eventsProcessed: Int
    var stateCommitCount: Int
    var renderOperationCount: Int
    var allocationUnits: Int
    var simulatedDurationMicroseconds: Int
    var platformBoundary: AutomationPlatformBoundary
    var touchesScreenCapture: Bool
    var touchesGlobalKeyboard: Bool
    var touchesPasteboard: Bool
    var touchesMicrophoneOrCamera: Bool
}

enum HighFrequencyInteractionBenchmarkSample {
    case phase4Default

    var events: [HighFrequencyInteractionEvent] {
        switch self {
        case .phase4Default:
            return Self.phase4DefaultEvents
        }
    }

    private static var phase4DefaultEvents: [HighFrequencyInteractionEvent] {
        var events: [HighFrequencyInteractionEvent] = []

        for index in 0..<40 {
            events.append(.pointerMove(CGPoint(x: index * 3, y: index * 2)))
        }

        let tools: [AnnotationTool] = [.pen, .line, .rectangle, .ellipse, .arrow]
        for (strokeIndex, tool) in tools.enumerated() {
            let origin = CGPoint(x: 20 + strokeIndex * 30, y: 40 + strokeIndex * 20)
            events.append(.beginStroke(origin, tool: tool))
            for step in 1...20 {
                events.append(.dragStroke(CGPoint(x: origin.x + CGFloat(step * 4), y: origin.y + CGFloat(step * 3))))
            }
            events.append(.endStroke(CGPoint(x: origin.x + 84, y: origin.y + 63)))
        }

        for index in 0..<20 {
            events.append(.zoomStep(factor: index.isMultiple(of: 2) ? 2 : 1))
        }

        let colors: [AnnotationColor] = [.red, .green, .blue, .yellow, .orange]
        for index in 0..<20 {
            events.append(.setStyle(AnnotationStyle(color: colors[index % colors.count], rootWidth: CGFloat(3 + index % 8), alpha: 1)))
        }

        return events
    }
}

enum HighFrequencyInteractionEvent: Equatable, Sendable {
    case pointerMove(CGPoint)
    case beginStroke(CGPoint, tool: AnnotationTool)
    case dragStroke(CGPoint)
    case endStroke(CGPoint)
    case zoomStep(factor: CGFloat)
    case setStyle(AnnotationStyle)

    var virtualCostMicroseconds: Int {
        switch self {
        case .pointerMove:
            return 25
        case .beginStroke, .dragStroke, .endStroke:
            return 55
        case .zoomStep:
            return 80
        case .setStyle:
            return 45
        }
    }
}

enum HighFrequencyInteractionBenchmark {
    static func run(_ sample: HighFrequencyInteractionBenchmarkSample) -> HighFrequencyInteractionBenchmarkReport {
        run(events: sample.events)
    }

    static func run(events: [HighFrequencyInteractionEvent]) -> HighFrequencyInteractionBenchmarkReport {
        var annotations: [Annotation] = []
        var inProgress: Annotation?
        var currentStyle = AnnotationStyle.default
        var stateCommitCount = 0
        var renderOperationCount = 0
        var simulatedDurationMicroseconds = 0

        for event in events {
            stateCommitCount += 1
            simulatedDurationMicroseconds += event.virtualCostMicroseconds

            switch event {
            case .pointerMove:
                break
            case .beginStroke(let point, let tool):
                inProgress = Annotation(tool: tool, points: [point], style: currentStyle)
            case .dragStroke(let point):
                guard inProgress != nil else { break }
                inProgress?.points.append(point)
            case .endStroke(let point):
                guard var stroke = inProgress else { break }
                stroke.points.append(point)
                annotations.append(stroke)
                inProgress = nil
            case .zoomStep:
                break
            case .setStyle(let style):
                currentStyle = style
            }

            let renderOperations = AnnotationRenderPlan.operations(for: annotations + Array(inProgress.map { [$0] } ?? []))
            renderOperationCount += renderOperations.count
            simulatedDurationMicroseconds += renderOperations.count * 8
        }

        return HighFrequencyInteractionBenchmarkReport(
            eventsProcessed: events.count,
            stateCommitCount: stateCommitCount,
            renderOperationCount: renderOperationCount,
            allocationUnits: events.count + renderOperationCount,
            simulatedDurationMicroseconds: simulatedDurationMicroseconds,
            platformBoundary: .simulatedOnly,
            touchesScreenCapture: false,
            touchesGlobalKeyboard: false,
            touchesPasteboard: false,
            touchesMicrophoneOrCamera: false
        )
    }
}
