import AppKit
import CoreGraphics
import CoreText

@MainActor
final class RecordingInputOverlayController {
    private var options = RecordingInputOverlayOptions(showClicks: false, showShortcuts: false)
    private var timeline = RecordingInputOverlayTimeline()
    private var globalMonitor: Any?
    private var recordingArea: CGRect = .zero

    var onPresentationStarted: (() -> Void)?

    func start(settings: AppSettings, recordingArea: CGRect) {
        stop()
        options = RecordingInputOverlayOptions(
            showClicks: settings.recordMouseClicks,
            showShortcuts: settings.recordShortcutKeys
        )
        self.recordingArea = recordingArea

        var mask: NSEvent.EventTypeMask = []
        if options.showClicks {
            mask.formUnion([.leftMouseDown, .rightMouseDown, .otherMouseDown])
        }
        if options.showShortcuts {
            mask.insert(.keyDown)
        }
        guard !mask.isEmpty, CGPreflightListenEventAccess() else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in
                self?.accept(event)
            }
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        globalMonitor = nil
        timeline = RecordingInputOverlayTimeline()
        onPresentationStarted = nil
    }

    func hasActivePresentation(at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        !timeline.activePresentations(at: uptime).isEmpty
    }

    func compositeIfActive(
        over image: CGImage,
        at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) -> CGImage? {
        let presentations = timeline.activePresentations(at: uptime)
        guard !presentations.isEmpty else { return nil }
        return RecordingInputOverlayRenderer.render(
            presentations: presentations,
            over: image,
            recordingArea: recordingArea
        )
    }

    private func accept(_ event: NSEvent) {
        guard let input = inputEvent(from: event),
              timeline.accept(input, options: options) else { return }
        onPresentationStarted?()
    }

    private func inputEvent(from event: NSEvent) -> RecordingInputEvent? {
        let authorized = CGPreflightListenEventAccess()
        let uptime = event.timestamp
        switch event.type {
        case .leftMouseDown:
            return .click(
                point: NSEvent.mouseLocation,
                button: .primary,
                uptime: uptime,
                isAuthorized: authorized
            )
        case .rightMouseDown:
            return .click(
                point: NSEvent.mouseLocation,
                button: .secondary,
                uptime: uptime,
                isAuthorized: authorized
            )
        case .otherMouseDown:
            return .click(
                point: NSEvent.mouseLocation,
                button: .other,
                uptime: uptime,
                isAuthorized: authorized
            )
        case .keyDown:
            guard let key = recordingKey(for: event) else { return nil }
            return .keyDown(
                key: key,
                modifiers: recordingModifiers(for: event.modifierFlags),
                uptime: uptime,
                isAuthorized: authorized
            )
        default:
            return nil
        }
    }

    private func recordingModifiers(for flags: NSEvent.ModifierFlags) -> RecordingInputModifiers {
        var modifiers: RecordingInputModifiers = []
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.command) { modifiers.insert(.command) }
        return modifiers
    }

    private func recordingKey(for event: NSEvent) -> RecordingInputKey? {
        let special: RecordingSpecialKey? = switch event.keyCode {
        case 36: .enter
        case 48: .tab
        case 51: .delete
        case 53: .escape
        case 123: .leftArrow
        case 124: .rightArrow
        case 125: .downArrow
        case 126: .upArrow
        default: nil
        }
        if let special { return .special(special) }
        guard let character = event.charactersIgnoringModifiers?.first,
              !character.isWhitespace && !character.isNewline else { return nil }
        return .character(String(character).uppercased())
    }
}

enum RecordingInputOverlayRenderer {
    static func render(
        presentations: [RecordingInputOverlayPresentation],
        over image: CGImage,
        recordingArea: CGRect
    ) -> CGImage {
        let width = image.width
        let height = image.height
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue
            | CGImageAlphaInfo.premultipliedFirst.rawValue
        guard recordingArea.width > 0, recordingArea.height > 0,
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo
              ) else { return image }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let scaleX = CGFloat(width) / recordingArea.width
        let scaleY = CGFloat(height) / recordingArea.height

        for presentation in presentations {
            switch presentation {
            case .clickHighlight(let globalPoint, _):
                guard recordingArea.contains(globalPoint) else { continue }
                let center = CGPoint(
                    x: (globalPoint.x - recordingArea.minX) * scaleX,
                    y: (globalPoint.y - recordingArea.minY) * scaleY
                )
                drawClick(at: center, scale: min(scaleX, scaleY), in: context)
            case .shortcut(let label, _):
                drawShortcut(
                    label,
                    imageSize: CGSize(width: width, height: height),
                    scale: min(scaleX, scaleY),
                    in: context
                )
            }
        }
        return context.makeImage() ?? image
    }

    private static func drawClick(at center: CGPoint, scale: CGFloat, in context: CGContext) {
        let radius = max(14, 18 * scale)
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.setFillColor(NSColor.systemRed.withAlphaComponent(0.22).cgColor)
        context.fillEllipse(in: rect)
        context.setStrokeColor(NSColor.systemRed.withAlphaComponent(0.95).cgColor)
        context.setLineWidth(max(3, 3 * scale))
        context.strokeEllipse(in: rect.insetBy(dx: 2, dy: 2))
    }

    private static func drawShortcut(
        _ label: String,
        imageSize: CGSize,
        scale: CGFloat,
        in context: CGContext
    ) {
        let fontSize = max(18, 22 * scale)
        let font = CTFontCreateWithName(".AppleSystemUIFont" as CFString, fontSize, nil)
        let attributed = NSAttributedString(
            string: label,
            attributes: [
                kCTFontAttributeName as NSAttributedString.Key: font,
                kCTForegroundColorAttributeName as NSAttributedString.Key: NSColor.white.cgColor
            ]
        )
        let line = CTLineCreateWithAttributedString(attributed)
        let textWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        let horizontalPadding = 18 * scale
        let capsuleHeight = 44 * scale
        let capsuleWidth = textWidth + horizontalPadding * 2
        let rect = CGRect(
            x: (imageSize.width - capsuleWidth) / 2,
            y: 24 * scale,
            width: capsuleWidth,
            height: capsuleHeight
        )
        context.addPath(CGPath(
            roundedRect: rect,
            cornerWidth: capsuleHeight / 2,
            cornerHeight: capsuleHeight / 2,
            transform: nil
        ))
        context.setFillColor(NSColor.black.withAlphaComponent(0.78).cgColor)
        context.fillPath()
        context.textPosition = CGPoint(
            x: rect.minX + horizontalPadding,
            y: rect.midY - fontSize * 0.36
        )
        CTLineDraw(line, context)
    }
}
