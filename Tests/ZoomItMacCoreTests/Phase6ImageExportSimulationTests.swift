import XCTest
@testable import ZoomItMacCore

final class Phase6ImageExportSimulationTests: XCTestCase {
    func testCurrentViewportSaveToDirectoryAlsoArmsPasteCompatibilityWhenConfigured() {
        var settings = AppSettings.defaults
        settings.copySnipToClipboardOnSave = true
        settings.saveSnipToDirectory = true
        settings.snipSaveDirectory = "/Users/dora/Pictures/DoraZoom"

        let result = ImageExportSimulation.run(
            image: .fixed(id: "viewport-2x", pixelWidth: 1440, pixelHeight: 900),
            action: .saveImage,
            source: .currentViewport,
            settings: settings,
            savePanel: .notPresented,
            ocr: .notRequested,
            clock: .fixed(filename: "DoraZoom 2026-07-27 095800.png")
        )

        XCTAssertEqual(result.platformBoundary, .simulatedOnly)
        XCTAssertEqual(result.pasteboard.images.map(\.id), ["viewport-2x"])
        XCTAssertEqual(result.pasteboard.changeCounts, [1])
        XCTAssertEqual(result.files, [
            .init(path: "/Users/dora/Pictures/DoraZoom/DoraZoom 2026-07-27 095800.png", imageID: "viewport-2x")
        ])
        XCTAssertEqual(result.savePanelEvents, [])
        XCTAssertEqual(result.pasteCompatibilityChangeCountsToArm, [1])
        XCTAssertEqual(result.outcome, .completed)
    }

    func testRegionSnipSavePanelAcceptCancelAndFailureAreSimulatedWithoutTouchingFilesystem() {
        var settings = AppSettings.defaults
        settings.copySnipToClipboardOnSave = false
        settings.saveSnipToDirectory = false

        let accepted = ImageExportSimulation.run(
            image: .fixed(id: "region-1", pixelWidth: 640, pixelHeight: 360),
            action: .saveImage,
            source: .regionSelection,
            settings: settings,
            savePanel: .accepted(path: "/tmp/region.png"),
            ocr: .notRequested,
            clock: .fixed(filename: "unused.png")
        )
        XCTAssertEqual(accepted.savePanelEvents, [.presented(suggestedFilename: "unused.png"), .accepted(path: "/tmp/region.png")])
        XCTAssertEqual(accepted.files, [.init(path: "/tmp/region.png", imageID: "region-1")])
        XCTAssertEqual(accepted.pasteboard.images, [])
        XCTAssertEqual(accepted.outcome, .completed)

        let cancelled = ImageExportSimulation.run(
            image: .fixed(id: "region-2", pixelWidth: 640, pixelHeight: 360),
            action: .saveImage,
            source: .regionSelection,
            settings: settings,
            savePanel: .cancelled,
            ocr: .notRequested,
            clock: .fixed(filename: "cancel.png")
        )
        XCTAssertEqual(cancelled.savePanelEvents, [.presented(suggestedFilename: "cancel.png"), .cancelled])
        XCTAssertEqual(cancelled.files, [])
        XCTAssertEqual(cancelled.outcome, .cancelled)

        let failed = ImageExportSimulation.run(
            image: .fixed(id: "region-3", pixelWidth: 640, pixelHeight: 360),
            action: .saveImage,
            source: .regionSelection,
            settings: settings,
            savePanel: .failed(message: "disk full"),
            ocr: .notRequested,
            clock: .fixed(filename: "failed.png")
        )
        XCTAssertEqual(failed.savePanelEvents, [.presented(suggestedFilename: "failed.png"), .failed(message: "disk full")])
        XCTAssertEqual(failed.files, [])
        XCTAssertEqual(failed.outcome, .failed(message: "disk full"))
    }

    func testOCRWritesRecognizedTextOnlyAndEmptyResultBeepsWithoutChangingClipboard() {
        let recognized = ImageExportSimulation.run(
            image: .fixed(id: "ocr-region", pixelWidth: 500, pixelHeight: 200),
            action: .recognizeText,
            source: .regionSelection,
            settings: .defaults,
            savePanel: .notPresented,
            ocr: .recognized("Hello Dora\nZoomIt"),
            clock: .fixed(filename: "unused.png")
        )
        XCTAssertEqual(recognized.pasteboard.text, "Hello Dora\nZoomIt")
        XCTAssertEqual(recognized.pasteboard.images, [])
        XCTAssertEqual(recognized.files, [])
        XCTAssertEqual(recognized.feedback, [])
        XCTAssertEqual(recognized.outcome, .completed)

        let empty = ImageExportSimulation.run(
            image: .fixed(id: "empty-ocr-region", pixelWidth: 500, pixelHeight: 200),
            action: .recognizeText,
            source: .regionSelection,
            settings: .defaults,
            savePanel: .notPresented,
            ocr: .recognized(""),
            clock: .fixed(filename: "unused.png")
        )
        XCTAssertNil(empty.pasteboard.text)
        XCTAssertEqual(empty.pasteboard.changeCounts, [])
        XCTAssertEqual(empty.feedback, [.beep(reason: .ocrFoundNoText)])
        XCTAssertEqual(empty.outcome, .cancelled)
    }
}
