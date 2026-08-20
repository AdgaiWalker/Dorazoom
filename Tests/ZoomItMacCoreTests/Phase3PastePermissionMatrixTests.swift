import XCTest
@testable import ZoomItMacCore

@MainActor
final class Phase3PastePermissionMatrixTests: XCTestCase {
    func testUnknownAccessThenAllowedRequestsOnceArmsAndStartsEventTap() {
        let requester = MatrixPermissionRequester(initialAccess: .init(canListen: false, canPost: false))
        let coordinator = PasteCompatibilityCoordinator(permissionRequester: requester)
        var permissionCenterRequestCount = 0
        coordinator.onInputPostingPermissionNeeded = {
            permissionCenterRequestCount += 1
            requester.access = .init(canListen: true, canPost: true)
        }
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

        XCTAssertEqual(permissionCenterRequestCount, 1)
        XCTAssertEqual(completionCount, 1)
        XCTAssertEqual(installer.installCount, 1)
        XCTAssertEqual(coordinator.handle(.keyDown(key: "v", modifiers: [.control])), .convertToCommandV)

        coordinator.screenshotCopied(changeCount: 11)
        XCTAssertEqual(permissionCenterRequestCount, 1)
        XCTAssertEqual(completionCount, 1)
        XCTAssertEqual(installer.installCount, 1)
    }

    func testDeniedAccessAfterRequestDoesNotArmInterceptOrInstallEventTap() {
        let requester = MatrixPermissionRequester(initialAccess: .init(canListen: false, canPost: false))
        let coordinator = PasteCompatibilityCoordinator(permissionRequester: requester)
        var permissionCenterRequestCount = 0
        coordinator.onInputPostingPermissionNeeded = {
            permissionCenterRequestCount += 1
        }
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

        XCTAssertEqual(permissionCenterRequestCount, 1)
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

        XCTAssertEqual(installer.installCount, 1)
        XCTAssertEqual(decision, .suppressOriginal)
        XCTAssertEqual(poster.postedCommands, [.commandV])
    }

    private func assertPartialAccessDoesNotIntercept(_ access: KeyboardEventAccess) {
        let requester = MatrixPermissionRequester(initialAccess: access)
        let coordinator = PasteCompatibilityCoordinator(permissionRequester: requester)
        var permissionCenterRequestCount = 0
        coordinator.onInputPostingPermissionNeeded = {
            permissionCenterRequestCount += 1
        }
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

        XCTAssertEqual(permissionCenterRequestCount, 1)
        XCTAssertFalse(tap.start())
        XCTAssertEqual(installer.installCount, 0)
        XCTAssertEqual(controller.handle(.keyDown(key: "v", modifiers: [.control])), .passThrough)
        XCTAssertTrue(poster.postedCommands.isEmpty)
    }
}

private final class MatrixPermissionRequester: InputCompatibilityPermissionRequester {
    var access: KeyboardEventAccess

    init(initialAccess: KeyboardEventAccess) {
        self.access = initialAccess
    }

    func currentAccess() -> KeyboardEventAccess {
        access
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
