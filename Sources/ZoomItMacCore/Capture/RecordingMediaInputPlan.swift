import Foundation

enum RecordingMediaSource: Equatable, Sendable {
    case video
    case systemAudio
    case microphone
    case webcam
}

enum RecordingMediaPermissionRequest: Equatable, Sendable {
    case microphone
    case camera
}

struct RecordingMediaInputPermissions: Equatable, Sendable {
    var microphone: MicrophonePermission
    var camera: MicrophonePermission
}

struct RecordingMediaSample: Equatable, Sendable {
    var source: RecordingMediaSource
    var sourceTimestampSeconds: Double
    var durationSeconds: Double
}

struct RecordingMediaTimelineEntry: Equatable, Sendable {
    var source: RecordingMediaSource
    var presentationSeconds: Double
    var durationSeconds: Double
}

struct RecordingMediaInputPlan: Equatable, Sendable {
    var includesSystemAudio: Bool
    var includesMicrophone: Bool
    var includesWebcam: Bool
    var permissionRequests: [RecordingMediaPermissionRequest]
    var timeline: [RecordingMediaTimelineEntry]
    var platformBoundary: AutomationPlatformBoundary
}

enum RecordingMediaInputPlanner {
    static func plan(
        settings: AppSettings,
        permissions: RecordingMediaInputPermissions,
        samples: [RecordingMediaSample]
    ) -> RecordingMediaInputPlan {
        var permissionRequests: [RecordingMediaPermissionRequest] = []

        let includesSystemAudio = settings.recordSystemAudio

        let includesMicrophone: Bool
        if settings.recordMicrophone {
            switch permissions.microphone {
            case .granted:
                includesMicrophone = true
            case .notDetermined:
                permissionRequests.append(.microphone)
                includesMicrophone = false
            case .denied:
                includesMicrophone = false
            }
        } else {
            includesMicrophone = false
        }

        let includesWebcam: Bool
        if settings.webcamEnabled {
            switch permissions.camera {
            case .granted:
                includesWebcam = true
            case .notDetermined:
                permissionRequests.append(.camera)
                includesWebcam = false
            case .denied:
                includesWebcam = false
            }
        } else {
            includesWebcam = false
        }

        let enabledSources = Set(
            [
                RecordingMediaSource.video,
                includesSystemAudio ? .systemAudio : nil,
                includesMicrophone ? .microphone : nil,
                includesWebcam ? .webcam : nil
            ].compactMap { $0 }
        )
        let enabledSamples = samples.filter { enabledSources.contains($0.source) }
        let origin = enabledSamples.map(\.sourceTimestampSeconds).min() ?? 0
        let timeline = enabledSamples.map { sample in
            RecordingMediaTimelineEntry(
                source: sample.source,
                presentationSeconds: rounded(sample.sourceTimestampSeconds - origin),
                durationSeconds: rounded(sample.durationSeconds)
            )
        }

        return RecordingMediaInputPlan(
            includesSystemAudio: includesSystemAudio,
            includesMicrophone: includesMicrophone,
            includesWebcam: includesWebcam,
            permissionRequests: permissionRequests,
            timeline: timeline,
            platformBoundary: .simulatedOnly
        )
    }

    private static func rounded(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}

enum RecordingWebcamPictureInPicturePlanner {
    static func initialFrame(
        area: CGRect,
        position: WebcamOverlayController.Position,
        size: WebcamOverlayController.Size,
        shape: WebcamOverlayController.Shape,
        cameraAspectRatio: CGFloat
    ) -> CGRect {
        guard let widthFraction = size.widthFraction else {
            return area.integral
        }
        let margin: CGFloat = 8
        var width = area.width * widthFraction
        var height = shape.isSquare ? width : width / max(cameraAspectRatio, 0.01)
        let maxWidth = max(1, area.width - 2 * margin)
        let maxHeight = max(1, area.height - 2 * margin)
        if width > maxWidth || height > maxHeight {
            let scale = min(maxWidth / width, maxHeight / height, 1)
            width *= scale
            height *= scale
        }

        let origin: CGPoint
        switch position {
        case .topLeft:
            origin = CGPoint(x: area.minX + margin, y: area.maxY - margin - height)
        case .topRight:
            origin = CGPoint(x: area.maxX - margin - width, y: area.maxY - margin - height)
        case .bottomLeft:
            origin = CGPoint(x: area.minX + margin, y: area.minY + margin)
        case .bottomRight:
            origin = CGPoint(x: area.maxX - margin - width, y: area.minY + margin)
        case .center:
            origin = CGPoint(x: area.midX - width / 2, y: area.midY - height / 2)
        }
        return CGRect(origin: origin, size: CGSize(width: width, height: height)).integral
    }

    static func draggedFrame(
        mouseOnScreen: CGPoint,
        grabOffset: CGSize,
        currentSize: CGSize,
        area: CGRect
    ) -> CGRect {
        let proposed = CGRect(
            x: mouseOnScreen.x - grabOffset.width,
            y: mouseOnScreen.y - grabOffset.height,
            width: currentSize.width,
            height: currentSize.height
        )
        return snapToNearestCorner(proposed, inside: area, margin: 8).integral
    }

    private static func snapToNearestCorner(_ frame: CGRect, inside area: CGRect, margin: CGFloat) -> CGRect {
        let candidates = [
            CGPoint(x: area.minX + margin, y: area.minY + margin),
            CGPoint(x: area.maxX - margin - frame.width, y: area.minY + margin),
            CGPoint(x: area.minX + margin, y: area.maxY - margin - frame.height),
            CGPoint(x: area.maxX - margin - frame.width, y: area.maxY - margin - frame.height)
        ]
        let proposedOrigin = frame.origin
        let nearest = candidates.min { lhs, rhs in
            distanceSquared(lhs, proposedOrigin) < distanceSquared(rhs, proposedOrigin)
        } ?? proposedOrigin
        return CGRect(origin: nearest, size: frame.size)
    }

    private static func distanceSquared(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return dx * dx + dy * dy
    }
}
