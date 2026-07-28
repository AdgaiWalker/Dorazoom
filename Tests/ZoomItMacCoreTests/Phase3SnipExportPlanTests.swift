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
            copyOCR: { image in
                ocrImages.append(image)
            }
        )

        let changeCounts = executor.execute(
            image: "selected-region",
            operations: SnipExportPlan.operations(for: .copyImage, settings: .defaults)
        )

        XCTAssertEqual(changeCounts, [7])
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
}
