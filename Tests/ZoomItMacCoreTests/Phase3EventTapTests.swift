import XCTest
@testable import ZoomItMacCore

@MainActor
final class Phase3EventTapTests: XCTestCase {
    func testControlVPasteHotkeyWorksWithPostAccessWhenListenAccessIsUnavailable() {
        let requester = FakeEventTapPermissionRequester(access: .init(canListen: false, canPost: true))
        let registrar = FakeControlVPasteHotkeyRegistrar()
        let poster = FakeKeyboardEventPoster()
        let pasteboard = FakePasteboardChangeCountProvider(changeCount: 42)
        let service = ControlVPasteHotkeyService(
            permissionRequester: requester,
            registrar: registrar,
            poster: poster,
            pasteboard: pasteboard
        )

        service.screenshotCopied(changeCount: 42)
        registrar.triggerControlV()

        XCTAssertEqual(registrar.registeredHotkeys, [.controlV])
        XCTAssertEqual(poster.postedCommands, [.commandV])
    }

    func testNativeTextEditingTemporarilyUnregistersControlVWithoutLosingArmedScreenshot() {
        let requester = FakeEventTapPermissionRequester(access: .init(canListen: false, canPost: true))
        let registrar = FakeControlVPasteHotkeyRegistrar()
        let poster = FakeKeyboardEventPoster()
        let pasteboard = FakePasteboardChangeCountProvider(changeCount: 42)
        let service = ControlVPasteHotkeyService(
            permissionRequester: requester,
            registrar: registrar,
            poster: poster,
            pasteboard: pasteboard
        )

        service.screenshotCopied(changeCount: 42)
        service.setTextEditingActive(true)
        registrar.triggerControlV()
        XCTAssertTrue(poster.postedCommands.isEmpty)
        XCTAssertFalse(registrar.isRegistered)

        service.setTextEditingActive(false)
        registrar.triggerControlV()
        XCTAssertTrue(registrar.isRegistered)
        XCTAssertEqual(poster.postedCommands, [.commandV])
    }

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

    func testEventTapPassesControlVThroughWhileNativeTextEditingIsActive() {
        let requester = FakeEventTapPermissionRequester(access: .init(canListen: true, canPost: true))
        let coordinator = PasteCompatibilityCoordinator(permissionRequester: requester)
        let poster = FakeKeyboardEventPoster()
        let eventTap = PasteCompatibilityEventTapController(coordinator: coordinator, poster: poster)
        coordinator.screenshotCopied(changeCount: 100)

        coordinator.setTextEditingActive(true)
        XCTAssertEqual(
            eventTap.handle(.keyDown(key: "v", modifiers: [.control])),
            .passThrough
        )
        XCTAssertTrue(poster.postedCommands.isEmpty)

        coordinator.setTextEditingActive(false)
        XCTAssertEqual(
            eventTap.handle(.keyDown(key: "v", modifiers: [.control])),
            .suppressOriginal
        )
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

}

private final class FakeEventTapInstaller: PasteCompatibilityEventTapInstalling {
    private(set) var installCount = 0

    func install() -> Bool {
        installCount += 1
        return true
    }

    func stop() {}
}

@MainActor
private final class FakeControlVPasteHotkeyRegistrar: ControlVPasteHotkeyRegistering {
    private(set) var registeredHotkeys: [PasteCompatibilityHotkey] = []
    private var handler: (() -> Void)?
    var isRegistered: Bool { handler != nil }

    func register(_ hotkey: PasteCompatibilityHotkey, handler: @escaping () -> Void) -> Bool {
        registeredHotkeys.append(hotkey)
        self.handler = handler
        return true
    }

    func unregister() {
        handler = nil
    }

    func triggerControlV() {
        handler?()
    }
}

private final class FakePasteboardChangeCountProvider: PasteboardChangeCountProviding {
    var changeCount: Int

    init(changeCount: Int) {
        self.changeCount = changeCount
    }
}
