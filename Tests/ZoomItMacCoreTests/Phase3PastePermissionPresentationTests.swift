import XCTest
@testable import ZoomItMacCore

final class Phase3PastePermissionPresentationTests: XCTestCase {
    func testSettingStatusReportsMissingPostAccess() {
        let requester = PresentationPermissionRequester(access: .init(canListen: false, canPost: false))
        let coordinator = PasteCompatibilityCoordinator(permissionRequester: requester)

        XCTAssertEqual(coordinator.settingStatus, .waitingForAuthorization(missing: [.post]))
    }

    func testSettingStatusBecomesReadyWhenBothAccessesAreGranted() {
        let requester = PresentationPermissionRequester(access: .init(canListen: true, canPost: true))
        let coordinator = PasteCompatibilityCoordinator(permissionRequester: requester)

        XCTAssertEqual(coordinator.settingStatus, .ready)
    }

    func testSettingStatusBecomesReadyWithPostAccessEvenWhenListenAccessIsUnavailable() {
        let requester = PresentationPermissionRequester(access: .init(canListen: false, canPost: true))
        let coordinator = PasteCompatibilityCoordinator(permissionRequester: requester)

        XCTAssertEqual(coordinator.settingStatus, .ready)
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

}
