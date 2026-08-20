import CoreGraphics

struct WindowSnipCandidate: Equatable, Sendable {
    var windowID: UInt32
    var ownerProcessID: Int32
    var frame: CGRect
    var layer: Int
    var isOnScreen: Bool
    var scaleFactor: CGFloat
}

struct WindowSnipRequestPlan: Equatable, Sendable {
    var windowID: UInt32
    var includeShadow: Bool
    var pixelWidth: Int
    var pixelHeight: Int
    var outputOperations: [SnipExportOperation]
}

enum WindowSnipSessionState: Equatable, Sendable {
    case idle
    case targeted(windowID: UInt32)
}

enum WindowSnipCaptureResult: Equatable, Sendable {
    case copied
    case cancelled
    case windowDisappeared
    case failed
}

struct WindowSnipSession: Equatable, Sendable {
    private(set) var state: WindowSnipSessionState = .idle

    mutating func begin(
        pointer: CGPoint,
        candidatesFrontToBack: [WindowSnipCandidate],
        ownProcessID: Int32,
        includeShadow: Bool
    ) -> WindowSnipRequestPlan? {
        guard let target = candidatesFrontToBack.first(where: {
            $0.ownerProcessID != ownProcessID
                && $0.layer == 0
                && $0.isOnScreen
                && !$0.frame.isEmpty
                && $0.frame.contains(pointer)
        }) else {
            state = .idle
            return nil
        }
        state = .targeted(windowID: target.windowID)
        return WindowSnipRequestPlan(
            windowID: target.windowID,
            includeShadow: includeShadow,
            pixelWidth: max(1, Int(target.frame.width * target.scaleFactor)),
            pixelHeight: max(1, Int(target.frame.height * target.scaleFactor)),
            outputOperations: [.pasteboardImage]
        )
    }

    mutating func cancel() {
        state = .idle
    }

    mutating func captureFinished(_ result: WindowSnipCaptureResult) {
        state = .idle
    }
}
