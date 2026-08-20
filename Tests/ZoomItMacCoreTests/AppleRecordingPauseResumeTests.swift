import XCTest
@testable import ZoomItMacCore

final class AppleRecordingPauseResumeTests: XCTestCase {
    func testMultiplePauseIntervalsAreRemovedFromOutputTimeline() throws {
        var timeline = RecordingPauseTimeline()

        XCTAssertEqual(try timeline.presentationTime(forSourceTime: 0), 0)
        XCTAssertEqual(try timeline.presentationTime(forSourceTime: 5), 5)
        XCTAssertEqual(timeline.pause(atSourceTime: 5), .paused)
        XCTAssertNil(try timeline.presentationTime(forSourceTime: 10))
        XCTAssertEqual(timeline.resume(atSourceTime: 15), .resumed)
        XCTAssertEqual(try timeline.presentationTime(forSourceTime: 15), 5)
        XCTAssertEqual(try timeline.presentationTime(forSourceTime: 25), 15)

        XCTAssertEqual(timeline.pause(atSourceTime: 30), .paused)
        XCTAssertEqual(timeline.resume(atSourceTime: 40), .resumed)
        XCTAssertEqual(try timeline.presentationTime(forSourceTime: 50), 30)
        XCTAssertEqual(timeline.totalPausedDuration, 20)
    }

    func testRepeatedPauseAndResumeCommandsAreIdempotent() {
        var timeline = RecordingPauseTimeline()

        XCTAssertEqual(timeline.pause(atSourceTime: 3), .paused)
        XCTAssertEqual(timeline.pause(atSourceTime: 8), .unchanged)
        XCTAssertEqual(timeline.resume(atSourceTime: 13), .resumed)
        XCTAssertEqual(timeline.resume(atSourceTime: 18), .unchanged)
        XCTAssertEqual(timeline.totalPausedDuration, 10)
        XCTAssertEqual(timeline.state, .recording)
    }

    func testPausedSamplesAreDroppedAndAudioVideoUseSameContinuousMapping() throws {
        var video = RecordingPauseTimeline()
        var audio = RecordingPauseTimeline()
        _ = try video.presentationTime(forSourceTime: 100)
        _ = try audio.presentationTime(forSourceTime: 100)
        _ = video.pause(atSourceTime: 110)
        _ = audio.pause(atSourceTime: 110)

        XCTAssertNil(try video.presentationTime(forSourceTime: 115))
        XCTAssertNil(try audio.presentationTime(forSourceTime: 115))

        _ = video.resume(atSourceTime: 125)
        _ = audio.resume(atSourceTime: 125)
        XCTAssertEqual(try video.presentationTime(forSourceTime: 130), 15)
        XCTAssertEqual(try audio.presentationTime(forSourceTime: 130), 15)
    }

    func testPauseCommandPolicyOnlyTogglesActiveRecording() {
        XCTAssertEqual(RecordingPauseCommandPolicy.effect(state: .recording), .pause)
        XCTAssertEqual(RecordingPauseCommandPolicy.effect(state: .paused), .resume)
        XCTAssertEqual(RecordingPauseCommandPolicy.effect(state: .preparing), .reject)
        XCTAssertEqual(RecordingPauseCommandPolicy.effect(state: .finalizing), .reject)
    }
}
