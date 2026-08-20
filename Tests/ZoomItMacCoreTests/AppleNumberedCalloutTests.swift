import AppKit
import XCTest
@testable import ZoomItMacCore

@MainActor
final class AppleNumberedCalloutTests: XCTestCase {
    func testCalloutsIncrementAndDragToReleasePoint() throws {
        let controller = makeController()

        addCallout(to: controller, from: CGPoint(x: 10, y: 10), to: CGPoint(x: 24, y: 28))
        addCallout(to: controller, from: CGPoint(x: 30, y: 10), to: CGPoint(x: 42, y: 28))

        XCTAssertEqual(controller.renderPlanSnapshot.map(\.kind), [.numberedCallout, .numberedCallout])
        XCTAssertEqual(controller.renderPlanSnapshot.map(\.calloutNumber), [1, 2])
        XCTAssertEqual(controller.renderPlanSnapshot.map { $0.points.last }, [CGPoint(x: 24, y: 28), CGPoint(x: 42, y: 28)])
    }

    func testUndoRollsBackNumberAndClearRestartsAtOne() {
        let controller = makeController()
        addCallout(to: controller, from: .zero, to: CGPoint(x: 10, y: 10))
        addCallout(to: controller, from: .zero, to: CGPoint(x: 20, y: 20))

        controller.undo()
        addCallout(to: controller, from: .zero, to: CGPoint(x: 30, y: 30))
        XCTAssertEqual(controller.renderPlanSnapshot.map(\.calloutNumber), [1, 2])

        controller.clear()
        addCallout(to: controller, from: .zero, to: CGPoint(x: 40, y: 40))
        XCTAssertEqual(controller.renderPlanSnapshot.map(\.calloutNumber), [1])
    }

    func testCalloutRendersIntoFinalBitmapPixels() throws {
        let controller = makeController()
        addCallout(to: controller, from: CGPoint(x: 12, y: 12), to: CGPoint(x: 32, y: 32))
        let width = 64
        let height = 64
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        let rendered = pixels.withUnsafeMutableBytes { storage -> Bool in
            guard let context = CGContext(
                data: storage.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            controller.render(
                in: context,
                bounds: CGRect(x: 0, y: 0, width: width, height: height),
                includesPrivacyPreview: true
            )
            return true
        }

        XCTAssertTrue(rendered)
        XCTAssertTrue(pixels.enumerated().contains { index, value in
            index % 4 != 3 && value < 240
        })
    }

    func testNumberedCalloutUsesModeLocalNShortcut() {
        XCTAssertEqual(
            DrawingShortcutPolicy.zoomItDefault.action(for: DrawingShortcut(key: "n")),
            .setTool(.numberedCallout)
        )
    }

    private func makeController() -> AnnotationController {
        let controller = AnnotationController()
        controller.currentTool = .numberedCallout
        controller.currentStyle = AnnotationStyle(color: .red, rootWidth: 5, alpha: 1)
        return controller
    }

    private func addCallout(to controller: AnnotationController, from start: CGPoint, to end: CGPoint) {
        controller.begin(at: start)
        controller.update(at: end)
        controller.end(at: end)
    }
}
