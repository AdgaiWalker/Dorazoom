import AppKit
import XCTest
@testable import ZoomItMacCore

@MainActor
final class AppleNativeTextEditingTests: XCTestCase {
    func testNativeTextFontShortcutsUseMacEditingCommandsWithoutConsumingOtherCommands() {
        XCTAssertEqual(
            CanvasTextEditingInputPolicy.fontSizeAdjustment(
                charactersIgnoringModifiers: "=",
                modifiers: [.command]
            ),
            .increase
        )
        XCTAssertEqual(
            CanvasTextEditingInputPolicy.fontSizeAdjustment(
                charactersIgnoringModifiers: "-",
                modifiers: [.command]
            ),
            .decrease
        )
        XCTAssertNil(CanvasTextEditingInputPolicy.fontSizeAdjustment(
            charactersIgnoringModifiers: "v",
            modifiers: [.command]
        ))
        XCTAssertEqual(CanvasTextEditingInputPolicy.fontSizeAdjustment(scrollingDeltaY: 2), .increase)
        XCTAssertEqual(CanvasTextEditingInputPolicy.fontSizeAdjustment(scrollingDeltaY: -2), .decrease)
        XCTAssertNil(CanvasTextEditingInputPolicy.fontSizeAdjustment(scrollingDeltaY: 0))
    }

    func testMarkedTextIsReplacedBeforeCommittedTextBecomesTheDraft() {
        let host = NSView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        var observedText: [String] = []
        let session = CanvasTextEditingSession(
            onTextChange: { observedText.append($0) },
            onExitRequested: {}
        )

        session.begin(
            in: host,
            frame: CGRect(x: 120, y: 120, width: 500, height: 200),
            font: .systemFont(ofSize: 20),
            alignment: .left
        )

        session.inputClient.setMarkedText(
            "ni",
            selectedRange: NSRange(location: 2, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0)
        )
        XCTAssertTrue(session.inputClient.hasMarkedText())
        XCTAssertEqual(session.text, "ni")

        session.inputClient.setMarkedText(
            "你好",
            selectedRange: NSRange(location: 2, length: 0),
            replacementRange: session.inputClient.markedRange()
        )
        session.inputClient.insertText(
            "你好",
            replacementRange: session.inputClient.markedRange()
        )

        XCTAssertFalse(session.inputClient.hasMarkedText())
        XCTAssertEqual(session.text, "你好")
        XCTAssertEqual(observedText.last, "你好")
    }

    func testEndingSessionRemovesTheNativeEditorAndKeepsCommittedDraft() {
        let host = NSView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        var committedText: String?
        let session = CanvasTextEditingSession(
            onTextChange: { _ in },
            onExitRequested: {}
        )

        session.begin(
            in: host,
            frame: CGRect(x: 120, y: 120, width: 500, height: 200),
            font: .systemFont(ofSize: 20),
            alignment: .left
        )
        session.inputClient.insertText(
            "Hello 世界",
            replacementRange: NSRange(location: NSNotFound, length: 0)
        )
        committedText = session.finish()

        XCTAssertEqual(committedText, "Hello 世界")
        XCTAssertFalse(session.isActive)
        XCTAssertNil(session.inputClient.superview)
    }

    func testEscapeRequestsExitOnlyWhenThereIsNoActiveComposition() throws {
        let host = NSView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        var exitRequestCount = 0
        let session = CanvasTextEditingSession(
            onTextChange: { _ in },
            onExitRequested: { exitRequestCount += 1 }
        )
        session.begin(
            in: host,
            frame: CGRect(x: 120, y: 120, width: 500, height: 200),
            font: .systemFont(ofSize: 20),
            alignment: .left
        )
        let escape = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\u{1b}",
            charactersIgnoringModifiers: "\u{1b}",
            isARepeat: false,
            keyCode: 53
        ))

        session.inputClient.setMarkedText(
            "zhong",
            selectedRange: NSRange(location: 5, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0)
        )
        session.inputClient.keyDown(with: escape)
        XCTAssertEqual(exitRequestCount, 0)

        session.inputClient.unmarkText()
        session.inputClient.keyDown(with: escape)
        XCTAssertEqual(exitRequestCount, 1)
    }

    func testAnnotationDraftReplacementDoesNotAppendCompositionUpdates() {
        let controller = AnnotationController()
        controller.setInsertionPoint(CGPoint(x: 20, y: 30))
        controller.beginTypingSession(rightAligned: false)

        controller.replaceTypingText("ni")
        controller.replaceTypingText("你好")

        XCTAssertEqual(controller.annotationSnapshot.count, 1)
        XCTAssertEqual(controller.annotationSnapshot.first?.text, "你好")
        XCTAssertEqual(controller.annotationSnapshot.first?.points, [CGPoint(x: 20, y: 30)])
    }

    func testNativeEditorOwnsOnScreenDraftWhileCaptureCanRenderPlainAnnotation() {
        let controller = AnnotationController()
        controller.setInsertionPoint(CGPoint(x: 20, y: 30))
        controller.beginTypingSession(rightAligned: false)
        controller.replaceTypingText("候选文字")

        controller.isTypingDraftPresentedByNativeEditor = true
        XCTAssertTrue(controller.renderPlanSnapshot.isEmpty)

        controller.isTypingDraftPresentedByNativeEditor = false
        XCTAssertEqual(controller.renderPlanSnapshot.count, 1)
        XCTAssertEqual(controller.renderPlanSnapshot.first?.text, "候选文字")
    }

    func testEnteringTypingModeInstallsNativeEditorAndLeavingRemovesIt() throws {
        let annotationController = AnnotationController()
        let canvas = try makeCanvas(annotationController: annotationController)
        let window = NSWindow(
            contentRect: canvas.bounds,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = canvas

        canvas.interactionMode = .typing

        XCTAssertEqual(canvas.subviews.compactMap { $0 as? NSTextView }.count, 1)
        XCTAssertTrue(window.firstResponder is NSTextView)

        canvas.interactionMode = .staticZoom

        XCTAssertTrue(canvas.subviews.compactMap { $0 as? NSTextView }.isEmpty)
        XCTAssertFalse(window.firstResponder is NSTextView)
    }

    func testRepeatedTypingStateUpdateDoesNotResetActiveComposition() throws {
        let annotationController = AnnotationController()
        let canvas = try makeCanvas(annotationController: annotationController)
        let window = NSWindow(
            contentRect: canvas.bounds,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = canvas
        canvas.interactionMode = .typing
        let editor = try XCTUnwrap(canvas.subviews.compactMap { $0 as? NSTextView }.first)
        editor.setMarkedText(
            "zhong",
            selectedRange: NSRange(location: 5, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0)
        )

        canvas.interactionMode = .typing

        XCTAssertEqual(editor.string, "zhong")
        XCTAssertTrue(editor.hasMarkedText())
    }

    func testNativeEditorCompositionUpdatesOneCanvasAnnotation() throws {
        let annotationController = AnnotationController()
        let canvas = try makeCanvas(annotationController: annotationController)
        let window = NSWindow(
            contentRect: canvas.bounds,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = canvas
        canvas.interactionMode = .typing
        let editor = try XCTUnwrap(canvas.subviews.compactMap { $0 as? NSTextView }.first)

        editor.setMarkedText(
            "zhong",
            selectedRange: NSRange(location: 5, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0)
        )
        editor.setMarkedText(
            "中文",
            selectedRange: NSRange(location: 2, length: 0),
            replacementRange: editor.markedRange()
        )
        editor.insertText("中文", replacementRange: editor.markedRange())

        XCTAssertEqual(annotationController.annotationSnapshot.map(\.text), ["中文"])
    }

    func testClickingANewLocationCommitsPreviousTextAndStartsAFreshDraft() throws {
        let annotationController = AnnotationController()
        let canvas = try makeCanvas(annotationController: annotationController)
        let window = NSWindow(
            contentRect: canvas.bounds,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = canvas
        canvas.interactionMode = .typing
        let editor = try XCTUnwrap(canvas.subviews.compactMap { $0 as? NSTextView }.first)
        editor.insertText("第一段", replacementRange: NSRange(location: NSNotFound, length: 0))

        let click = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: CGPoint(x: 500, y: 300),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ))
        canvas.mouseDown(with: click)

        XCTAssertEqual(editor.string, "")
        editor.insertText("第二段", replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertEqual(annotationController.annotationSnapshot.map(\.text), ["第一段", "第二段"])
    }

    private func makeCanvas(annotationController: AnnotationController) throws -> ZoomCanvasView {
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: 800,
            height: 600,
            bitsPerComponent: 8,
            bytesPerRow: 800 * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let image = try XCTUnwrap(context.makeImage())
        let display = DisplayDescriptor(
            id: 1,
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            scaleFactor: 1
        )
        let frame = CapturedFrame(
            image: image,
            display: display,
            pixelSize: CGSize(width: 800, height: 600),
            timestamp: Date(timeIntervalSince1970: 0)
        )
        let viewportController = ZoomViewportController()
        viewportController.configure(for: frame, initialZoom: 2)
        return ZoomCanvasView(
            frame: display.frame,
            capturedFrame: frame,
            viewportController: viewportController,
            annotationController: annotationController,
            smoothImage: true,
            commandSink: { _ in }
        )
    }
}
