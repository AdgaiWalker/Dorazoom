enum LiveZoomCommandEffect: Equatable, Sendable {
    case toggleDrawingWithinLiveZoom
    case normalCommandHandling
}

enum LiveZoomCommandPolicy {
    static func effect(mode: AppMode, command: AppCommand) -> LiveZoomCommandEffect {
        guard mode == .liveZoom else {
            return .normalCommandHandling
        }

        switch command {
        case .activateStaticZoom, .activateDrawWithoutZoom:
            return .toggleDrawingWithinLiveZoom
        default:
            return .normalCommandHandling
        }
    }
}
