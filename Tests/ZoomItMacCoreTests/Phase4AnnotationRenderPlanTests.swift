import XCTest
@testable import ZoomItMacCore

@MainActor
final class Phase4AnnotationRenderPlanTests: XCTestCase {
    func testRenderPlanCoversAllDrawingToolsWithStyle() {
        let style = AnnotationStyle(color: .green, rootWidth: 7, alpha: 1)
        let first = CGPoint(x: 10, y: 20)
        let last = CGPoint(x: 80, y: 90)

        let operations = AnnotationRenderPlan.operations(for: [
            Annotation(tool: .pen, points: [first, last], style: style),
            Annotation(tool: .line, points: [first, last], style: style),
            Annotation(tool: .rectangle, points: [first, last], style: style),
            Annotation(tool: .ellipse, points: [first, last], style: style),
            Annotation(tool: .arrow, points: [first, last], style: style),
            Annotation(tool: .highlighter, points: [first, last], style: AnnotationStyle(color: .yellow, rootWidth: 11, alpha: 0.5)),
            Annotation(tool: .text, points: [first], style: style, text: "Hello", fontSize: 24)
        ])

        XCTAssertEqual(Set(operations.map(\.kind)), [
            .freehand,
            .line,
            .rectangleOutline,
            .ellipseOutline,
            .arrow,
            .highlightFreehand,
            .text
        ])
        let freehand = operations.first { $0.kind == .freehand }
        let highlighter = operations.first { $0.kind == .highlightFreehand }
        let text = operations.first { $0.kind == .text }
        XCTAssertEqual(freehand?.style.color, .green)
        XCTAssertEqual(freehand?.style.rootWidth, 7)
        XCTAssertEqual(highlighter?.style.alpha, AnnotationStyle.highlightAlpha)
        XCTAssertEqual(text?.text, "Hello")
    }

    func testAnnotationControllerProducesPlanWithColorWidthUndoAndClear() {
        let controller = AnnotationController()
        controller.currentTool = .pen
        controller.currentStyle = AnnotationStyle(color: .blue, rootWidth: 9, alpha: 1)

        controller.begin(at: CGPoint(x: 1, y: 2))
        controller.update(at: CGPoint(x: 20, y: 30))
        controller.end(at: CGPoint(x: 40, y: 50))

        XCTAssertEqual(controller.renderPlanSnapshot.map(\.kind), [.freehand])
        XCTAssertEqual(controller.renderPlanSnapshot.first?.style.color, .blue)
        XCTAssertEqual(controller.renderPlanSnapshot.first?.style.rootWidth, 9)

        controller.undo()
        XCTAssertTrue(controller.renderPlanSnapshot.isEmpty)

        controller.currentTool = .rectangle
        controller.begin(at: CGPoint(x: 3, y: 4))
        controller.end(at: CGPoint(x: 30, y: 40))
        XCTAssertEqual(controller.renderPlanSnapshot.map(\.kind), [.rectangleOutline])

        controller.clear()
        XCTAssertTrue(controller.renderPlanSnapshot.isEmpty)
    }
}
