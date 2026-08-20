import XCTest
@testable import ZoomItMacCore

final class AppleWindowSnipTests: XCTestCase {
    func testPointerSelectsFrontmostEligibleWindowAndExcludesDoraZoom() throws {
        var session = WindowSnipSession()
        let plan = try XCTUnwrap(session.begin(
            pointer: CGPoint(x: 120, y: 140),
            candidatesFrontToBack: [
                candidate(id: 1, ownerPID: 99, frame: CGRect(x: 80, y: 80, width: 300, height: 240)),
                candidate(id: 2, ownerPID: 42, frame: CGRect(x: 100, y: 100, width: 400, height: 300)),
                candidate(id: 3, ownerPID: 77, frame: CGRect(x: 100, y: 100, width: 500, height: 400))
            ],
            ownProcessID: 99,
            includeShadow: true
        ))

        XCTAssertEqual(plan.windowID, 2)
        XCTAssertTrue(plan.includeShadow)
        XCTAssertEqual(plan.outputOperations, [.pasteboardImage])
        XCTAssertEqual(session.state, .targeted(windowID: 2))
    }

    func testShadowPreferenceFlowsIntoCapturePlan() throws {
        var session = WindowSnipSession()
        let plan = try XCTUnwrap(session.begin(
            pointer: CGPoint(x: 120, y: 140),
            candidatesFrontToBack: [candidate(id: 2, ownerPID: 42)],
            ownProcessID: 99,
            includeShadow: false
        ))

        XCTAssertFalse(plan.includeShadow)
        XCTAssertTrue(AppSettings.defaults.includeWindowShadow)
    }

    func testNoWindowCancelAndDisappearanceAlwaysReleaseSessionState() throws {
        var session = WindowSnipSession()
        XCTAssertNil(session.begin(
            pointer: CGPoint(x: 900, y: 900),
            candidatesFrontToBack: [candidate(id: 2, ownerPID: 42)],
            ownProcessID: 99,
            includeShadow: true
        ))
        XCTAssertEqual(session.state, .idle)

        _ = try XCTUnwrap(session.begin(
            pointer: CGPoint(x: 120, y: 140),
            candidatesFrontToBack: [candidate(id: 2, ownerPID: 42)],
            ownProcessID: 99,
            includeShadow: true
        ))
        session.cancel()
        XCTAssertEqual(session.state, .idle)

        _ = try XCTUnwrap(session.begin(
            pointer: CGPoint(x: 120, y: 140),
            candidatesFrontToBack: [candidate(id: 2, ownerPID: 42)],
            ownProcessID: 99,
            includeShadow: true
        ))
        session.captureFinished(.windowDisappeared)
        XCTAssertEqual(session.state, .idle)
        XCTAssertTrue(WindowCaptureError.windowDisappeared(2).localizedDescription.contains("2"))
    }

    @MainActor
    func testStatusMenuExposesWindowScreenshotWithoutGlobalDefaultHotkey() {
        let plan = StatusMenuPlan.make(
            status: .idle,
            permissions: .init(rows: [], platformBoundary: .simulatedOnly),
            settings: .defaults
        )

        XCTAssertEqual(
            AppDelegate.actionSelector(for: .snipWindow),
            #selector(AppController.snipWindowAtPointer)
        )
        XCTAssertNil(plan.item(.snipWindow)?.shortcut)
    }

    @MainActor
    func testWindowTargetSelectorIsCaptureExcludedAndCancellationReleasesIt() {
        var cancelled = false
        let controller = WindowTargetSelectionController(
            candidatesFrontToBack: [candidate(id: 2, ownerPID: 42)],
            ownProcessID: 99,
            includeShadow: true,
            displayFrames: [CGRect(x: 0, y: 0, width: 1512, height: 982)],
            pointerProvider: { CGPoint(x: 120, y: 140) },
            onSelected: { _ in XCTFail("test cancellation must not select a window") },
            onCancelled: { cancelled = true }
        )

        XCTAssertEqual(controller.window?.sharingType, NSWindow.SharingType.none)
        XCTAssertEqual(controller.window?.level, .screenSaver)
        XCTAssertFalse(controller.window?.isVisible == true)

        controller.cancel()
        XCTAssertTrue(cancelled)
        XCTAssertNil(controller.window)
    }

    private func candidate(
        id: UInt32,
        ownerPID: Int32,
        frame: CGRect = CGRect(x: 100, y: 100, width: 400, height: 300)
    ) -> WindowSnipCandidate {
        WindowSnipCandidate(
            windowID: id,
            ownerProcessID: ownerPID,
            frame: frame,
            layer: 0,
            isOnScreen: true,
            scaleFactor: 2
        )
    }
}
