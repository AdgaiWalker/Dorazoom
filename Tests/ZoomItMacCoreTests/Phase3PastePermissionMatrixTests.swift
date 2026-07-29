import XCTest
@testable import ZoomItMacCore

@MainActor
final class Phase3PastePermissionMatrixTests: XCTestCase {
    func testUnknownAccessThenAllowedRequestsOnceArmsAndStartsEventTap() {
        let requester = MatrixPermissionRequester(initialAccess: .init(canListen: false, canPost: false))
        requester.accessAfterRequest = .init(canListen: true, canPost: true)
        let coordinator = PasteCompatibilityCoordinator(permissionRequester: requester)
        let installer = MatrixEventTapInstaller()
        let tap = SystemPasteCompatibilityEventTap(
            coordinator: coordinator,
            poster: MatrixKeyboardPoster(),
            permissionRequester: requester,
            installer: installer
        )
        var completionCount = 0
        coordinator.onAccessBecameComplete = {
            completionCount += 1
            _ = tap.start()
        }

        coordinator.screenshotCopied(changeCount: 10)

        XCTAssertEqual(requester.requestCount, 1)
        XCTAssertEqual(completionCount, 1)
        XCTAssertEqual(installer.installCount, 1)
        XCTAssertEqual(coordinator.handle(.keyDown(key: "v", modifiers: [.control])), .convertToCommandV)

        coordinator.screenshotCopied(changeCount: 11)
        XCTAssertEqual(requester.requestCount, 1)
        XCTAssertEqual(completionCount, 1)
        XCTAssertEqual(installer.installCount, 1)
    }

    func testDeniedAccessAfterRequestDoesNotArmInterceptOrInstallEventTap() {
        let requester = MatrixPermissionRequester(initialAccess: .init(canListen: false, canPost: false))
        requester.accessAfterRequest = .init(canListen: false, canPost: false)
        let coordinator = PasteCompatibilityCoordinator(permissionRequester: requester)
        let poster = MatrixKeyboardPoster()
        let installer = MatrixEventTapInstaller()
        let tap = SystemPasteCompatibilityEventTap(
            coordinator: coordinator,
            poster: poster,
            permissionRequester: requester,
            installer: installer
        )
        let controller = PasteCompatibilityEventTapController(coordinator: coordinator, poster: poster)

        coordinator.screenshotCopied(changeCount: 20)

        XCTAssertEqual(requester.requestCount, 1)
        XCTAssertFalse(tap.start())
        XCTAssertEqual(installer.installCount, 0)
        XCTAssertEqual(controller.handle(.keyDown(key: "v", modifiers: [.control])), .passThrough)
        XCTAssertTrue(poster.postedCommands.isEmpty)
    }

    func testListenOnlyPartialAccessDoesNotArmInterceptOrInstallEventTap() {
        assertPartialAccessDoesNotIntercept(.init(canListen: true, canPost: false))
    }

    func testPostOnlyAccessDoesNotNeedAnotherPermissionRequestOrInstallEventTap() {
        let requester = MatrixPermissionRequester(initialAccess: .init(canListen: false, canPost: true))
        let coordinator = PasteCompatibilityCoordinator(permissionRequester: requester)
        let poster = MatrixKeyboardPoster()
        let installer = MatrixEventTapInstaller()
        let tap = SystemPasteCompatibilityEventTap(
            coordinator: coordinator,
            poster: poster,
            permissionRequester: requester,
            installer: installer
        )

        coordinator.screenshotCopied(changeCount: 40)

        XCTAssertEqual(requester.requestCount, 0)
        XCTAssertFalse(tap.start())
        XCTAssertEqual(installer.installCount, 0)
    }

    func testPreviouslyAllowedAccessAfterRestartStartsAtLaunchAndArmsWithoutRequesting() {
        let requester = MatrixPermissionRequester(initialAccess: .init(canListen: true, canPost: true))
        let coordinator = PasteCompatibilityCoordinator(permissionRequester: requester)
        let poster = MatrixKeyboardPoster()
        let installer = MatrixEventTapInstaller()
        let tap = SystemPasteCompatibilityEventTap(
            coordinator: coordinator,
            poster: poster,
            permissionRequester: requester,
            installer: installer
        )

        XCTAssertTrue(tap.start())
        coordinator.screenshotCopied(changeCount: 30)
        let decision = PasteCompatibilityEventTapController(coordinator: coordinator, poster: poster)
            .handle(.keyDown(key: "v", modifiers: [.control]))

        XCTAssertEqual(requester.requestCount, 0)
        XCTAssertEqual(installer.installCount, 1)
        XCTAssertEqual(decision, .suppressOriginal)
        XCTAssertEqual(poster.postedCommands, [.commandV])
    }

    private func assertPartialAccessDoesNotIntercept(_ access: KeyboardEventAccess) {
        let requester = MatrixPermissionRequester(initialAccess: access)
        requester.accessAfterRequest = access
        let coordinator = PasteCompatibilityCoordinator(permissionRequester: requester)
        let poster = MatrixKeyboardPoster()
        let installer = MatrixEventTapInstaller()
        let tap = SystemPasteCompatibilityEventTap(
            coordinator: coordinator,
            poster: poster,
            permissionRequester: requester,
            installer: installer
        )
        let controller = PasteCompatibilityEventTapController(coordinator: coordinator, poster: poster)

        coordinator.screenshotCopied(changeCount: 40)

        XCTAssertEqual(requester.requestCount, 1)
        XCTAssertFalse(tap.start())
        XCTAssertEqual(installer.installCount, 0)
        XCTAssertEqual(controller.handle(.keyDown(key: "v", modifiers: [.control])), .passThrough)
        XCTAssertTrue(poster.postedCommands.isEmpty)
    }
}

private final class MatrixPermissionRequester: InputCompatibilityPermissionRequester {
    var access: KeyboardEventAccess
    var accessAfterRequest: KeyboardEventAccess?
    private(set) var requestCount = 0

    init(initialAccess: KeyboardEventAccess) {
        self.access = initialAccess
    }

    func currentAccess() -> KeyboardEventAccess {
        access
    }

    func explainAndRequestInputCompatibilityAccess() {
        requestCount += 1
        if let accessAfterRequest {
            access = accessAfterRequest
        }
    }
}

private final class MatrixKeyboardPoster: KeyboardEventPoster {
    private(set) var postedCommands: [KeyboardPostCommand] = []

    func post(_ command: KeyboardPostCommand) {
        postedCommands.append(command)
    }
}

private final class MatrixEventTapInstaller: PasteCompatibilityEventTapInstalling {
    private(set) var installCount = 0

    func install() -> Bool {
        installCount += 1
        return true
    }

    func stop() {}
}
