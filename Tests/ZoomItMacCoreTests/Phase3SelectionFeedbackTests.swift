import XCTest
@testable import ZoomItMacCore

final class Phase3SelectionFeedbackTests: XCTestCase {
    func testSelectionFeedbackUsesPixelDimensionsFromBackingScale() {
        let feedback = RegionSelectionFeedback.presentation(
            selection: CGRect(x: 10, y: 20, width: 123.4, height: 56.6),
            scale: 2,
            container: CGRect(x: 0, y: 0, width: 500, height: 300)
        )

        XCTAssertEqual(feedback?.text, "247 × 113")
    }

    func testSelectionFeedbackIsHiddenForTinySelection() {
        let feedback = RegionSelectionFeedback.presentation(
            selection: CGRect(x: 10, y: 20, width: 2.9, height: 30),
            scale: 2,
            container: CGRect(x: 0, y: 0, width: 500, height: 300)
        )

        XCTAssertNil(feedback)
    }

    func testSelectionFeedbackPositionStaysInsideContainer() {
        let feedback = RegionSelectionFeedback.presentation(
            selection: CGRect(x: 470, y: 280, width: 25, height: 15),
            scale: 2,
            container: CGRect(x: 0, y: 0, width: 500, height: 300)
        )

        XCTAssertNotNil(feedback)
        XCTAssertGreaterThanOrEqual(feedback!.frame.minX, 0)
        XCTAssertGreaterThanOrEqual(feedback!.frame.minY, 0)
        XCTAssertLessThanOrEqual(feedback!.frame.maxX, 500)
        XCTAssertLessThanOrEqual(feedback!.frame.maxY, 300)
    }
}
