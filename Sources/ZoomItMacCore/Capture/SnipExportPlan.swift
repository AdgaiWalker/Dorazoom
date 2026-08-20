enum SnipExportOperation: Equatable, Sendable {
    case pasteboardImage
    case directoryFile
    case savePanel
    case ocrClipboard
}

enum SnipPasteboardOutput: Equatable, Sendable {
    case image(changeCount: Int)
    case ocrText(changeCount: Int, characterCount: Int)

    var changeCount: Int {
        switch self {
        case let .image(changeCount), let .ocrText(changeCount, _):
            changeCount
        }
    }

    var feedbackCompletion: FeedbackCompletion {
        switch self {
        case .image:
            .screenshotCopied
        case let .ocrText(_, characterCount):
            .ocrCopied(characterCount: characterCount)
        }
    }
}

enum SnipExportPlan {
    static func operations(for action: SnipAction, settings: AppSettings) -> [SnipExportOperation] {
        switch action {
        case .copyImage:
            return [.pasteboardImage]
        case .saveImage:
            var operations: [SnipExportOperation] = []
            if settings.copySnipToClipboardOnSave {
                operations.append(.pasteboardImage)
            }
            operations.append(settings.saveSnipToDirectory ? .directoryFile : .savePanel)
            return operations
        case .recognizeText:
            return [.ocrClipboard]
        }
    }
}

struct SnipExportExecutor<Image> {
    var copyToPasteboard: (Image) -> Int
    var writeToDirectory: (Image) -> Void
    var presentSavePanel: (Image) -> Void
    var copyOCR: (Image, @escaping (SnipPasteboardOutput) -> Void) -> Void

    func execute(
        image: Image,
        operations: [SnipExportOperation],
        onPasteboardOutput: @escaping (SnipPasteboardOutput) -> Void
    ) {
        for operation in operations {
            switch operation {
            case .pasteboardImage:
                onPasteboardOutput(.image(changeCount: copyToPasteboard(image)))
            case .directoryFile:
                writeToDirectory(image)
            case .savePanel:
                presentSavePanel(image)
            case .ocrClipboard:
                copyOCR(image, onPasteboardOutput)
            }
        }
    }
}
