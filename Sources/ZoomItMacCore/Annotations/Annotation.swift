import AppKit

enum AnnotationTool: Equatable, Sendable {
    case pen
    case line
    case rectangle
    case ellipse
    case arrow
    case text
    case highlighter
    case blur
    case redact
    case numberedCallout
}

enum AnnotationColor: String, CaseIterable, Equatable, Sendable {
    case red
    case green
    case blue
    case yellow
    case orange
    case pink
    case white
    case black

    var nsColor: NSColor {
        switch self {
        case .red: .systemRed
        case .green: .systemGreen
        case .blue: .systemBlue
        case .yellow: .systemYellow
        case .orange: .systemOrange
        case .pink: .systemPink
        case .white: .white
        case .black: .black
        }
    }

    var displayName: String {
        switch self {
        case .red: AppLocalization.string("color.red", defaultValue: "Red")
        case .green: AppLocalization.string("color.green", defaultValue: "Green")
        case .blue: AppLocalization.string("color.blue", defaultValue: "Blue")
        case .yellow: AppLocalization.string("color.yellow", defaultValue: "Yellow")
        case .orange: AppLocalization.string("color.orange", defaultValue: "Orange")
        case .pink: AppLocalization.string("color.pink", defaultValue: "Pink")
        case .white: AppLocalization.string("color.white", defaultValue: "White")
        case .black: AppLocalization.string("color.black", defaultValue: "Black")
        }
    }
}

struct AnnotationStyle: Equatable {
    var color: AnnotationColor
    var rootWidth: CGFloat
    var alpha: CGFloat

    /// Translucency used for highlighting (Shift+color and the highlighter
    /// tool), matching Windows ZoomIt's g_AlphaBlend (0x80 = 50%).
    static let highlightAlpha: CGFloat = 0.5

    static let `default` = AnnotationStyle(color: .red, rootWidth: 5, alpha: 1)
}

struct Annotation: Equatable {
    var tool: AnnotationTool
    var points: [CGPoint]
    var style: AnnotationStyle
    var text: String = ""
    var fontSize: CGFloat = 36
    var fontName: String = ""
    var rightAligned: Bool = false
    var calloutNumber: Int? = nil
}
