import XCTest
@testable import ZoomItMacCore

final class ApplePreviousRegionSnipTests: XCTestCase {
    func testSuccessfulSelectionCanBeReusedOnlyOnSameDisplayTopology() {
        var memory = PreviousRegionSnipMemory()
        let displays = [display(id: 7, scale: 2)]
        let selection = CGRect(x: 10, y: 20, width: 80, height: 40)

        XCTAssertEqual(memory.plan(for: displays), .selectNew(reason: .noHistory))
        memory.remember(selection: selection, displayID: 7, displays: displays)

        XCTAssertEqual(
            memory.plan(for: displays),
            .reuse(.init(
                displayID: 7,
                selectionInPoints: selection,
                pixelRect: CGRect(x: 20, y: 40, width: 160, height: 80)
            ))
        )
    }

    func testTopologyChangeInvalidatesHistoryInsteadOfReusingOldCoordinates() {
        var memory = PreviousRegionSnipMemory()
        let original = [display(id: 7, scale: 2)]
        memory.remember(
            selection: CGRect(x: 10, y: 20, width: 80, height: 40),
            displayID: 7,
            displays: original
        )
        let changed = [PreviousRegionDisplay(
            id: 7,
            frame: CGRect(x: 0, y: 0, width: 1728, height: 1117),
            scaleFactor: 2
        )]

        XCTAssertEqual(memory.plan(for: changed), .selectNew(reason: .topologyChanged))
        XCTAssertEqual(memory.plan(for: original), .selectNew(reason: .noHistory))
    }

    func testCancelledFreshSelectionKeepsLastSuccessfulRegion() {
        var memory = PreviousRegionSnipMemory()
        let displays = [display(id: 7, scale: 2)]
        let selection = CGRect(x: 10, y: 20, width: 80, height: 40)
        memory.remember(selection: selection, displayID: 7, displays: displays)

        memory.selectionCancelled()

        guard case .reuse(let plan) = memory.plan(for: displays) else {
            return XCTFail("cancelling a new selection must not erase the last successful region")
        }
        XCTAssertEqual(plan.selectionInPoints, selection)
    }

    func testPreviousRegionAlwaysUsesMemoryPasteboardExportPlan() {
        XCTAssertEqual(
            PreviousRegionSnipMemory.exportOperations,
            [.pasteboardImage]
        )
        XCTAssertFalse(PreviousRegionSnipMemory.exportOperations.contains(.directoryFile))
        XCTAssertFalse(PreviousRegionSnipMemory.exportOperations.contains(.savePanel))
    }

    @MainActor
    func testStatusMenuExposesFreshAndPreviousRegionScreenshotActions() {
        XCTAssertEqual(
            AppDelegate.actionSelector(for: .snipRegion),
            #selector(AppController.snipRegion)
        )
        XCTAssertEqual(
            AppDelegate.actionSelector(for: .snipPreviousRegion),
            #selector(AppController.snipPreviousRegion)
        )
    }

    private func display(id: UInt32, scale: CGFloat) -> PreviousRegionDisplay {
        PreviousRegionDisplay(
            id: id,
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            scaleFactor: scale
        )
    }
}
