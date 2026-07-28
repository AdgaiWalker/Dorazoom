import AVFoundation
import UniformTypeIdentifiers
import XCTest
@testable import ZoomItMacCore

final class Phase5RecordingMovieProfileTests: XCTestCase {
    func testDefaultRecordingFormatIsMovWithH264AacProfile() {
        XCTAssertEqual(RecordingFileFormat.default, .mov)

        let profile = RecordingOutputStrategy.defaultMovieProfile

        XCTAssertEqual(profile.container, .mov)
        XCTAssertEqual(profile.fileExtension, "mov")
        XCTAssertEqual(profile.videoCodec, .h264)
        XCTAssertEqual(profile.audioCodec, .aac)
        XCTAssertEqual(profile.avFileType, .mov)
        XCTAssertEqual(profile.saveContentType, .quickTimeMovie)
        XCTAssertEqual(profile.audioSampleRate, 48_000)
        XCTAssertEqual(profile.audioBitRate, 128_000)
        XCTAssertEqual(profile.audioChannelCount, 2)
    }

    func testMp4MovieProfileIsStillAvailable() {
        guard case .movie(let profile) = RecordingOutputStrategy.strategy(for: .mp4) else {
            return XCTFail("Expected MP4 to stay on the movie pipeline")
        }

        XCTAssertEqual(profile.container, .mp4)
        XCTAssertEqual(profile.fileExtension, "mp4")
        XCTAssertEqual(profile.avFileType, .mp4)
        XCTAssertEqual(profile.saveContentType, .mpeg4Movie)
    }

    func testGifStaysOutOfMovieWriterProfile() {
        XCTAssertEqual(RecordingOutputStrategy.strategy(for: .gif), .animatedImage(.zoomItDefault))
    }

    func testRecordingFileNamesUseDoraZoomProductPrefix() {
        let profile = RecordingOutputStrategy.defaultMovieProfile
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let date = calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 27,
            hour: 9,
            minute: 58,
            second: 0
        ))!

        XCTAssertEqual(
            RecordingFileNaming.suggestedMovieFilename(date: date, profile: profile),
            "DoraZoom 2026-07-27 095800.mov"
        )
        XCTAssertEqual(
            RecordingFileNaming.temporaryMovieFilename(id: "sample-id", profile: profile),
            "DoraZoom-sample-id.mov"
        )
        XCTAssertEqual(
            RecordingFileNaming.temporaryEditFilename(id: "sample-id", profile: profile),
            "DoraZoom-edit-sample-id.mov"
        )
    }
}
