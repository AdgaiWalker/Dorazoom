import CoreGraphics
import Foundation

struct RecordingInputOverlayOptions: Equatable, Sendable {
    var showClicks: Bool
    var showShortcuts: Bool
}

enum RecordingMouseButton: Equatable, Sendable {
    case primary
    case secondary
    case other
}

struct RecordingInputModifiers: OptionSet, Equatable, Sendable {
    let rawValue: UInt8

    static let control = RecordingInputModifiers(rawValue: 1 << 0)
    static let option = RecordingInputModifiers(rawValue: 1 << 1)
    static let shift = RecordingInputModifiers(rawValue: 1 << 2)
    static let command = RecordingInputModifiers(rawValue: 1 << 3)
}

enum RecordingSpecialKey: String, Equatable, Sendable {
    case tab = "Tab"
    case escape = "Escape"
    case enter = "Return"
    case delete = "Delete"
    case leftArrow = "←"
    case rightArrow = "→"
    case downArrow = "↓"
    case upArrow = "↑"

    var localizedLabel: String {
        switch self {
        case .tab:
            AppLocalization.string(
                "recording.input_overlay.key.tab",
                defaultValue: "Tab"
            )
        case .escape:
            AppLocalization.string(
                "recording.input_overlay.key.escape",
                defaultValue: "Escape"
            )
        case .enter:
            AppLocalization.string(
                "recording.input_overlay.key.return",
                defaultValue: "Return"
            )
        case .delete:
            AppLocalization.string(
                "recording.input_overlay.key.delete",
                defaultValue: "Delete"
            )
        case .leftArrow, .rightArrow, .downArrow, .upArrow:
            rawValue
        }
    }
}

enum RecordingInputKey: Equatable, Sendable {
    case character(String)
    case special(RecordingSpecialKey)
}

enum RecordingInputEvent: Equatable, Sendable {
    case click(
        point: CGPoint,
        button: RecordingMouseButton,
        uptime: TimeInterval,
        isAuthorized: Bool
    )
    case keyDown(
        key: RecordingInputKey,
        modifiers: RecordingInputModifiers,
        uptime: TimeInterval,
        isAuthorized: Bool
    )

    var uptime: TimeInterval {
        switch self {
        case .click(_, _, let uptime, _), .keyDown(_, _, let uptime, _):
            return uptime
        }
    }
}

enum RecordingInputOverlayPresentation: Equatable, Sendable {
    case clickHighlight(center: CGPoint, duration: TimeInterval)
    case shortcut(label: String, duration: TimeInterval)

    var duration: TimeInterval {
        switch self {
        case .clickHighlight(_, let duration), .shortcut(_, let duration):
            return duration
        }
    }
}

enum RecordingInputOverlayPolicy {
    static let clickDuration: TimeInterval = 0.55
    static let shortcutDuration: TimeInterval = 1.2

    static func presentation(
        for event: RecordingInputEvent,
        options: RecordingInputOverlayOptions
    ) -> RecordingInputOverlayPresentation? {
        switch event {
        case .click(let point, _, _, let isAuthorized):
            guard options.showClicks, isAuthorized else { return nil }
            return .clickHighlight(center: point, duration: clickDuration)

        case .keyDown(let key, let modifiers, _, let isAuthorized):
            guard options.showShortcuts, isAuthorized,
                  isSafeShortcut(key: key, modifiers: modifiers) else { return nil }
            return .shortcut(
                label: shortcutLabel(key: key, modifiers: modifiers),
                duration: shortcutDuration
            )
        }
    }

    private static func isSafeShortcut(
        key: RecordingInputKey,
        modifiers: RecordingInputModifiers
    ) -> Bool {
        let actionModifiers: RecordingInputModifiers = [.control, .option, .command]
        guard !modifiers.intersection(actionModifiers).isEmpty else { return false }

        switch key {
        case .character:
            // Option-only character input can produce ordinary text. Requiring
            // Command or Control prevents passwords and chat text from entering
            // the recording overlay while preserving application shortcuts.
            return modifiers.contains(.command) || modifiers.contains(.control)
        case .special:
            return true
        }
    }

    private static func shortcutLabel(
        key: RecordingInputKey,
        modifiers: RecordingInputModifiers
    ) -> String {
        var label = ""
        if modifiers.contains(.control) { label += "⌃" }
        if modifiers.contains(.option) { label += "⌥" }
        if modifiers.contains(.shift) { label += "⇧" }
        if modifiers.contains(.command) { label += "⌘" }
        switch key {
        case .character(let character):
            label += character.uppercased()
        case .special(let key):
            label += key.localizedLabel
        }
        return label
    }
}

struct RecordingInputOverlayTimeline: Equatable, Sendable {
    private struct Entry: Equatable, Sendable {
        var presentation: RecordingInputOverlayPresentation
        var expiresAt: TimeInterval
    }

    private var entries: [Entry] = []

    @discardableResult
    mutating func accept(
        _ event: RecordingInputEvent,
        options: RecordingInputOverlayOptions
    ) -> Bool {
        guard let presentation = RecordingInputOverlayPolicy.presentation(
            for: event,
            options: options
        ) else { return false }
        entries.append(Entry(
            presentation: presentation,
            expiresAt: event.uptime + presentation.duration
        ))
        return true
    }

    mutating func activePresentations(at uptime: TimeInterval) -> [RecordingInputOverlayPresentation] {
        entries.removeAll { $0.expiresAt <= uptime }
        return entries.map(\.presentation)
    }
}
