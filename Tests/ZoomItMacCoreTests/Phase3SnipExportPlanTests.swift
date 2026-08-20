import XCTest
@testable import ZoomItMacCore

final class Phase3SnipExportPlanTests: XCTestCase {
    func testCopyImageWritesOnlyToPasteboardAndNeverToFilesystem() {
        let plan = SnipExportPlan.operations(for: .copyImage, settings: .defaults)

        XCTAssertEqual(plan, [.pasteboardImage])
        XCTAssertFalse(plan.contains(.directoryFile))
        XCTAssertFalse(plan.contains(.savePanel))
    }

    func testCopyImageExecutionTouchesOnlyMemoryPasteboard() {
        var pasteboardImages: [String] = []
        var directoryFiles: [String] = []
        var savePanels: [String] = []
        var ocrImages: [String] = []
        var outputs: [SnipPasteboardOutput] = []
        let executor = SnipExportExecutor<String>(
            copyToPasteboard: { image in
                pasteboardImages.append(image)
                return 7
            },
            writeToDirectory: { image in
                directoryFiles.append(image)
            },
            presentSavePanel: { image in
                savePanels.append(image)
            },
            copyOCR: { image, _ in
                ocrImages.append(image)
            }
        )

        executor.execute(
            image: "selected-region",
            operations: SnipExportPlan.operations(for: .copyImage, settings: .defaults),
            onPasteboardOutput: { outputs.append($0) }
        )

        XCTAssertEqual(outputs, [.image(changeCount: 7)])
        XCTAssertEqual(pasteboardImages, ["selected-region"])
        XCTAssertTrue(directoryFiles.isEmpty)
        XCTAssertTrue(savePanels.isEmpty)
        XCTAssertTrue(ocrImages.isEmpty)
    }

    func testSaveImageUsesConfiguredFileDestinationAndOptionalPasteboardCopy() {
        var settings = AppSettings.defaults
        settings.copySnipToClipboardOnSave = true
        settings.saveSnipToDirectory = true

        XCTAssertEqual(
            SnipExportPlan.operations(for: .saveImage, settings: settings),
            [.pasteboardImage, .directoryFile]
        )

        settings.copySnipToClipboardOnSave = false
        settings.saveSnipToDirectory = false

        XCTAssertEqual(
            SnipExportPlan.operations(for: .saveImage, settings: settings),
            [.savePanel]
        )
    }

    func testOcrSnipOnlyWritesRecognizedTextToClipboard() {
        let plan = SnipExportPlan.operations(for: .recognizeText, settings: .defaults)

        XCTAssertEqual(plan, [.ocrClipboard])
        XCTAssertFalse(plan.contains(.pasteboardImage))
        XCTAssertFalse(plan.contains(.directoryFile))
        XCTAssertFalse(plan.contains(.savePanel))
    }

    func testOcrExecutionPropagatesClipboardIdentityAndUserPerceivedCharacterCount() {
        var outputs: [SnipPasteboardOutput] = []
        let executor = SnipExportExecutor<String>(
            copyToPasteboard: { _ in XCTFail("OCR must not copy an image"); return 0 },
            writeToDirectory: { _ in XCTFail("OCR must not write a file") },
            presentSavePanel: { _ in XCTFail("OCR must not present a save panel") },
            copyOCR: { _, completion in
                completion(.ocrText(changeCount: 19, characterCount: "你好 👋".count))
            }
        )

        executor.execute(
            image: "ocr-region",
            operations: [.ocrClipboard],
            onPasteboardOutput: { outputs.append($0) }
        )

        XCTAssertEqual(outputs, [.ocrText(changeCount: 19, characterCount: 4)])
        XCTAssertEqual(outputs.first?.feedbackCompletion, .ocrCopied(characterCount: 4))
    }
}
