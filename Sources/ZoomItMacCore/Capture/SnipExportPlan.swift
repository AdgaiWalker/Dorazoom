enum SnipExportOperation: Equatable, Sendable {
    case pasteboardImage
    case directoryFile
    case savePanel
    case ocrClipboard
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
    var copyOCR: (Image) -> Void

    func execute(image: Image, operations: [SnipExportOperation]) -> [Int] {
        var pasteboardChangeCounts: [Int] = []
        for operation in operations {
            switch operation {
            case .pasteboardImage:
                pasteboardChangeCounts.append(copyToPasteboard(image))
            case .directoryFile:
                writeToDirectory(image)
            case .savePanel:
                presentSavePanel(image)
            case .ocrClipboard:
                copyOCR(image)
            }
        }
        return pasteboardChangeCounts
    }
}
