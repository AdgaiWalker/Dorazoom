import AppKit
import UniformTypeIdentifiers

/// What happened to an export. A failure is never silent: the caller still owns
/// the image, and `ImageExporter` has already offered a way out.
enum SaveOutcome: Equatable {
    case saved(URL)
    /// Nothing was written. The capture was preserved on the clipboard so it
    /// cannot be lost while the user picks another location.
    case failed(FileAccessError)
}

/// Shared helpers for exporting a captured image: copying it to the clipboard
/// or saving it to a PNG file, mirroring ZoomIt's Ctrl+C / Ctrl+S behaviour.
@MainActor
enum ImageExporter {
    /// Copies the image to the general pasteboard as PNG and TIFF so it can be
    /// pasted into the widest range of apps.
    @discardableResult
    static func copyToPasteboard(_ image: CGImage) -> Int {
        let rep = NSBitmapImageRep(cgImage: image)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let png = rep.representation(using: .png, properties: [:]) {
            pasteboard.setData(png, forType: .png)
        }
        if let tiff = rep.tiffRepresentation {
            pasteboard.setData(tiff, forType: .tiff)
        }
        return pasteboard.changeCount
    }

    /// Saves the image according to the user's snip preferences: optionally
    /// copies it to the clipboard as well, then either writes it directly to the
    /// configured directory or presents a Save dialog. `onWillShowSaveDialog` is
    /// invoked only when the Save dialog is about to appear, so callers can
    /// prepare their UI (e.g. lower an overlay window).
    static func saveImage(
        _ image: CGImage,
        settings: AppSettings,
        onWillShowSaveDialog: (() -> Void)? = nil
    ) {
        if settings.copySnipToClipboardOnSave {
            copyToPasteboard(image)
        }
        if settings.saveSnipToDirectory {
            writeToDirectory(image, directoryPath: settings.snipSaveDirectory)
        } else {
            onWillShowSaveDialog?()
            presentSavePanel(for: image)
        }
    }

    /// Presents a Save dialog defaulting to a timestamped PNG name and writes
    /// the image as PNG.
    static func presentSavePanel(for image: CGImage) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedFilename()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        NSApp.activate(ignoringOtherApps: true)

        guard panel.runModal() == .OK, let url = panel.url else { return }
        let rep = NSBitmapImageRep(cgImage: image)
        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        do {
            try png.write(to: url)
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    /// Writes the image as a timestamped PNG into `directoryPath` (or the user's
    /// Documents folder when it is empty).
    ///
    /// When the user has granted access to a save folder, the write runs inside
    /// that security-scoped grant: a folder chosen in a previous launch is only
    /// reachable through its bookmark, so resolving it here is what makes
    /// "restart the app, save again" work. A failure is surfaced with the exits
    /// the user needs and the capture is put on the clipboard meanwhile, rather
    /// than being dropped.
    @discardableResult
    static func writeToDirectory(
        _ image: CGImage,
        directoryPath: String,
        fileAccess: FileAccessService = FileAccessService()
    ) -> SaveOutcome {
        guard let png = pngData(for: image) else {
            return fail(
                .encodingFailed("PNG encoding returned no data"),
                image: image,
                fileAccess: fileAccess
            )
        }

        do {
            let url: URL
            if fileAccess.hasStoredAuthorization {
                url = try fileAccess.withAuthorizedFolder { folder in
                    try write(png, into: folder)
                }
            } else {
                // No grant on record. A configured path can still be writable —
                // the non-sandboxed build, or a folder granted earlier in this
                // launch — so try it, but never assume it at the next launch.
                url = try write(png, into: resolvedSaveDirectory(directoryPath))
            }
            return .saved(url)
        } catch let error as FileAccessError {
            return fail(error, image: image, fileAccess: fileAccess)
        } catch {
            return fail(
                .writeFailed(error.localizedDescription),
                image: image,
                fileAccess: fileAccess
            )
        }
    }

    /// Writes `png` into `folder` under an auto-generated name, creating the
    /// folder when needed. Throws `FileAccessError.folderUnavailable` when the
    /// folder is gone or read-only, so the caller can offer to re-pick it.
    static func write(_ png: Data, into folder: URL) throws -> URL {
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            throw FileAccessError.folderUnavailable(folder.path)
        }

        guard fileManager.isWritableFile(atPath: folder.path) else {
            throw FileAccessError.folderUnavailable(folder.path)
        }

        let url = folder.appendingPathComponent(suggestedFilename())
        do {
            try png.write(to: url)
        } catch {
            throw FileAccessError.writeFailed(error.localizedDescription)
        }
        return url
    }

    static func pngData(for image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    private static func fail(
        _ error: FileAccessError,
        image: CGImage,
        fileAccess: FileAccessService
    ) -> SaveOutcome {
        presentSaveFailure(error, for: image, fileAccess: fileAccess)
        return .failed(error)
    }

    /// Reports a failed direct save with the exits the plan requires:
    /// "重新选择位置" records a fresh grant and retries, "另存为" writes wherever
    /// the user points, and cancelling keeps the capture on the clipboard so it
    /// is not lost while the overlay goes away.
    static func presentSaveFailure(
        _ error: FileAccessError,
        for image: CGImage,
        fileAccess: FileAccessService
    ) {
        copyToPasteboard(image)

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = AppLocalization.string(
            "save_failure.title",
            defaultValue: "DoraZoom could not save the image"
        )
        alert.informativeText = error.userFacingReason + "\n\n" + AppLocalization.string(
            "save_failure.clipboard_notice",
            defaultValue: "The image is on the clipboard, so it is not lost."
        )
        alert.addButton(withTitle: AppLocalization.string(
            "save_failure.choose_folder",
            defaultValue: "Choose Folder Again…"
        ))
        alert.addButton(withTitle: AppLocalization.string(
            "save_failure.save_as",
            defaultValue: "Save As…"
        ))
        alert.addButton(withTitle: AppLocalization.string(
            "common.cancel",
            defaultValue: "Cancel"
        ))

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            guard let url = chooseSaveDirectory() else { return }
            _ = try? fileAccess.grantAccess(to: url)
            writeToDirectory(image, directoryPath: url.path, fileAccess: fileAccess)
        case .alertSecondButtonReturn:
            presentSavePanel(for: image)
        default:
            break
        }
    }

    /// Open panel used when the recorded grant can no longer be restored and the
    /// user has to point at the folder again.
    static func chooseSaveDirectory() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = AppLocalization.string("common.choose", defaultValue: "Choose")
        panel.title = AppLocalization.string(
            "save_failure.choose_folder.title",
            defaultValue: "DoraZoom: Choose Save Folder"
        )
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    /// The directory used when saving directly: the configured folder, or the
    /// user's Documents folder when unset.
    static func resolvedSaveDirectory(_ directoryPath: String) -> URL {
        let trimmed = directoryPath.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return defaultSaveDirectory()
        }
        return URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath, isDirectory: true)
    }

    /// The default save location shown in Settings and used when no directory is
    /// configured: the user's Documents folder.
    static func defaultSaveDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    }

    /// "DoraZoom YYYY-MM-DD HHMMSS.png", matching ZoomIt's unique-name scheme.
    static func suggestedFilename() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HHmmss"
        return "\(AppInfo.productName) \(formatter.string(from: Date())).png"
    }
}
