import CoreGraphics

struct MultiDisplayControlPresentationPlan: Equatable, Sendable {
    var displayID: UInt32
    var windowFrame: CGRect
    var excludesControlLayersFromCapture: Bool
}

enum MultiDisplayTargetingPolicy {
    static func targetDisplay(
        forAppKitPoint point: CGPoint,
        displays: [DisplayDescriptor]
    ) -> DisplayDescriptor? {
        displays.first(where: { $0.frame.contains(point) }) ?? displays.first
    }

    static func display(id: UInt32, in displays: [DisplayDescriptor]) -> DisplayDescriptor? {
        displays.first(where: { $0.id == id })
    }

    static func localTopLeftPoint(
        fromAppKitPoint point: CGPoint,
        in display: DisplayDescriptor
    ) -> CGPoint {
        CGPoint(
            x: point.x - display.frame.minX,
            y: display.frame.maxY - point.y
        )
    }

    static func pixelRect(
        forLocalTopLeftSelection selection: CGRect,
        in display: DisplayDescriptor
    ) -> CGRect {
        let localBounds = CGRect(origin: .zero, size: display.frame.size)
        let clipped = selection.standardized.intersection(localBounds)
        guard !clipped.isNull, !clipped.isEmpty else { return .zero }
        return CGRect(
            x: clipped.minX * display.scaleFactor,
            y: clipped.minY * display.scaleFactor,
            width: clipped.width * display.scaleFactor,
            height: clipped.height * display.scaleFactor
        ).integral
    }

    static func screenCapturePoint(
        fromAppKitPoint point: CGPoint,
        displayFrames: [CGRect]
    ) -> CGPoint {
        CGPoint(x: point.x, y: desktopTop(displayFrames) - point.y)
    }

    static func appKitPoint(
        fromScreenCapturePoint point: CGPoint,
        displayFrames: [CGRect]
    ) -> CGPoint {
        CGPoint(x: point.x, y: desktopTop(displayFrames) - point.y)
    }

    static func appKitRect(
        fromScreenCaptureRect rect: CGRect,
        displayFrames: [CGRect]
    ) -> CGRect {
        CGRect(
            x: rect.minX,
            y: desktopTop(displayFrames) - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    static func feedbackOrigin(
        nearAppKitPointer pointer: CGPoint,
        contentSize: CGSize,
        visibleFrame: CGRect,
        margin: CGFloat
    ) -> CGPoint {
        let right = pointer.x + 18
        let left = pointer.x - contentSize.width - margin
        let preferredX = right + contentSize.width <= visibleFrame.maxX - margin ? right : left

        let below = pointer.y - contentSize.height - 18
        let above = pointer.y + margin
        let preferredY = below >= visibleFrame.minY + margin ? below : above

        return CGPoint(
            x: min(
                max(preferredX, visibleFrame.minX + margin),
                visibleFrame.maxX - contentSize.width - margin
            ),
            y: min(
                max(preferredY, visibleFrame.minY + margin),
                visibleFrame.maxY - contentSize.height - margin
            )
        )
    }

    static func controlPresentationPlan(
        for display: DisplayDescriptor
    ) -> MultiDisplayControlPresentationPlan {
        MultiDisplayControlPresentationPlan(
            displayID: display.id,
            windowFrame: display.frame,
            excludesControlLayersFromCapture: true
        )
    }

    private static func desktopTop(_ displayFrames: [CGRect]) -> CGFloat {
        displayFrames.map(\.maxY).max() ?? 0
    }
}
