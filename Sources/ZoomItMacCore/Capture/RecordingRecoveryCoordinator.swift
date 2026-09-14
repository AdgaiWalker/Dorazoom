import AppKit

final class FileRecordingRecoveryStore: RecordingRecoveryStoring {
    private let fileManager: FileManager
    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default, directory: URL? = nil) {
        self.fileManager = fileManager
        if let directory {
            self.directory = directory
        } else {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.directory = base
                .appendingPathComponent("DoraZoom", isDirectory: true)
                .appendingPathComponent("Recording Recovery", isDirectory: true)
        }
        encoder.outputFormatting = [.sortedKeys]
    }

    func save(_ manifest: RecordingRecoveryManifest) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try encoder.encode(manifest).write(to: manifestURL(id: manifest.id), options: .atomic)
    }

    func remove(id: String) throws {
        let url = manifestURL(id: id)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    func loadAll() throws -> [RecordingRecoveryManifest] {
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        return try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "json" }
        .compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(RecordingRecoveryManifest.self, from: data)
        }
        .sorted { $0.createdAt < $1.createdAt }
    }

    func fileState(for manifest: RecordingRecoveryManifest) -> RecordingRecoveryFileState {
        let url = URL(fileURLWithPath: manifest.temporaryPath)
        guard fileManager.fileExists(atPath: url.path) else { return .missing }
        let size = ((try? fileManager.attributesOfItem(atPath: url.path)[.size]) as? NSNumber)?.int64Value ?? 0
        return manifest.phase == .finalized
            ? .finalizedMovie(byteCount: size)
            : .fragmentedMovie(byteCount: size)
    }

    func deleteMovie(for manifest: RecordingRecoveryManifest) throws {
        let url = URL(fileURLWithPath: manifest.temporaryPath)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private func manifestURL(id: String) -> URL {
        directory.appendingPathComponent(id).appendingPathExtension("json")
    }
}

@MainActor
final class RecordingRecoveryCoordinator {
    private let store: RecordingRecoveryStoring
    private var pending: [RecordingRecoveryManifest] = []
    private var window: NSWindow?
    private var currentManifest: RecordingRecoveryManifest?

    init(store: RecordingRecoveryStoring) {
        self.store = store
    }

    func presentPendingIfNeeded() {
        pending = (try? store.loadAll()) ?? []
        presentNext()
    }

    private func presentNext() {
        while let manifest = pending.first {
            switch RecordingRecoveryPlanner.plan(
                manifest: manifest,
                file: store.fileState(for: manifest)
            ) {
            case .discardManifest:
                try? store.remove(id: manifest.id)
                pending.removeFirst()
            case .recoverMovie(_, let isFinalized):
                presentWindow(manifest: manifest, isFinalized: isFinalized)
                return
            }
        }
    }

    private func presentWindow(manifest: RecordingRecoveryManifest, isFinalized: Bool) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 190),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = AppLocalization.string(
            "recording.recovery.window.title",
            defaultValue: "Recover an Unfinished Recording"
        )
        window.level = .normal
        window.isReleasedWhenClosed = false

        let message = NSTextField(labelWithString: isFinalized
            ? AppLocalization.string(
                "recording.recovery.message.finalized",
                defaultValue: "DoraZoom found a completed recording that has not been exported."
            )
            : AppLocalization.string(
                "recording.recovery.message.fragmented",
                defaultValue: "DoraZoom found a fragmented MOV that may be recoverable through its last written fragment."
            ))
        message.maximumNumberOfLines = 3
        let recover = NSButton(
            title: AppLocalization.string(
                "recording.recovery.action.recover_to",
                defaultValue: "Recover To…"
            ),
            target: self,
            action: #selector(recoverPressed)
        )
        recover.bezelStyle = .rounded
        let discard = NSButton(
            title: AppLocalization.string(
                "recording.recovery.action.discard",
                defaultValue: "Discard"
            ),
            target: self,
            action: #selector(discardPressed)
        )
        discard.bezelStyle = .rounded
        let buttons = NSStackView(views: [recover, discard])
        buttons.orientation = .horizontal
        buttons.spacing = 10
        let stack = NSStackView(views: [message, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        window.contentView = stack
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        currentManifest = manifest
        self.window = window
    }

    @objc private func recoverPressed() {
        guard let currentManifest else { return }
        recover(currentManifest)
    }

    @objc private func discardPressed() {
        guard let currentManifest else { return }
        discard(currentManifest)
    }

    private func recover(_ manifest: RecordingRecoveryManifest) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = AppLocalization.string(
            "recording.recovery.suggested_filename",
            defaultValue: "DoraZoom Recovered.mov"
        )
        panel.allowedContentTypes = [.quickTimeMovie]
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        let source = URL(fileURLWithPath: manifest.temporaryPath)
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: source, to: destination)
            try store.remove(id: manifest.id)
            completeCurrent()
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private func discard(_ manifest: RecordingRecoveryManifest) {
        try? store.deleteMovie(for: manifest)
        try? store.remove(id: manifest.id)
        completeCurrent()
    }

    private func completeCurrent() {
        window?.orderOut(nil)
        window = nil
        currentManifest = nil
        if !pending.isEmpty { pending.removeFirst() }
        presentNext()
    }
}
