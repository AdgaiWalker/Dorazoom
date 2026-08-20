import Foundation

struct ImageExportSimulationImage: Equatable, Sendable {
    var id: String
    var pixelWidth: Int
    var pixelHeight: Int

    static func fixed(id: String, pixelWidth: Int, pixelHeight: Int) -> ImageExportSimulationImage {
        ImageExportSimulationImage(id: id, pixelWidth: pixelWidth, pixelHeight: pixelHeight)
    }
}

enum ImageExportSimulationSource: Equatable, Sendable {
    case currentViewport
    case regionSelection
}

enum ImageExportSimulationSavePanel: Equatable, Sendable {
    case notPresented
    case accepted(path: String)
    case cancelled
    case failed(message: String)
}

enum ImageExportSimulationOCR: Equatable, Sendable {
    case notRequested
    case recognized(String)
}

enum ImageExportSimulationClock: Equatable, Sendable {
    case fixed(filename: String)

    var filename: String {
        switch self {
        case .fixed(let filename):
            return filename
        }
    }
}

struct ImageExportSimulationPasteboard: Equatable, Sendable {
    var images: [ImageExportSimulationImage] = []
    var text: String?
    var changeCounts: [Int] = []
}

struct ImageExportSimulationFile: Equatable, Sendable {
    var path: String
    var imageID: String
}

enum ImageExportSimulationSavePanelEvent: Equatable, Sendable {
    case presented(suggestedFilename: String)
    case accepted(path: String)
    case cancelled
    case failed(message: String)
}

enum ImageExportSimulationFeedbackReason: Equatable, Sendable {
    case ocrFoundNoText
}

enum ImageExportSimulationFeedback: Equatable, Sendable {
    case beep(reason: ImageExportSimulationFeedbackReason)
}

enum ImageExportSimulationOutcome: Equatable, Sendable {
    case completed
    case cancelled
    case failed(message: String)
}

struct ImageExportSimulationResult: Equatable, Sendable {
    var source: ImageExportSimulationSource
    var pasteboard: ImageExportSimulationPasteboard
    var pasteboardOutputs: [SnipPasteboardOutput]
    var files: [ImageExportSimulationFile]
    var savePanelEvents: [ImageExportSimulationSavePanelEvent]
    var feedback: [ImageExportSimulationFeedback]
    var pasteCompatibilityChangeCountsToArm: [Int]
    var outcome: ImageExportSimulationOutcome
    var platformBoundary: AutomationPlatformBoundary
}

enum ImageExportSimulation {
    static func run(
        image: ImageExportSimulationImage,
        action: SnipAction,
        source: ImageExportSimulationSource,
        settings: AppSettings,
        savePanel: ImageExportSimulationSavePanel,
        ocr: ImageExportSimulationOCR,
        clock: ImageExportSimulationClock
    ) -> ImageExportSimulationResult {
        var pasteboard = ImageExportSimulationPasteboard()
        var pasteboardOutputs: [SnipPasteboardOutput] = []
        var files: [ImageExportSimulationFile] = []
        var savePanelEvents: [ImageExportSimulationSavePanelEvent] = []
        var feedback: [ImageExportSimulationFeedback] = []
        var pasteCompatibilityChangeCountsToArm: [Int] = []
        var outcome: ImageExportSimulationOutcome = .completed

        for operation in SnipExportPlan.operations(for: action, settings: settings) {
            switch operation {
            case .pasteboardImage:
                let changeCount = nextChangeCount(after: pasteboard)
                pasteboard.images.append(image)
                pasteboard.changeCounts.append(changeCount)
                pasteboardOutputs.append(.image(changeCount: changeCount))
                pasteCompatibilityChangeCountsToArm.append(changeCount)

            case .directoryFile:
                files.append(.init(path: directoryPath(settings.snipSaveDirectory, filename: clock.filename), imageID: image.id))

            case .savePanel:
                savePanelEvents.append(.presented(suggestedFilename: clock.filename))
                switch savePanel {
                case .notPresented:
                    outcome = .failed(message: "save panel was required but no simulated decision was supplied")
                case .accepted(let path):
                    savePanelEvents.append(.accepted(path: path))
                    files.append(.init(path: path, imageID: image.id))
                case .cancelled:
                    savePanelEvents.append(.cancelled)
                    outcome = .cancelled
                case .failed(let message):
                    savePanelEvents.append(.failed(message: message))
                    outcome = .failed(message: message)
                }

            case .ocrClipboard:
                switch ocr {
                case .notRequested:
                    outcome = .failed(message: "OCR operation was required but no simulated OCR result was supplied")
                case .recognized(let text) where text.isEmpty:
                    feedback.append(.beep(reason: .ocrFoundNoText))
                    outcome = .cancelled
                case .recognized(let text):
                    let changeCount = nextChangeCount(after: pasteboard)
                    pasteboard.text = text
                    pasteboard.changeCounts.append(changeCount)
                    pasteboardOutputs.append(.ocrText(
                        changeCount: changeCount,
                        characterCount: text.count
                    ))
                    pasteCompatibilityChangeCountsToArm.append(changeCount)
                }
            }
        }

        return ImageExportSimulationResult(
            source: source,
            pasteboard: pasteboard,
            pasteboardOutputs: pasteboardOutputs,
            files: files,
            savePanelEvents: savePanelEvents,
            feedback: feedback,
            pasteCompatibilityChangeCountsToArm: pasteCompatibilityChangeCountsToArm,
            outcome: outcome,
            platformBoundary: .simulatedOnly
        )
    }

    private static func nextChangeCount(after pasteboard: ImageExportSimulationPasteboard) -> Int {
        (pasteboard.changeCounts.last ?? 0) + 1
    }

    private static func directoryPath(_ directory: String, filename: String) -> String {
        let trimmed = directory.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "Documents" : trimmed
        return base.hasSuffix("/") ? "\(base)\(filename)" : "\(base)/\(filename)"
    }
}
