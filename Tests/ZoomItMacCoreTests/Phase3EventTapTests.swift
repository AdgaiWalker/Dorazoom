import XCTest
@testable import ZoomItMacCore

@MainActor
final class Phase3EventTapTests: XCTestCase {
    func testArmedControlVPostsCommandVAndSuppressesOriginalEvent() {
        let requester = FakeEventTapPermissionRequester(access: .init(canListen: true, canPost: true))
        let coordinator = PasteCompatibilityCoordinator(permissionRequester: requester)
        let poster = FakeKeyboardEventPoster()
        let eventTap = PasteCompatibilityEventTapController(coordinator: coordinator, poster: poster)

        coordinator.screenshotCopied(changeCount: 100)

        let decision = eventTap.handle(.keyDown(key: "v", modifiers: [.control]))

        XCTAssertEqual(decision, .suppressOriginal)
        XCTAssertEqual(poster.postedCommands, [.commandV])
    }

    func testUnarmedControlVPassesThroughWithoutPosting() {
        let requester = FakeEventTapPermissionRequester(access: .init(canListen: true, canPost: true))
        let coordinator = PasteCompatibilityCoordinator(permissionRequester: requester)
        let poster = FakeKeyboardEventPoster()
        let eventTap = PasteCompatibilityEventTapController(coordinator: coordinator, poster: poster)

        let decision = eventTap.handle(.keyDown(key: "v", modifiers: [.control]))

        XCTAssertEqual(decision, .passThrough)
        XCTAssertTrue(poster.postedCommands.isEmpty)
    }

    func testSyntheticAndNonExactControlVEventsPassThroughWithoutPosting() {
        let requester = FakeEventTapPermissionRequester(access: .init(canListen: true, canPost: true))
        let coordinator = PasteCompatibilityCoordinator(permissionRequester: requester)
        let poster = FakeKeyboardEventPoster()
        let eventTap = PasteCompatibilityEventTapController(coordinator: coordinator, poster: poster)

        coordinator.screenshotCopied(changeCount: 200)

        XCTAssertEqual(eventTap.handle(.keyDown(key: "v", modifiers: [.control], isSynthetic: true)), .passThrough)
        XCTAssertEqual(eventTap.handle(.keyDown(key: "v", modifiers: [.control, .shift])), .passThrough)
        XCTAssertEqual(eventTap.handle(.keyDown(key: "c", modifiers: [.control])), .passThrough)
        XCTAssertTrue(poster.postedCommands.isEmpty)
    }

    func testCommandVAlwaysPassesThroughInUnarmedUnauthorizedAndAuthorizedStates() {
        let unauthorizedRequester = FakeEventTapPermissionRequester(access: .init(canListen: false, canPost: false))
        let unauthorizedCoordinator = PasteCompatibilityCoordinator(permissionRequester: unauthorizedRequester)
        let unauthorizedPoster = FakeKeyboardEventPoster()
        let unauthorizedTap = PasteCompatibilityEventTapController(coordinator: unauthorizedCoordinator, poster: unauthorizedPoster)
        unauthorizedCoordinator.screenshotCopied(changeCount: 1)

        XCTAssertEqual(unauthorizedTap.handle(.keyDown(key: "v", modifiers: [.command])), .passThrough)
        XCTAssertTrue(unauthorizedPoster.postedCommands.isEmpty)

        let unarmedRequester = FakeEventTapPermissionRequester(access: .init(canListen: true, canPost: true))
        let unarmedCoordinator = PasteCompatibilityCoordinator(permissionRequester: unarmedRequester)
        let unarmedPoster = FakeKeyboardEventPoster()
        let unarmedTap = PasteCompatibilityEventTapController(coordinator: unarmedCoordinator, poster: unarmedPoster)

        XCTAssertEqual(unarmedTap.handle(.keyDown(key: "v", modifiers: [.command])), .passThrough)
        XCTAssertTrue(unarmedPoster.postedCommands.isEmpty)

        let armedRequester = FakeEventTapPermissionRequester(access: .init(canListen: true, canPost: true))
        let armedCoordinator = PasteCompatibilityCoordinator(permissionRequester: armedRequester)
        let armedPoster = FakeKeyboardEventPoster()
        let armedTap = PasteCompatibilityEventTapController(coordinator: armedCoordinator, poster: armedPoster)
        armedCoordinator.screenshotCopied(changeCount: 2)

        XCTAssertEqual(armedTap.handle(.keyDown(key: "v", modifiers: [.command])), .passThrough)
        XCTAssertTrue(armedPoster.postedCommands.isEmpty)
    }

    func testSystemEventTapStartsOnlyWhenListenAndPostAccessAreComplete() {
        let deniedRequester = FakeEventTapPermissionRequester(access: .init(canListen: true, canPost: false))
        let deniedCoordinator = PasteCompatibilityCoordinator(permissionRequester: deniedRequester)
        let deniedInstaller = FakeEventTapInstaller()
        let deniedTap = SystemPasteCompatibilityEventTap(
            coordinator: deniedCoordinator,
            poster: FakeKeyboardEventPoster(),
            permissionRequester: deniedRequester,
            installer: deniedInstaller
        )

        XCTAssertFalse(deniedTap.start())
        XCTAssertEqual(deniedInstaller.installCount, 0)

        let allowedRequester = FakeEventTapPermissionRequester(access: .init(canListen: true, canPost: true))
        let allowedCoordinator = PasteCompatibilityCoordinator(permissionRequester: allowedRequester)
        let allowedInstaller = FakeEventTapInstaller()
        let allowedTap = SystemPasteCompatibilityEventTap(
            coordinator: allowedCoordinator,
            poster: FakeKeyboardEventPoster(),
            permissionRequester: allowedRequester,
            installer: allowedInstaller
        )

        XCTAssertTrue(allowedTap.start())
        XCTAssertEqual(allowedInstaller.installCount, 1)
    }
}

private final class FakeKeyboardEventPoster: KeyboardEventPoster {
    private(set) var postedCommands: [KeyboardPostCommand] = []

    func post(_ command: KeyboardPostCommand) {
        postedCommands.append(command)
    }
}

private final class FakeEventTapPermissionRequester: InputCompatibilityPermissionRequester {
    var access: KeyboardEventAccess

    init(access: KeyboardEventAccess) {
        self.access = access
    }

    func currentAccess() -> KeyboardEventAccess {
        access
    }

    func explainAndRequestInputCompatibilityAccess() {}
}

private final class FakeEventTapInstaller: PasteCompatibilityEventTapInstalling {
    private(set) var installCount = 0

    func install() -> Bool {
        installCount += 1
        return true
    }

    func stop() {}
}
