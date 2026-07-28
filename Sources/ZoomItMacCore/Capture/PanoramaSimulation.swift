import Foundation

struct PanoramaSimulationFrame: Equatable, Sendable {
    var id: String
    var topRow: Int
    var width: Int
    var height: Int
}

enum PanoramaSimulationOutput: Equatable, Sendable {
    case clipboard
    case file(path: String)
}

enum PanoramaSimulationEvent: Equatable, Sendable {
    case appendFrame(String)
    case finish
    case cancel
}

enum PanoramaSimulationClock: Equatable, Sendable {
    case fixed(filename: String)
}

enum PanoramaSimulationProgress: Equatable, Sendable {
    case capturing(frameCount: Int)
    case stitching(percent: Int)
    case cancelled
}

enum PanoramaSimulationOutputAction: Equatable, Sendable {
    case copyToPasteboard(imageID: String, changeCount: Int)
    case writeFile(path: String, imageID: String)
}

enum PanoramaSimulationOutcome: Equatable, Sendable {
    case completed(message: String)
    case cancelled(message: String)
    case failed(message: String)
}

enum PanoramaSimulationIgnoredCallback: Equatable, Sendable {
    case appendFrameAfterCancellation(String)
    case finishAfterCancellation
}

struct PanoramaSimulationResult: Equatable, Sendable {
    var progress: [PanoramaSimulationProgress]
    var outputActions: [PanoramaSimulationOutputAction]
    var outcome: PanoramaSimulationOutcome
    var ignoredCallbacks: [PanoramaSimulationIgnoredCallback]
    var virtualWindowsReleased: Bool
    var platformBoundary: AutomationPlatformBoundary
    var touchesRealScreenCapture: Bool
    var touchesRealPasteboard: Bool
    var touchesRealFilesystem: Bool
}

enum PanoramaSimulation {
    static func run(
        frames: [PanoramaSimulationFrame],
        output: PanoramaSimulationOutput,
        events: [PanoramaSimulationEvent],
        clock: PanoramaSimulationClock
    ) -> PanoramaSimulationResult {
        let frameByID = Dictionary(uniqueKeysWithValues: frames.map { ($0.id, $0) })
        var capturedFrames: [PanoramaSimulationFrame] = []
        var progress: [PanoramaSimulationProgress] = []
        var outputActions: [PanoramaSimulationOutputAction] = []
        var ignoredCallbacks: [PanoramaSimulationIgnoredCallback] = []
        var outcome: PanoramaSimulationOutcome = .failed(message: "Panorama did not finish")
        var cancelled = false

        for event in events {
            if cancelled {
                switch event {
                case .appendFrame(let id):
                    ignoredCallbacks.append(.appendFrameAfterCancellation(id))
                case .finish:
                    ignoredCallbacks.append(.finishAfterCancellation)
                case .cancel:
                    break
                }
                continue
            }

            switch event {
            case .appendFrame(let id):
                guard let frame = frameByID[id] else { continue }
                if capturedFrames.last?.id != frame.id {
                    capturedFrames.append(frame)
                    progress.append(.capturing(frameCount: capturedFrames.count))
                }

            case .finish:
                guard !capturedFrames.isEmpty else {
                    outcome = .cancelled(message: "Panorama cancelled — nothing captured")
                    continue
                }

                appendStitchingProgress(frameCount: capturedFrames.count, progress: &progress)
                let imageID = stitchedImageID(for: capturedFrames)
                switch output {
                case .clipboard:
                    outputActions.append(.copyToPasteboard(imageID: imageID, changeCount: 1))
                    outcome = .completed(message: "Panorama copied to clipboard")
                case .file(let path):
                    outputActions.append(.writeFile(path: path, imageID: imageID))
                    outcome = .completed(message: "Panorama ready to save")
                }

            case .cancel:
                cancelled = true
                progress.append(.cancelled)
                outcome = .cancelled(message: "Panorama cancelled")
            }
        }

        _ = clock
        return PanoramaSimulationResult(
            progress: progress,
            outputActions: outputActions,
            outcome: outcome,
            ignoredCallbacks: ignoredCallbacks,
            virtualWindowsReleased: true,
            platformBoundary: .simulatedOnly,
            touchesRealScreenCapture: false,
            touchesRealPasteboard: false,
            touchesRealFilesystem: false
        )
    }

    private static func appendStitchingProgress(
        frameCount: Int,
        progress: inout [PanoramaSimulationProgress]
    ) {
        guard frameCount > 0 else { return }
        for index in 1...frameCount {
            progress.append(.stitching(percent: Int(Double(index) / Double(frameCount) * 100.0)))
        }
    }

    private static func stitchedImageID(for frames: [PanoramaSimulationFrame]) -> String {
        "panorama[\(frames.map(\.id).joined(separator: "+"))]"
    }
}
