import XCTest
@testable import InkLayer

final class ActivationLifecycleTests: XCTestCase {
    func testCancellingLoadingRejectsItsLateCompletion() throws {
        var lifecycle = ActivationLifecycle()
        let token = try XCTUnwrap(lifecycle.beginLoading())

        XCTAssertEqual(lifecycle.state, .loading(token))
        XCTAssertTrue(lifecycle.requiresDeactivation)
        XCTAssertTrue(lifecycle.deactivate())
        XCTAssertEqual(lifecycle.state, .idle)
        XCTAssertFalse(lifecycle.requiresDeactivation)

        XCTAssertFalse(lifecycle.activate(token))
        XCTAssertFalse(lifecycle.isActive)
    }

    func testOnlyCurrentLoadingTokenCanCompleteOrFail() throws {
        var lifecycle = ActivationLifecycle()
        let token = try XCTUnwrap(lifecycle.beginLoading())

        XCTAssertNil(lifecycle.beginLoading())
        XCTAssertFalse(lifecycle.activate(UUID()))
        XCTAssertEqual(lifecycle.state, .loading(token))

        XCTAssertTrue(lifecycle.activate(token))
        XCTAssertTrue(lifecycle.isActive)
        XCTAssertTrue(lifecycle.requiresDeactivation)
        XCTAssertTrue(lifecycle.deactivate())

        let nextToken = try XCTUnwrap(lifecycle.beginLoading())
        XCTAssertFalse(lifecycle.fail(UUID()))
        XCTAssertEqual(lifecycle.state, .loading(nextToken))
        XCTAssertTrue(lifecycle.fail(nextToken))
        XCTAssertEqual(lifecycle.state, .idle)
        XCTAssertFalse(lifecycle.requiresDeactivation)
    }
}
