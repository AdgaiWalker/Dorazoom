import XCTest
@testable import ZoomItMacCore

final class Phase7HotkeyFallbackSimulationTests: XCTestCase {
    @MainActor
    func testMissingListenPermissionPromptsOnlyOnceAcrossHotkeyReregistration() {
        let session = HotkeyFallbackPermissionSession()

        XCTAssertEqual(session.action(hasListenAccess: false), .promptForAuthorization)
        XCTAssertEqual(session.action(hasListenAccess: false), .waitForRelaunch)
        XCTAssertEqual(session.action(hasListenAccess: false), .waitForRelaunch)
        XCTAssertEqual(session.action(hasListenAccess: true), .installEventTap)
    }

    @MainActor
    func testEventTapFallbackDispatchesZoomItControlNumberShortcutsThatCarbonCouldNotRegister() {
        var dispatched: [AppCommand] = []
        let bindings: [HotkeyFallbackBinding] = [
            .init(command: .activateStaticZoom, keyCode: 18, modifiers: [.control]),
            .init(command: .activateDrawWithoutZoom, keyCode: 19, modifiers: [.control]),
            .init(command: .snipRegion(save: false), keyCode: 22, modifiers: [.control])
        ]
        let controller = HotkeyFallbackEventTapController(bindings: bindings) { command in
            dispatched.append(command)
        }

        XCTAssertEqual(controller.handle(keyCode: 18, modifiers: [.control], isSynthetic: false), .suppressOriginal)
        XCTAssertEqual(controller.handle(keyCode: 19, modifiers: [.control], isSynthetic: false), .suppressOriginal)
        XCTAssertEqual(controller.handle(keyCode: 22, modifiers: [.control], isSynthetic: false), .suppressOriginal)

        XCTAssertEqual(dispatched, [
            .activateStaticZoom,
            .activateDrawWithoutZoom,
            .snipRegion(save: false)
        ])
    }

    @MainActor
    func testEventTapFallbackIgnoresNonMatchingAndSyntheticKeyboardEvents() {
        var dispatched: [AppCommand] = []
        let controller = HotkeyFallbackEventTapController(
            bindings: [.init(command: .activateStaticZoom, keyCode: 18, modifiers: [.control])]
        ) { command in
            dispatched.append(command)
        }

        XCTAssertEqual(controller.handle(keyCode: 18, modifiers: [.control, .shift], isSynthetic: false), .passThrough)
        XCTAssertEqual(controller.handle(keyCode: 18, modifiers: [.control], isSynthetic: true), .passThrough)
        XCTAssertEqual(controller.handle(keyCode: 20, modifiers: [.control], isSynthetic: false), .passThrough)
        XCTAssertEqual(dispatched, [])
    }
}
