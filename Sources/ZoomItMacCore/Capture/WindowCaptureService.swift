import AppKit
@preconcurrency import ScreenCaptureKit

enum WindowCaptureError: LocalizedError, Equatable {
    case windowDisappeared(UInt32)
    case imageCreationFailed

    var errorDescription: String? {
        switch self {
        case .windowDisappeared(let windowID):
            AppLocalization.format(
                "capture.error.window.disappeared",
                defaultValue: "Window %u is no longer available.",
                windowID
            )
        case .imageCreationFailed:
            AppLocalization.string(
                "capture.error.window.image_creation_failed",
                defaultValue: "The window image could not be created."
            )
        }
    }
}

@MainActor
protocol WindowCaptureService {
    func candidatesFrontToBack() async throws -> [WindowSnipCandidate]
    func pointerLocation() -> CGPoint
    func capture(_ plan: WindowSnipRequestPlan) async throws -> CGImage
}

@MainActor
final class ScreenCaptureKitWindowCaptureService: WindowCaptureService {
    func candidatesFrontToBack() async throws -> [WindowSnipCandidate] {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        return content.windows.map { window in
            WindowSnipCandidate(
                windowID: window.windowID,
                ownerProcessID: window.owningApplication?.processID ?? -1,
                frame: window.frame,
                layer: window.windowLayer,
                isOnScreen: window.isOnScreen,
                scaleFactor: scaleFactor(forScreenCaptureFrame: window.frame)
            )
        }
    }

    func pointerLocation() -> CGPoint {
        MultiDisplayTargetingPolicy.screenCapturePoint(
            fromAppKitPoint: NSEvent.mouseLocation,
            displayFrames: NSScreen.screens.map(\.frame)
        )
    }

    func capture(_ plan: WindowSnipRequestPlan) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        guard let window = content.windows.first(where: { $0.windowID == plan.windowID }) else {
            throw WindowCaptureError.windowDisappeared(plan.windowID)
        }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        configuration.width = plan.pixelWidth
        configuration.height = plan.pixelHeight
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = !plan.includeShadow
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
        return image
    }

    private func scaleFactor(forScreenCaptureFrame frame: CGRect) -> CGFloat {
        let centerInAppKit = MultiDisplayTargetingPolicy.appKitPoint(
            fromScreenCapturePoint: CGPoint(x: frame.midX, y: frame.midY),
            displayFrames: NSScreen.screens.map(\.frame)
        )
        return NSScreen.screens.first(where: { $0.frame.contains(centerInAppKit) })?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 1
    }
}
