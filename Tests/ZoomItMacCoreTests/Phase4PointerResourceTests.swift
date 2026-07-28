import XCTest
@testable import ZoomItMacCore

final class Phase4PointerResourceTests: XCTestCase {
    func testPointerResourceCatalogDifferentiatesSelectionPurposes() {
        let screenshot = PointerResourceCatalog.resource(for: .screenshot)
        let ocr = PointerResourceCatalog.resource(for: .ocr)
        let recording = PointerResourceCatalog.resource(for: .recordingSelection)
        let panorama = PointerResourceCatalog.resource(for: .panoramaSelection)

        XCTAssertEqual(screenshot.shape, .captureCrosshair)
        XCTAssertEqual(ocr.shape, .textScanCrosshair)
        XCTAssertEqual(recording.shape, .recordFrameCrosshair)
        XCTAssertEqual(panorama.shape, .panoramaScrollCrosshair)

        XCTAssertEqual(Set([screenshot.tint, ocr.tint, recording.tint, panorama.tint]).count, 4)
        XCTAssertEqual(screenshot.hotspot, CGPoint(x: 12, y: 12))
        XCTAssertEqual(ocr.hotspot, CGPoint(x: 12, y: 12))
        XCTAssertEqual(recording.hotspot, CGPoint(x: 12, y: 12))
        XCTAssertEqual(panorama.hotspot, CGPoint(x: 12, y: 12))

        for resource in [screenshot, ocr, recording, panorama] {
            XCTAssertEqual(resource.scaleVariants, [.oneX, .twoX])
        }
    }

    func testPresentationSnapshotUsesPurposeSpecificSelectionPointers() {
        XCTAssertEqual(pointer(for: .regionSelection(.screenshotToClipboard)), .crosshair(purpose: .screenshot))
        XCTAssertEqual(pointer(for: .regionSelection(.ocrToClipboard)), .crosshair(purpose: .ocr))
        XCTAssertEqual(pointer(for: .regionSelection(.recording)), .crosshair(purpose: .recordingSelection))
        XCTAssertEqual(pointer(for: .panorama(save: false)), .crosshair(purpose: .panoramaSelection))
    }

    func testSnipActionProvidesSelectionPointerPurpose() {
        XCTAssertEqual(SnipAction.copyImage.pointerPurpose, .screenshot)
        XCTAssertEqual(SnipAction.saveImage.pointerPurpose, .screenshot)
        XCTAssertEqual(SnipAction.recognizeText.pointerPurpose, .ocr)
    }

    private func pointer(for interaction: InteractionState) -> PointerFeedback {
        let state = AppSessionState(
            interaction: interaction,
            recording: .idle,
            annotation: .init(tool: .pen, color: .red, isHighlighter: false),
            canvas: .transparent
        )
        return InteractionPresentationSnapshot.derive(from: state).pointer
    }
}
