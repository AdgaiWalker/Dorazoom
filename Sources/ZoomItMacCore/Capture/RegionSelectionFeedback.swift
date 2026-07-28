import CoreGraphics

enum RegionSelectionResource: Equatable, Hashable, Sendable {
    case selectionWindow
    case crosshairCursor
    case sizeHUD
}

struct RegionSelectionLifecycle: Equatable, Sendable {
    private(set) var isActive: Bool
    private var anchorPoint: CGPoint?
    private(set) var currentSelection: CGRect
    private(set) var currentFeedback: RegionSelectionFeedback?

    static func active() -> RegionSelectionLifecycle {
        RegionSelectionLifecycle(isActive: true, anchorPoint: nil, currentSelection: .zero, currentFeedback: nil)
    }

    var activeResources: [RegionSelectionResource] {
        guard isActive else { return [] }
        var resources: [RegionSelectionResource] = [.selectionWindow, .crosshairCursor]
        if currentFeedback != nil {
            resources.append(.sizeHUD)
        }
        return resources
    }

    mutating func beginSelection(at point: CGPoint) {
        isActive = true
        anchorPoint = point
        currentSelection = .zero
        currentFeedback = nil
    }

    mutating func updateSelection(to point: CGPoint, scale: CGFloat, container: CGRect) {
        guard isActive, let anchorPoint else { return }
        currentSelection = CGRect(
            x: min(anchorPoint.x, point.x),
            y: min(anchorPoint.y, point.y),
            width: abs(point.x - anchorPoint.x),
            height: abs(point.y - anchorPoint.y)
        )
        currentFeedback = RegionSelectionFeedback.presentation(
            selection: currentSelection,
            scale: scale,
            container: container
        )
    }

    mutating func finish() -> CGRect? {
        let selection = currentSelection
        reset()
        return selection.width >= 3 && selection.height >= 3 ? selection : nil
    }

    mutating func cancel() -> CGRect? {
        reset()
        return nil
    }

    private mutating func reset() {
        isActive = false
        anchorPoint = nil
        currentSelection = .zero
        currentFeedback = nil
    }
}

struct RegionSelectionFeedback: Equatable, Sendable {
    let text: String
    let frame: CGRect

    static func presentation(selection: CGRect, scale: CGFloat, container: CGRect) -> RegionSelectionFeedback? {
        guard selection.width >= 3, selection.height >= 3 else { return nil }

        let pixelWidth = max(1, Int((selection.width * scale).rounded()))
        let pixelHeight = max(1, Int((selection.height * scale).rounded()))
        let text = "\(pixelWidth) × \(pixelHeight)"
        let estimatedTextSize = CGSize(width: CGFloat(text.count) * 7 + 16, height: 22)
        let x = clamp(selection.minX, lower: container.minX + 6, upper: container.maxX - estimatedTextSize.width - 6)
        let preferredY = selection.minY - estimatedTextSize.height - 6
        let fallbackY = selection.maxY + 6
        let y = preferredY >= container.minY + 6
            ? preferredY
            : clamp(fallbackY, lower: container.minY + 6, upper: container.maxY - estimatedTextSize.height - 6)

        return RegionSelectionFeedback(
            text: text,
            frame: CGRect(origin: CGPoint(x: x, y: y), size: estimatedTextSize)
        )
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), max(lower, upper))
    }
}
