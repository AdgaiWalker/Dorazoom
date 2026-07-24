import XCTest
@testable import InkLayer

final class RecordingLifecycleTests: XCTestCase {
    func testRecordingFollowsSingleLegalLifecycle() {
        var lifecycle = RecordingLifecycle()

        XCTAssertEqual(lifecycle.state, .idle)
        XCTAssertTrue(lifecycle.requestStart())
        XCTAssertEqual(lifecycle.state, .starting)
        XCTAssertFalse(lifecycle.requestStart())

        XCTAssertTrue(lifecycle.didStart())
        XCTAssertEqual(lifecycle.state, .recording)
        XCTAssertTrue(lifecycle.requestStop())
        XCTAssertEqual(lifecycle.state, .stopping)
        XCTAssertFalse(lifecycle.requestStop())

        lifecycle.didFinish()
        XCTAssertEqual(lifecycle.state, .idle)
    }

    func testInvalidCompletionCannotSkipLifecycleStages() {
        var lifecycle = RecordingLifecycle()

        XCTAssertFalse(lifecycle.didStart())
        XCTAssertEqual(lifecycle.state, .idle)
        XCTAssertFalse(lifecycle.requestStop())
        XCTAssertEqual(lifecycle.state, .idle)

        XCTAssertTrue(lifecycle.requestStart())
        lifecycle.didFinish()
        XCTAssertEqual(lifecycle.state, .idle)
    }
}
