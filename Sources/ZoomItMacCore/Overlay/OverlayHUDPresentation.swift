import CoreGraphics

struct OverlayHUD: Equatable, Sendable {
    let text: String
    let frame: CGRect
}

enum OverlayHUDPresentation {
    static func presentation(interactionMode: AppMode, zoomFactor: CGFloat, container: CGRect) -> OverlayHUD? {
        guard interactionMode == .staticZoom else { return nil }

        let text = "Zoom \(formattedZoomFactor(zoomFactor))×"
        let estimatedSize = CGSize(width: CGFloat(text.count) * 8 + 20, height: 24)
        let size = CGSize(
            width: min(estimatedSize.width, max(1, container.width - 12)),
            height: min(estimatedSize.height, max(1, container.height - 6))
        )
        let origin = CGPoint(
            x: clamp(container.maxX - size.width - 12, lower: container.minX + 6, upper: container.maxX - size.width),
            y: clamp(container.minY + 12, lower: container.minY, upper: container.maxY - size.height)
        )
        return OverlayHUD(text: text, frame: CGRect(origin: origin, size: size))
    }

    private static func formattedZoomFactor(_ zoomFactor: CGFloat) -> String {
        let rounded = (zoomFactor * 10).rounded() / 10
        if rounded.rounded() == rounded {
            return "\(Int(rounded))"
        }
        return String(format: "%.1f", Double(rounded))
    }

    static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), max(lower, upper))
    }
}
