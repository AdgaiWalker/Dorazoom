import CoreGraphics

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

enum RecordingCaptureRequestPlanError: Error, Equatable {
    case displayNotFound(UInt32)
    case noDisplayAvailable
    case windowNotFound(UInt32)
    case windowDisplayNotFound(windowID: UInt32, displayID: UInt32)
    case invalidRegion(CGRect)
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
