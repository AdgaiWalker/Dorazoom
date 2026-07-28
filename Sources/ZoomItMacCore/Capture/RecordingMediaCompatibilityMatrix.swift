import Foundation

enum RecordingMediaCompatibilityEnvironment: Equatable, Sendable {
    case quickTimePlayer
    case windowsNativePlayback
    case capCut
    case davinciResolve
}

enum RecordingMediaCompatibilityVersionPolicy: Equatable, Sendable {
    case recordInstalledVersionAtAcceptance
}

struct RecordingMediaCompatibilityTarget: Equatable, Sendable {
    var environment: RecordingMediaCompatibilityEnvironment
    var versionPolicy: RecordingMediaCompatibilityVersionPolicy
}

enum RecordingMediaCompatibilitySamplePurpose: Equatable, Sendable {
    case defaultDailyRecording
    case recordingWithAudioWebcamAndAnnotations
    case retainedExportOption
}

struct RecordingMediaCompatibilitySample: Equatable, Sendable {
    var format: RecordingFileFormat
    var required: Bool
    var purpose: RecordingMediaCompatibilitySamplePurpose
}

enum RecordingMediaCompatibilityCheck: Equatable, Sendable {
    case opensOrImports
    case playsVideo
    case audioIsPresentWhenExpected
    case audioVideoSync
    case durationMatchesExpected
    case failureReasonRecorded
}

enum RecordingMediaCompatibilityStatus: Equatable, Hashable, Sendable {
    case localSimulationPassed
    case passed
    case failed
}

struct RecordingMediaCompatibilityResult: Equatable, Sendable {
    var target: RecordingMediaCompatibilityTarget
    var sample: RecordingMediaCompatibilitySample
    var status: RecordingMediaCompatibilityStatus
    var notes: String
}

struct RecordingMediaCompatibilityMatrix: Equatable, Sendable {
    var targets: [RecordingMediaCompatibilityTarget]
    var samples: [RecordingMediaCompatibilitySample]
    var requiredChecks: [RecordingMediaCompatibilityCheck]
    var results: [RecordingMediaCompatibilityResult]
    var platformBoundary: AutomationPlatformBoundary

    static var phase7Default: RecordingMediaCompatibilityMatrix {
        let targets = [
            RecordingMediaCompatibilityTarget(environment: .quickTimePlayer, versionPolicy: .recordInstalledVersionAtAcceptance),
            RecordingMediaCompatibilityTarget(environment: .windowsNativePlayback, versionPolicy: .recordInstalledVersionAtAcceptance),
            RecordingMediaCompatibilityTarget(environment: .capCut, versionPolicy: .recordInstalledVersionAtAcceptance),
            RecordingMediaCompatibilityTarget(environment: .davinciResolve, versionPolicy: .recordInstalledVersionAtAcceptance)
        ]
        let samples = [
            RecordingMediaCompatibilitySample(format: .mov, required: true, purpose: .defaultDailyRecording),
            RecordingMediaCompatibilitySample(format: .mov, required: true, purpose: .recordingWithAudioWebcamAndAnnotations),
            RecordingMediaCompatibilitySample(format: .mp4, required: true, purpose: .retainedExportOption),
            RecordingMediaCompatibilitySample(format: .gif, required: true, purpose: .retainedExportOption)
        ]
        let checks: [RecordingMediaCompatibilityCheck] = [
            .opensOrImports,
            .playsVideo,
            .audioIsPresentWhenExpected,
            .audioVideoSync,
            .durationMatchesExpected,
            .failureReasonRecorded
        ]
        let results = targets.flatMap { target in
            samples.map { sample in
                RecordingMediaCompatibilityResult(
                    target: target,
                    sample: sample,
                    status: .localSimulationPassed,
                    notes: "Local simulation acceptance only; no external player was launched."
                )
            }
        }

        return RecordingMediaCompatibilityMatrix(
            targets: targets,
            samples: samples,
            requiredChecks: checks,
            results: results,
            platformBoundary: .simulatedOnly
        )
    }
}
