import XCTest
@testable import ZoomItMacCore

final class AppleShortcutGuideConsistencyTests: XCTestCase {
    func testDrawingGuideMatchesBoardAndColorShortcutPolicy() {
        XCTAssertTrue(DrawingShortcutGuide.colors.contains("R / G / B / Y / O / P"))
        XCTAssertTrue(DrawingShortcutGuide.colors.contains("White and black have no default shortcuts"))
        XCTAssertTrue(DrawingShortcutGuide.canvas.contains("press W for a whiteboard or K for a blackboard"))
        XCTAssertFalse(DrawingShortcutGuide.canvas.contains("Control+W"))
        XCTAssertFalse(DrawingShortcutGuide.canvas.contains("Ctrl+W"))
    }

    func testTextGuideMatchesNativeEditorLifecycleAndFontCommands() {
        XCTAssertTrue(DrawingShortcutGuide.text.contains("T"))
        XCTAssertTrue(DrawingShortcutGuide.text.contains("Shift+T"))
        XCTAssertTrue(DrawingShortcutGuide.text.contains("Clicking a new position"))
        XCTAssertTrue(DrawingShortcutGuide.text.contains("Command++ / Command+-"))
        XCTAssertTrue(DrawingShortcutGuide.text.contains("Arrow keys, Delete, selection, and paste are handled by the macOS text system"))
        XCTAssertFalse(DrawingShortcutGuide.text.contains("left click to exit"))
        XCTAssertFalse(DrawingShortcutGuide.text.contains("arrow keys to change the font size"))
    }
}
