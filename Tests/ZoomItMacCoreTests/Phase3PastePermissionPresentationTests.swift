import XCTest
@testable import ZoomItMacCore

final class Phase3PastePermissionPresentationTests: XCTestCase {
    func testSettingStatusReportsMissingListenAndPostAccess() {
        let requester = PresentationPermissionRequester(access: .init(canListen: false, canPost: false))
        let coordinator = PasteCompatibilityCoordinator(permissionRequester: requester)

        XCTAssertEqual(coordinator.settingStatus, .waitingForAuthorization(missing: [.listen, .post]))
    }

    func testSettingStatusBecomesReadyWhenBothAccessesAreGranted() {
        let requester = PresentationPermissionRequester(access: .init(canListen: true, canPost: true))
        let coordinator = PasteCompatibilityCoordinator(permissionRequester: requester)

        XCTAssertEqual(coordinator.settingStatus, .ready)
    }

    func testAccessExplanationNamesControlVCompatibilityAndCommandVFallback() {
        let explanation = InputCompatibilityAccessExplanation.controlVPaste

        XCTAssertEqual(explanation.title, "启用 ⌃V 粘贴截图")
        XCTAssertTrue(explanation.message.contains("⌃V"))
        XCTAssertTrue(explanation.message.contains("⌘V"))
        XCTAssertTrue(explanation.message.contains("监听"))
        XCTAssertTrue(explanation.message.contains("发送"))
    }
}

private final class PresentationPermissionRequester: InputCompatibilityPermissionRequester {
    var access: KeyboardEventAccess

    init(access: KeyboardEventAccess) {
        self.access = access
    }

    func currentAccess() -> KeyboardEventAccess {
        access
    }

    func explainAndRequestInputCompatibilityAccess() {}
}
