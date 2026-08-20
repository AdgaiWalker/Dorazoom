import XCTest
@testable import ZoomItMacCore

final class AppleRecordingInputOverlayTests: XCTestCase {
    func testAuthorizedClickProducesShortLivedHighlightOnlyWhenEnabled() {
        let event = RecordingInputEvent.click(
            point: CGPoint(x: 120, y: 80),
            button: .primary,
            uptime: 10,
            isAuthorized: true
        )

        XCTAssertEqual(
            RecordingInputOverlayPolicy.presentation(
                for: event,
                options: .init(showClicks: true, showShortcuts: false)
            ),
            .clickHighlight(center: CGPoint(x: 120, y: 80), duration: 0.55)
        )
        XCTAssertNil(RecordingInputOverlayPolicy.presentation(
            for: event,
            options: .init(showClicks: false, showShortcuts: true)
        ))
    }

    func testShortcutPolicyShowsSafeModifiedCommandsAndFiltersTextLikeInput() {
        let options = RecordingInputOverlayOptions(showClicks: false, showShortcuts: true)
        let safe = RecordingInputEvent.keyDown(
            key: .character("K"),
            modifiers: [.control, .option, .shift, .command],
            uptime: 20,
            isAuthorized: true
        )
        let safeSpecial = RecordingInputEvent.keyDown(
            key: .special(.tab),
            modifiers: [.option],
            uptime: 21,
            isAuthorized: true
        )

        XCTAssertEqual(
            RecordingInputOverlayPolicy.presentation(for: safe, options: options),
            .shortcut(label: "⌃⌥⇧⌘K", duration: 1.2)
        )
        XCTAssertEqual(
            RecordingInputOverlayPolicy.presentation(for: safeSpecial, options: options),
            .shortcut(label: "⌥Tab", duration: 1.2)
        )

        for unsafe in [
            RecordingInputEvent.keyDown(key: .character("P"), modifiers: [], uptime: 22, isAuthorized: true),
            RecordingInputEvent.keyDown(key: .character("P"), modifiers: [.shift], uptime: 23, isAuthorized: true),
            RecordingInputEvent.keyDown(key: .character("P"), modifiers: [.option], uptime: 24, isAuthorized: true)
        ] {
            XCTAssertNil(RecordingInputOverlayPolicy.presentation(for: unsafe, options: options))
        }
    }

    func testUnauthorizedEventsNeverEnterThePresentationTimeline() {
        let options = RecordingInputOverlayOptions(showClicks: true, showShortcuts: true)
        let events: [RecordingInputEvent] = [
            .click(point: .zero, button: .primary, uptime: 1, isAuthorized: false),
            .keyDown(key: .character("V"), modifiers: [.command], uptime: 2, isAuthorized: false)
        ]

        XCTAssertTrue(events.allSatisfy {
            RecordingInputOverlayPolicy.presentation(for: $0, options: options) == nil
        })
    }

    func testTimelineExpiresClickAndShortcutPresentationsDeterministically() {
        var timeline = RecordingInputOverlayTimeline()
        timeline.accept(
            .click(point: CGPoint(x: 20, y: 30), button: .secondary, uptime: 100, isAuthorized: true),
            options: .init(showClicks: true, showShortcuts: true)
        )
        timeline.accept(
            .keyDown(key: .special(.escape), modifiers: [.control], uptime: 100.1, isAuthorized: true),
            options: .init(showClicks: true, showShortcuts: true)
        )

        XCTAssertEqual(timeline.activePresentations(at: 100.2).count, 2)
        XCTAssertEqual(timeline.activePresentations(at: 100.7), [
            .shortcut(label: "⌃Escape", duration: 1.2)
        ])
        XCTAssertEqual(timeline.activePresentations(at: 101.31), [])
    }

    func testRecordingInputOverlaysAreOptInSettings() {
        XCTAssertFalse(AppSettings.defaults.recordMouseClicks)
        XCTAssertFalse(AppSettings.defaults.recordShortcutKeys)
    }

    func testClickHighlightIsCompositedIntoFinalRecordingPixels() throws {
        let source = try solidImage(width: 80, height: 80)
        let output = RecordingInputOverlayRenderer.render(
            presentations: [
                .clickHighlight(center: CGPoint(x: 40, y: 40), duration: 0.55)
            ],
            over: source,
            recordingArea: CGRect(x: 0, y: 0, width: 80, height: 80)
        )

        XCTAssertNotEqual(try pixelBytes(output, x: 40, y: 40), [0, 0, 0, 255])
        XCTAssertEqual(try pixelBytes(output, x: 0, y: 0), [0, 0, 0, 255])
    }

    private func solidImage(width: Int, height: Int) throws -> CGImage {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw OverlayFixtureError.context }
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else { throw OverlayFixtureError.image }
        return image
    }

    private func pixelBytes(_ image: CGImage, x: Int, y: Int) throws -> [UInt8] {
        var storage = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let madeContext = storage.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard madeContext else { throw OverlayFixtureError.context }
        let index = ((image.height - 1 - y) * image.width + x) * 4
        return Array(storage[index..<(index + 4)])
    }
}

private enum OverlayFixtureError: Error {
    case context
    case image
}
