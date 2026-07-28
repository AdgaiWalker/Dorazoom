import UniformTypeIdentifiers
import XCTest
@testable import ZoomItMacCore

final class Phase5GifOutputWriterTests: XCTestCase {
    func testGifProfileUsesIndependentAnimatedImageSettings() {
        guard case .animatedImage(let profile) = RecordingOutputStrategy.strategy(for: .gif) else {
            return XCTFail("Expected GIF to stay on the animated-image pipeline")
        }

        XCTAssertEqual(profile.fileExtension, "gif")
        XCTAssertEqual(profile.saveContentType, .gif)
        XCTAssertEqual(profile.loopCount, 0)
        XCTAssertEqual(profile.colorDepthBits, 8)
    }

    func testGifWriterReceivesOrderedFramesAndDurationsWithoutMovieWriter() throws {
        let frames = [
            RecordingGifFramePlan(frameID: "first", durationSeconds: 0.12),
            RecordingGifFramePlan(frameID: "second", durationSeconds: 0.24),
            RecordingGifFramePlan(frameID: "third", durationSeconds: 0.18)
        ]
        let gifWriter = FakeGifRecordingWriter()
        let movieWriter = FakeMovieRecordingWriter()

        try RecordingOutputWriterRouter.write(
            format: .gif,
            gifFrames: frames,
            gifWriter: gifWriter,
            movieWriter: movieWriter
        )

        XCTAssertEqual(gifWriter.writtenPlans, [
            RecordingGifOutputPlan(profile: .zoomItDefault, frames: frames)
        ])
        XCTAssertEqual(movieWriter.writeCount, 0)
    }
}

private final class FakeGifRecordingWriter: RecordingGifWriting {
    private(set) var writtenPlans: [RecordingGifOutputPlan] = []

    func writeGif(_ plan: RecordingGifOutputPlan) throws {
        writtenPlans.append(plan)
    }
}

private final class FakeMovieRecordingWriter: RecordingMovieWriting {
    private(set) var writeCount = 0

    func writeMovie(_ profile: MovieRecordingProfile) throws {
        writeCount += 1
    }
}
