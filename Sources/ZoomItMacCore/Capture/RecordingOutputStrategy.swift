import AVFoundation
import UniformTypeIdentifiers

enum RecordingFileFormat: Equatable, Sendable {
    case mov
    case mp4
    case gif

    static let `default`: RecordingFileFormat = .mov
}

enum MovieContainer: Equatable, Sendable {
    case mov
    case mp4
}

enum MovieVideoCodec: Equatable, Sendable {
    case h264
}

enum MovieAudioCodec: Equatable, Sendable {
    case aac
}

struct MovieRecordingProfile: Equatable, Sendable {
    var container: MovieContainer
    var fileExtension: String
    var videoCodec: MovieVideoCodec
    var audioCodec: MovieAudioCodec
    var audioSampleRate: Int = 48_000
    var audioBitRate: Int = 128_000
    var audioChannelCount: Int = 2

    var avFileType: AVFileType {
        switch container {
        case .mov:
            return .mov
        case .mp4:
            return .mp4
        }
    }

    var saveContentType: UTType {
        switch container {
        case .mov:
            return .quickTimeMovie
        case .mp4:
            return .mpeg4Movie
        }
    }
}

enum RecordingFileNaming {
    static func suggestedMovieFilename(date: Date, profile: MovieRecordingProfile) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HHmmss"
        return "DoraZoom \(formatter.string(from: date)).\(profile.fileExtension)"
    }

    static func temporaryMovieFilename(id: String = UUID().uuidString, profile: MovieRecordingProfile) -> String {
        "DoraZoom-\(id).\(profile.fileExtension)"
    }

    static func temporaryEditFilename(id: String = UUID().uuidString, profile: MovieRecordingProfile) -> String {
        "DoraZoom-edit-\(id).\(profile.fileExtension)"
    }
}

struct RecordingGifProfile: Equatable, Sendable {
    var fileExtension: String
    var loopCount: Int
    var colorDepthBits: Int

    static let zoomItDefault = RecordingGifProfile(
        fileExtension: "gif",
        loopCount: 0,
        colorDepthBits: 8
    )

    var saveContentType: UTType {
        .gif
    }
}

struct RecordingGifFramePlan: Equatable, Sendable {
    var frameID: String
    var durationSeconds: Double
}

struct RecordingGifOutputPlan: Equatable, Sendable {
    var profile: RecordingGifProfile
    var frames: [RecordingGifFramePlan]
}

protocol RecordingGifWriting: AnyObject {
    func writeGif(_ plan: RecordingGifOutputPlan) throws
}

protocol RecordingMovieWriting: AnyObject {
    func writeMovie(_ profile: MovieRecordingProfile) throws
}

enum RecordingOutputWriterRouter {
    static func write(
        format: RecordingFileFormat,
        gifFrames: [RecordingGifFramePlan],
        gifWriter: RecordingGifWriting,
        movieWriter: RecordingMovieWriting
    ) throws {
        switch RecordingOutputStrategy.strategy(for: format) {
        case .movie(let profile):
            try movieWriter.writeMovie(profile)
        case .animatedImage(let profile):
            try gifWriter.writeGif(.init(profile: profile, frames: gifFrames))
        }
    }
}

enum RecordingOutputStrategy: Equatable, Sendable {
    case movie(MovieRecordingProfile)
    case animatedImage(RecordingGifProfile)

    static var defaultMovieProfile: MovieRecordingProfile {
        guard case .movie(let profile) = strategy(for: RecordingFileFormat.default) else {
            preconditionFailure("Default recording format must use the movie pipeline")
        }
        return profile
    }

    static func strategy(for format: RecordingFileFormat) -> RecordingOutputStrategy {
        switch format {
        case .mov:
            return .movie(.init(container: .mov, fileExtension: "mov", videoCodec: .h264, audioCodec: .aac))
        case .mp4:
            return .movie(.init(container: .mp4, fileExtension: "mp4", videoCodec: .h264, audioCodec: .aac))
        case .gif:
            return .animatedImage(.zoomItDefault)
        }
    }
}
