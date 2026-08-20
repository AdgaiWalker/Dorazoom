import XCTest
@testable import ZoomItMacCore

final class AppleShortcutGuideConsistencyTests: XCTestCase {
    func testDrawingGuideMatchesBoardAndColorShortcutPolicy() {
        XCTAssertTrue(DrawingShortcutGuide.colors.contains("R / G / B / Y / O / P"))
        XCTAssertTrue(DrawingShortcutGuide.colors.contains("白色和黑色画笔没有默认按键"))
        XCTAssertTrue(DrawingShortcutGuide.canvas.contains("按 W 进入白板，按 K 进入黑板"))
        XCTAssertFalse(DrawingShortcutGuide.canvas.contains("Control+W"))
        XCTAssertFalse(DrawingShortcutGuide.canvas.contains("Ctrl+W"))
    }

    func testTextGuideMatchesNativeEditorLifecycleAndFontCommands() {
        XCTAssertTrue(DrawingShortcutGuide.text.contains("T"))
        XCTAssertTrue(DrawingShortcutGuide.text.contains("Shift+T"))
        XCTAssertTrue(DrawingShortcutGuide.text.contains("点击新位置"))
        XCTAssertTrue(DrawingShortcutGuide.text.contains("Command++ / Command+-"))
        XCTAssertTrue(DrawingShortcutGuide.text.contains("方向键、删除、选择和粘贴由 macOS 文本系统处理"))
        XCTAssertFalse(DrawingShortcutGuide.text.contains("左键退出"))
        XCTAssertFalse(DrawingShortcutGuide.text.contains("方向键调整字号"))
    }
}
