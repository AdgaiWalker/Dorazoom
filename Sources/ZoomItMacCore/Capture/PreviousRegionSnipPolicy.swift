import CoreGraphics

struct PreviousRegionDisplay: Equatable, Sendable {
    var id: UInt32
    var frame: CGRect
    var scaleFactor: CGFloat
}

struct PreviousRegionReusePlan: Equatable, Sendable {
    var displayID: UInt32
    var selectionInPoints: CGRect
    var pixelRect: CGRect
}

enum PreviousRegionFallbackReason: Equatable, Sendable {
    case noHistory
    case topologyChanged
    case displayUnavailable
}

enum PreviousRegionSnipPlan: Equatable, Sendable {
    case selectNew(reason: PreviousRegionFallbackReason)
    case reuse(PreviousRegionReusePlan)
}

struct PreviousRegionSnipMemory: Equatable, Sendable {
    static let exportOperations: [SnipExportOperation] = [.pasteboardImage]

    private struct Record: Equatable, Sendable {
        var selection: CGRect
        var displayID: UInt32
        var topology: [PreviousRegionDisplay]
    }

    private var record: Record?

    mutating func remember(
        selection: CGRect,
        displayID: UInt32,
        displays: [PreviousRegionDisplay]
    ) {
        guard selection.width > 0, selection.height > 0 else { return }
        record = Record(
            selection: selection.standardized,
            displayID: displayID,
            topology: normalized(displays)
        )
    }

    mutating func plan(for displays: [PreviousRegionDisplay]) -> PreviousRegionSnipPlan {
        guard let record else { return .selectNew(reason: .noHistory) }
        let currentTopology = normalized(displays)
        guard currentTopology == record.topology else {
            self.record = nil
            return .selectNew(reason: .topologyChanged)
        }
        guard let display = currentTopology.first(where: { $0.id == record.displayID }) else {
            self.record = nil
            return .selectNew(reason: .displayUnavailable)
        }
        let scale = display.scaleFactor
        let selection = record.selection
        return .reuse(PreviousRegionReusePlan(
            displayID: record.displayID,
            selectionInPoints: selection,
            pixelRect: CGRect(
                x: selection.minX * scale,
                y: selection.minY * scale,
                width: selection.width * scale,
                height: selection.height * scale
            ).integral
        ))
    }

    mutating func selectionCancelled() {
        // Cancellation is not a successful replacement and deliberately keeps
        // the last valid region available for the next explicit repeat action.
    }

    private func normalized(_ displays: [PreviousRegionDisplay]) -> [PreviousRegionDisplay] {
        displays.sorted { lhs, rhs in
            if lhs.id != rhs.id { return lhs.id < rhs.id }
            if lhs.frame.minX != rhs.frame.minX { return lhs.frame.minX < rhs.frame.minX }
            return lhs.frame.minY < rhs.frame.minY
        }
    }
}

extension PreviousRegionDisplay {
    init(_ descriptor: DisplayDescriptor) {
        self.init(
            id: descriptor.id,
            frame: descriptor.frame,
            scaleFactor: descriptor.scaleFactor
        )
    }
}
