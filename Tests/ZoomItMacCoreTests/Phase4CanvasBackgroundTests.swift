import XCTest
@testable import ZoomItMacCore

@MainActor
final class Phase4CanvasBackgroundTests: XCTestCase {
    func testDrawingShortcutsMapWAndKToCanvasButNotWhiteOrBlackInk() {
        XCTAssertEqual(
            DrawingShortcutCommandPolicy.command(for: .init(key: "w")),
            .setCanvas(.whiteboard)
        )
        XCTAssertEqual(
            DrawingShortcutCommandPolicy.command(for: .init(key: "k")),
            .setCanvas(.blackboard)
        )

        XCTAssertNil(DrawingShortcutCommandPolicy.command(for: .init(key: "w", modifiers: [.shift])))
        XCTAssertNil(DrawingShortcutCommandPolicy.command(for: .init(key: "k", modifiers: [.shift])))
        XCTAssertNil(DrawingShortcutCommandPolicy.command(for: .init(key: "w", modifiers: [.control])))
        XCTAssertNil(DrawingShortcutCommandPolicy.command(for: .init(key: "k", modifiers: [.control])))

        XCTAssertNil(DrawingShortcutPolicy.zoomItDefault.shortcut(for: .setColor(.white)))
        XCTAssertNil(DrawingShortcutPolicy.zoomItDefault.shortcut(for: .setColor(.black)))
        XCTAssertNil(DrawingShortcutPolicy.zoomItDefault.shortcut(for: .setHighlightColor(.white)))
        XCTAssertNil(DrawingShortcutPolicy.zoomItDefault.shortcut(for: .setHighlightColor(.black)))
        XCTAssertTrue(AnnotationColor.allCases.contains(.white))
        XCTAssertTrue(AnnotationColor.allCases.contains(.black))
    }

    func testCanvasBackgroundLivesWithAnnotationsAndPreservesExistingMarks() {
        let controller = AnnotationController()
        let start = CGPoint(x: 10, y: 10)
        let end = CGPoint(x: 40, y: 40)

        controller.begin(at: start)
        controller.end(at: end)

        XCTAssertEqual(controller.canvasBackground, .transparent)
        XCTAssertEqual(controller.renderPlanSnapshot.count, 1)

        controller.setCanvasBackground(.whiteboard)

        XCTAssertEqual(controller.canvasBackground, .whiteboard)
        XCTAssertEqual(controller.renderPlanSnapshot.count, 1)

        controller.setCanvasBackground(.blackboard)

        XCTAssertEqual(controller.canvasBackground, .blackboard)
        XCTAssertEqual(controller.renderPlanSnapshot.count, 1)
    }

    func testCanvasBackgroundDeclaresExportComposition() {
        XCTAssertEqual(CanvasBackground.transparent.renderFill, .none)
        XCTAssertFalse(CanvasBackground.transparent.isCompositedIntoExports)

        XCTAssertEqual(CanvasBackground.whiteboard.renderFill, .white)
        XCTAssertTrue(CanvasBackground.whiteboard.isCompositedIntoExports)

        XCTAssertEqual(CanvasBackground.blackboard.renderFill, .black)
        XCTAssertTrue(CanvasBackground.blackboard.isCompositedIntoExports)
    }
}
