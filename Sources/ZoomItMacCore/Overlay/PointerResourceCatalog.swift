import CoreGraphics

enum PointerResourceShape: Equatable, Sendable {
    case captureCrosshair
    case textScanCrosshair
    case recordFrameCrosshair
    case panoramaScrollCrosshair
}

enum PointerResourceTint: Equatable, Hashable, Sendable {
    case white
    case purple
    case red
    case blue
}

enum PointerScaleVariant: Equatable, Sendable {
    case oneX
    case twoX
}

struct PointerResource: Equatable, Sendable {
    var purpose: PointerPurpose
    var shape: PointerResourceShape
    var tint: PointerResourceTint
    var hotspot: CGPoint
    var scaleVariants: [PointerScaleVariant]
}

enum PointerResourceCatalog {
    static func resource(for purpose: PointerPurpose) -> PointerResource {
        PointerResource(
            purpose: purpose,
            shape: shape(for: purpose),
            tint: tint(for: purpose),
            hotspot: CGPoint(x: 12, y: 12),
            scaleVariants: [.oneX, .twoX]
        )
    }

    private static func shape(for purpose: PointerPurpose) -> PointerResourceShape {
        switch purpose {
        case .screenshot, .zoom, .draw:
            return .captureCrosshair
        case .ocr:
            return .textScanCrosshair
        case .recordingSelection:
            return .recordFrameCrosshair
        case .panoramaSelection:
            return .panoramaScrollCrosshair
        }
    }

    private static func tint(for purpose: PointerPurpose) -> PointerResourceTint {
        switch purpose {
        case .screenshot, .zoom, .draw:
            return .white
        case .ocr:
            return .purple
        case .recordingSelection:
            return .red
        case .panoramaSelection:
            return .blue
        }
    }
}
