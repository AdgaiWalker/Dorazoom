import AppKit
import XCTest
@testable import ZoomItMacCore

@MainActor
final class AppleBlurAndRedactTests: XCTestCase {
    func testRedactionReplacesProtectedPixelsWithOpaqueColor() throws {
        let source = try makeFixture()
        let operation = try XCTUnwrap(AnnotationRenderPlan.operations(for: [
            Annotation(
                tool: .redact,
                points: [CGPoint(x: 3, y: 3), CGPoint(x: 9, y: 9)],
                style: AnnotationStyle(color: .black, rootWidth: 5, alpha: 0.2)
            )
        ]).first)

        XCTAssertEqual(operation.kind, .redactionFill)
        XCTAssertTrue(operation.isPrivacy)

        let output = try XCTUnwrap(PrivacyAnnotationCompositor.composite(
            source: source,
            operations: [operation],
            contentToImageTransform: .identity
        ))

        XCTAssertEqual(try pixel(in: output, x: 6, y: 6), RGBA(0, 0, 0, 255))
        XCTAssertEqual(try pixel(in: output, x: 0, y: 0), try pixel(in: source, x: 0, y: 0))
        XCTAssertNotEqual(try pixel(in: output, x: 6, y: 6), try pixel(in: source, x: 6, y: 6))
    }

    func testBlurBrushChangesProtectedPixelsWithoutChangingOutsidePixels() throws {
        let source = try makeFixture()
        let operation = try XCTUnwrap(AnnotationRenderPlan.operations(for: [
            Annotation(
                tool: .blur,
                points: [CGPoint(x: 4, y: 6), CGPoint(x: 8, y: 6)],
                style: AnnotationStyle(color: .black, rootWidth: 5, alpha: 1)
            )
        ]).first)

        XCTAssertEqual(operation.kind, .blurFreehand)
        XCTAssertTrue(operation.isPrivacy)

        let output = try XCTUnwrap(PrivacyAnnotationCompositor.composite(
            source: source,
            operations: [operation],
            contentToImageTransform: .identity
        ))

        XCTAssertNotEqual(try pixel(in: output, x: 6, y: 6), try pixel(in: source, x: 6, y: 6))
        XCTAssertEqual(try pixel(in: output, x: 0, y: 0), try pixel(in: source, x: 0, y: 0))
    }

    func testUndoRemovesPrivacyAnnotationBeforeComposition() throws {
        let controller = AnnotationController()
        controller.currentTool = .redact
        controller.currentStyle = AnnotationStyle(color: .black, rootWidth: 5, alpha: 1)
        controller.begin(at: CGPoint(x: 3, y: 3))
        controller.end(at: CGPoint(x: 9, y: 9))

        XCTAssertEqual(controller.privacyRenderPlanSnapshot.map(\.kind), [.redactionFill])
        controller.undo()
        XCTAssertTrue(controller.privacyRenderPlanSnapshot.isEmpty)

        let source = try makeFixture()
        let output = try XCTUnwrap(PrivacyAnnotationCompositor.composite(
            source: source,
            operations: controller.privacyRenderPlanSnapshot,
            contentToImageTransform: .identity
        ))
        XCTAssertEqual(try bytes(of: output), try bytes(of: source))
    }

    func testCompositedPrivacyImageCopiesOnlyToMemoryPasteboardBoundary() throws {
        let source = try makeFixture()
        let operations = AnnotationRenderPlan.operations(for: [
            Annotation(
                tool: .redact,
                points: [CGPoint(x: 3, y: 3), CGPoint(x: 9, y: 9)],
                style: AnnotationStyle(color: .black, rootWidth: 5, alpha: 1)
            )
        ])
        let composited = try XCTUnwrap(PrivacyAnnotationCompositor.composite(
            source: source,
            operations: operations,
            contentToImageTransform: .identity
        ))
        var copiedImage: CGImage?
        var fileWriteCount = 0
        var savePanelCount = 0
        var outputs: [SnipPasteboardOutput] = []
        let executor = SnipExportExecutor<CGImage>(
            copyToPasteboard: {
                copiedImage = $0
                return 12
            },
            writeToDirectory: { _ in fileWriteCount += 1 },
            presentSavePanel: { _ in savePanelCount += 1 },
            copyOCR: { _, _ in XCTFail("copy image must not invoke OCR") }
        )

        executor.execute(
            image: composited,
            operations: SnipExportPlan.operations(for: .copyImage, settings: .defaults),
            onPasteboardOutput: { outputs.append($0) }
        )

        XCTAssertEqual(outputs, [.image(changeCount: 12)])
        XCTAssertEqual(try bytes(of: XCTUnwrap(copiedImage)), try bytes(of: composited))
        XCTAssertEqual(fileWriteCount, 0)
        XCTAssertEqual(savePanelCount, 0)
    }

    func testPrivacyToolsUseModeLocalShortcutsWithoutAddingGlobalHotkeys() {
        XCTAssertEqual(
            DrawingShortcutPolicy.zoomItDefault.action(for: DrawingShortcut(key: "m")),
            .setTool(.blur)
        )
        XCTAssertEqual(
            DrawingShortcutPolicy.zoomItDefault.action(for: DrawingShortcut(key: "x")),
            .setTool(.redact)
        )
    }

    private func makeFixture() throws -> CGImage {
        guard let context = CGContext(
            data: nil,
            width: 12,
            height: 12,
            bitsPerComponent: 8,
            bytesPerRow: 12 * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw FixtureError.contextCreationFailed
        }
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
        context.setFillColor(NSColor.systemRed.cgColor)
        context.fill(CGRect(x: 5, y: 5, width: 3, height: 3))
        guard let image = context.makeImage() else {
            throw FixtureError.imageCreationFailed
        }
        return image
    }

    private func bytes(of image: CGImage) throws -> [UInt8] {
        let width = image.width
        let height = image.height
        var storage = [UInt8](repeating: 0, count: width * height * 4)
        let created = storage.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard created else { throw FixtureError.contextCreationFailed }
        return storage
    }

    private func pixel(in image: CGImage, x: Int, y: Int) throws -> RGBA {
        let storage = try bytes(of: image)
        let index = ((image.height - 1 - y) * image.width + x) * 4
        return RGBA(storage[index], storage[index + 1], storage[index + 2], storage[index + 3])
    }
}

private struct RGBA: Equatable {
    var red: UInt8
    var green: UInt8
    var blue: UInt8
    var alpha: UInt8

    init(_ red: UInt8, _ green: UInt8, _ blue: UInt8, _ alpha: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

private enum FixtureError: Error {
    case contextCreationFailed
    case imageCreationFailed
}
