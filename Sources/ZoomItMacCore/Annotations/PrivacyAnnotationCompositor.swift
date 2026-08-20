import AppKit
import CoreImage

@MainActor
enum PrivacyAnnotationCompositor {
    private static let imageContext = CIContext()

    static func composite(
        source: CGImage,
        operations: [AnnotationRenderOperation],
        contentToImageTransform: CGAffineTransform
    ) -> CGImage? {
        let privacyOperations = operations.filter(\.isPrivacy)
        guard !privacyOperations.isEmpty else { return source }

        let width = source.width
        let height = source.height
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(source, in: bounds)
        let maximumBlurRadius = privacyOperations
            .filter { $0.kind == .blurFreehand }
            .map { max(4, transformedWidth($0.style.rootWidth, by: contentToImageTransform) * 0.9) }
            .max()
        let blurred = maximumBlurRadius.flatMap { blurredImage(source, radius: $0) }

        for operation in privacyOperations {
            switch operation.kind {
            case .blurFreehand:
                guard let blurred else { continue }
                clipBrush(operation, in: context, imageHeight: CGFloat(height), transform: contentToImageTransform)
                context.draw(blurred, in: bounds)
                context.restoreGState()
            case .redactionFill:
                fillRedaction(operation, in: context, imageHeight: CGFloat(height), transform: contentToImageTransform)
            default:
                break
            }
        }
        return context.makeImage()
    }

    private static func blurredImage(_ source: CGImage, radius: CGFloat) -> CGImage? {
        let input = CIImage(cgImage: source)
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return nil }
        filter.setValue(input.clampedToExtent(), forKey: kCIInputImageKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        guard let output = filter.outputImage?.cropped(to: input.extent) else { return nil }
        return imageContext.createCGImage(output, from: input.extent)
    }

    private static func clipBrush(
        _ operation: AnnotationRenderOperation,
        in context: CGContext,
        imageHeight: CGFloat,
        transform: CGAffineTransform
    ) {
        guard let first = operation.points.first else { return }
        context.saveGState()
        let path = CGMutablePath()
        path.move(to: drawingPoint(first, imageHeight: imageHeight, transform: transform))
        for point in operation.points.dropFirst() {
            path.addLine(to: drawingPoint(point, imageHeight: imageHeight, transform: transform))
        }
        context.addPath(path)
        context.setLineWidth(transformedWidth(operation.style.rootWidth, by: transform))
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.replacePathWithStrokedPath()
        context.clip()
    }

    private static func fillRedaction(
        _ operation: AnnotationRenderOperation,
        in context: CGContext,
        imageHeight: CGFloat,
        transform: CGAffineTransform
    ) {
        guard let first = operation.points.first, let last = operation.points.last else { return }
        let sourceRect = CGRect(
            origin: first,
            size: CGSize(width: last.x - first.x, height: last.y - first.y)
        ).standardized
        let corners = [
            CGPoint(x: sourceRect.minX, y: sourceRect.minY),
            CGPoint(x: sourceRect.maxX, y: sourceRect.minY),
            CGPoint(x: sourceRect.maxX, y: sourceRect.maxY),
            CGPoint(x: sourceRect.minX, y: sourceRect.maxY)
        ].map { drawingPoint($0, imageHeight: imageHeight, transform: transform) }
        guard let firstCorner = corners.first else { return }
        let path = CGMutablePath()
        path.move(to: firstCorner)
        for corner in corners.dropFirst() {
            path.addLine(to: corner)
        }
        path.closeSubpath()
        context.saveGState()
        context.setAlpha(1)
        context.setFillColor(operation.style.color.nsColor.cgColor)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()
    }

    private static func drawingPoint(
        _ point: CGPoint,
        imageHeight: CGFloat,
        transform: CGAffineTransform
    ) -> CGPoint {
        let transformed = point.applying(transform)
        return CGPoint(x: transformed.x, y: imageHeight - transformed.y)
    }

    private static func transformedWidth(_ width: CGFloat, by transform: CGAffineTransform) -> CGFloat {
        let horizontalScale = hypot(transform.a, transform.b)
        let verticalScale = hypot(transform.c, transform.d)
        return max(1, width * (horizontalScale + verticalScale) / 2)
    }
}
