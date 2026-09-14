import CoreGraphics
import Foundation

enum RecordingCaptureRequestFilter: Equatable, Sendable {
    case display(displayID: UInt32, excludingWindowIDs: [UInt32])
    case window(windowID: UInt32)
}

struct RecordingWindowDescriptor: Equatable, Sendable {
    var windowID: UInt32
    var displayID: UInt32
    var frameInDisplay: CGRect
}

struct RecordingCaptureRequestPlan: Equatable, Sendable {
    var target: RecordingTarget
    var filter: RecordingCaptureRequestFilter
    var displayID: UInt32
    var windowID: UInt32?
    var sourceRect: CGRect?
    var pixelWidth: Int
    var pixelHeight: Int
    var showsCursor: Bool
}

enum RecordingCaptureRequestPlanError: LocalizedError, Equatable {
    case displayNotFound(UInt32)
    case noDisplayAvailable
    case windowNotFound(UInt32)
    case windowDisplayNotFound(windowID: UInt32, displayID: UInt32)
    case invalidRegion(CGRect)

    var errorDescription: String? {
        switch self {
        case .displayNotFound(let displayID):
            AppLocalization.format(
                "recording.error.plan.display_not_found",
                defaultValue: "Display %u is no longer available.",
                displayID
            )
        case .noDisplayAvailable:
            AppLocalization.string(
                "recording.error.plan.no_display_available",
                defaultValue: "No display is available for recording."
            )
        case .windowNotFound(let windowID):
            AppLocalization.format(
                "recording.error.plan.window_not_found",
                defaultValue: "Window %u is no longer available for recording.",
                windowID
            )
        case .windowDisplayNotFound(let windowID, let displayID):
            AppLocalization.format(
                "recording.error.plan.window_display_not_found",
                defaultValue: "Window %u belongs to display %u, which is no longer available.",
                windowID,
                displayID
            )
        case .invalidRegion(let region):
            AppLocalization.format(
                "recording.error.plan.invalid_region",
                defaultValue: "The selected recording region is invalid (%.0f × %.0f).",
                Double(region.width),
                Double(region.height)
            )
        }
    }
}

enum RecordingCaptureRequestPlanner {
    static func plan(
        target: RecordingTarget,
        displays: [DisplayDescriptor],
        windows: [RecordingWindowDescriptor],
        excludingWindowIDs: [UInt32] = []
    ) throws -> RecordingCaptureRequestPlan {
        switch target {
        case .fullScreen(let displayID):
            let display = try display(withID: displayID, in: displays)
            let sourceRect = CGRect(origin: .zero, size: display.frame.size)
            return plan(
                target: target,
                filter: .display(displayID: displayID, excludingWindowIDs: excludingWindowIDs),
                display: display,
                windowID: nil,
                sourceRect: sourceRect
            )
        case .region(let x, let y, let width, let height):
            guard width > 0, height > 0 else {
                throw RecordingCaptureRequestPlanError.invalidRegion(
                    CGRect(x: x, y: y, width: width, height: height)
                )
            }
            guard let display = displays.first else {
                throw RecordingCaptureRequestPlanError.noDisplayAvailable
            }
            let sourceRect = CGRect(x: x, y: y, width: width, height: height)
            return plan(
                target: target,
                filter: .display(displayID: display.id, excludingWindowIDs: excludingWindowIDs),
                display: display,
                windowID: nil,
                sourceRect: sourceRect
            )
        case .window(let windowID):
            guard let window = windows.first(where: { $0.windowID == windowID }) else {
                throw RecordingCaptureRequestPlanError.windowNotFound(windowID)
            }
            guard let display = displays.first(where: { $0.id == window.displayID }) else {
                throw RecordingCaptureRequestPlanError.windowDisplayNotFound(
                    windowID: windowID,
                    displayID: window.displayID
                )
            }
            return plan(
                target: target,
                filter: .window(windowID: windowID),
                display: display,
                windowID: windowID,
                sourceRect: nil,
                sizeInPoints: window.frameInDisplay.size
            )
        }
    }

    private static func plan(
        target: RecordingTarget,
        filter: RecordingCaptureRequestFilter,
        display: DisplayDescriptor,
        windowID: UInt32?,
        sourceRect: CGRect,
        showsCursor: Bool = true
    ) -> RecordingCaptureRequestPlan {
        plan(
            target: target,
            filter: filter,
            display: display,
            windowID: windowID,
            sourceRect: sourceRect,
            sizeInPoints: sourceRect.size,
            showsCursor: showsCursor
        )
    }

    private static func plan(
        target: RecordingTarget,
        filter: RecordingCaptureRequestFilter,
        display: DisplayDescriptor,
        windowID: UInt32?,
        sourceRect: CGRect?,
        sizeInPoints: CGSize,
        showsCursor: Bool = true
    ) -> RecordingCaptureRequestPlan {
        RecordingCaptureRequestPlan(
            target: target,
            filter: filter,
            displayID: display.id,
            windowID: windowID,
            sourceRect: sourceRect,
            pixelWidth: Int(sizeInPoints.width * display.scaleFactor),
            pixelHeight: Int(sizeInPoints.height * display.scaleFactor),
            showsCursor: showsCursor
        )
    }

    private static func display(withID displayID: UInt32, in displays: [DisplayDescriptor]) throws -> DisplayDescriptor {
        guard let display = displays.first(where: { $0.id == displayID }) else {
            throw RecordingCaptureRequestPlanError.displayNotFound(displayID)
        }
        return display
    }
}
