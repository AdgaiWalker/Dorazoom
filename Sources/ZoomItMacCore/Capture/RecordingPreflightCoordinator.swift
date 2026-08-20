import AppKit

@MainActor
protocol RecordingPreflightProviding {
    func input(
        targetName: String,
        targetAvailable: Bool,
        settings: AppSettings
    ) -> RecordingPreflightInput
}

@MainActor
final class SystemRecordingPreflightProvider: RecordingPreflightProviding {
    private let permissionService: PermissionService
    private let minimumAvailableBytes: Int64

    init(
        permissionService: PermissionService,
        minimumAvailableBytes: Int64 = 512 * 1_024 * 1_024
    ) {
        self.permissionService = permissionService
        self.minimumAvailableBytes = minimumAvailableBytes
    }

    func input(
        targetName: String,
        targetAvailable: Bool,
        settings: AppSettings
    ) -> RecordingPreflightInput {
        RecordingPreflightInput(
            targetName: targetName,
            targetAvailable: targetAvailable,
            availableDiskBytes: availableDiskBytes(),
            requiredDiskBytes: minimumAvailableBytes,
            systemAudio: settings.recordSystemAudio
                ? .enabled(permission: .allowed, availability: .available, level: .unknown)
                : .disabled,
            microphone: source(
                enabled: settings.recordMicrophone,
                permission: permissionService.microphoneStatus(),
                available: AudioDevices.microphone(forID: settings.microphoneDeviceID) != nil,
                measuresLevel: true
            ),
            camera: source(
                enabled: settings.webcamEnabled,
                permission: permissionService.cameraStatus(),
                available: VideoDevices.camera(forID: settings.webcamDeviceID) != nil,
                measuresLevel: false
            )
        )
    }

    private func source(
        enabled: Bool,
        permission: MicrophonePermission,
        available: Bool,
        measuresLevel: Bool
    ) -> RecordingPreflightSource {
        guard enabled else { return .disabled }
        let mappedPermission: RecordingPreflightPermission = switch permission {
        case .granted: .allowed
        case .denied: .denied
        case .notDetermined: .notRequested
        }
        return .enabled(
            permission: mappedPermission,
            availability: available ? .available : .unavailable,
            level: measuresLevel ? .unknown : .notApplicable
        )
    }

    private func availableDiskBytes() -> Int64 {
        let url = FileManager.default.temporaryDirectory
        let values = try? url.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ])
        if let capacity = values?.volumeAvailableCapacityForImportantUsage {
            return capacity
        }
        if let capacity = values?.volumeAvailableCapacity {
            return Int64(capacity)
        }
        return 0
    }
}

@MainActor
final class RecordingPreflightWindowController: NSObject, NSWindowDelegate {
    private(set) var window: NSWindow?
    private(set) var renderedPlan: RecordingPreflightPlan?
    private var audioSelection = RecordingPreflightAudioSelection(settings: .defaults)
    private var onProceed: ((RecordingPreflightAudioSelection) -> Void)?
    private var onCancel: (() -> Void)?

    func present(
        _ plan: RecordingPreflightPlan,
        audioSelection: RecordingPreflightAudioSelection,
        onProceed: @escaping (RecordingPreflightAudioSelection) -> Void,
        onCancel: @escaping () -> Void
    ) {
        close(invokeCancel: false)
        renderedPlan = plan
        self.audioSelection = audioSelection
        self.onProceed = onProceed
        self.onCancel = onCancel

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "录制前检查"
        window.level = .normal
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = makeContent(plan)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        close(invokeCancel: true)
    }

    private func makeContent(_ plan: RecordingPreflightPlan) -> NSView {
        let titleText = switch plan.decision {
        case .ready: "已就绪"
        case .requiresConfirmation: "请确认警告"
        case .blocked: "暂时无法开始"
        }
        let title = NSTextField(labelWithString: titleText)
        title.font = .systemFont(ofSize: 18, weight: .semibold)

        let rows = plan.rows.map { row -> NSView in
            let symbol = switch row.status {
            case .ready: "✓"
            case .disabled: "—"
            case .warning: "!"
            case .blocked: "×"
            }
            let name = switch row.kind {
            case .target: "目标"
            case .disk: "磁盘"
            case .systemAudio: "系统声音"
            case .microphone: "麦克风"
            case .camera: "摄像头"
            }

            if row.kind == .systemAudio || row.kind == .microphone {
                let enabled = row.kind == .systemAudio
                    ? audioSelection.systemAudio
                    : audioSelection.microphone
                let checkbox = NSButton(
                    checkboxWithTitle: "录制\(name)",
                    target: self,
                    action: row.kind == .systemAudio
                        ? #selector(systemAudioChanged(_:))
                        : #selector(microphoneChanged(_:))
                )
                checkbox.state = enabled ? .on : .off
                checkbox.font = .systemFont(ofSize: 13)

                let detail = NSTextField(labelWithString: "\(symbol) \(row.detail)")
                detail.font = .systemFont(ofSize: 12)
                detail.textColor = .secondaryLabelColor

                let rowStack = NSStackView(views: [checkbox, detail])
                rowStack.orientation = .horizontal
                rowStack.spacing = 8
                return rowStack
            }

            let label = NSTextField(labelWithString: "\(symbol)  \(name)：\(row.detail)")
            label.font = .systemFont(ofSize: 13)
            return label
        }

        let cancel = NSButton(title: "取消", target: self, action: #selector(cancelPressed))
        cancel.bezelStyle = .rounded
        var buttons = [cancel]
        if plan.decision != .blocked {
            let proceed = NSButton(
                title: plan.decision == .ready ? "开始录制" : "仍然开始",
                target: self,
                action: #selector(proceedPressed)
            )
            proceed.bezelStyle = .rounded
            proceed.keyEquivalent = "\r"
            buttons.insert(proceed, at: 0)
        }
        let buttonRow = NSStackView(views: buttons)
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10

        let stack = NSStackView(views: [title] + rows + [buttonRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        return stack
    }

    @objc private func proceedPressed() {
        let callback = onProceed
        let selection = audioSelection
        close(invokeCancel: false)
        callback?(selection)
    }

    @objc private func systemAudioChanged(_ sender: NSButton) {
        audioSelection.systemAudio = sender.state == .on
    }

    @objc private func microphoneChanged(_ sender: NSButton) {
        audioSelection.microphone = sender.state == .on
    }

    @objc private func cancelPressed() {
        close(invokeCancel: true)
    }

    private func close(invokeCancel: Bool) {
        let callback = invokeCancel ? onCancel : nil
        onProceed = nil
        onCancel = nil
        renderedPlan = nil
        let current = window
        window = nil
        current?.delegate = nil
        current?.orderOut(nil)
        callback?()
    }
}
