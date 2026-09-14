import AppKit

@MainActor
final class PermissionCenterWindowController: NSObject, PermissionCenterPresenting, NSWindowDelegate {
    private let onSelectRowAction: (PermissionCenterKind) -> Void

    private(set) var window: NSWindow?
    private(set) var renderedPlan: PermissionCenterPlan?

    var isVisible: Bool {
        window?.isVisible == true
    }

    var renderedRowKinds: [PermissionCenterKind] {
        renderedPlan?.rows.map(\.kind) ?? []
    }

    init(onSelectRowAction: @escaping (PermissionCenterKind) -> Void) {
        self.onSelectRowAction = onSelectRowAction
        super.init()
    }

    func present(_ plan: PermissionCenterPlan) {
        let window = self.window ?? makeWindow()
        render(plan, in: window)
        window.makeKeyAndOrderFront(nil)
    }

    func refresh(_ plan: PermissionCenterPlan) {
        guard let window else { return }
        render(plan, in: window)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        renderedPlan = nil
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 430),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = AppLocalization.string(
            "permission_center.window_title",
            defaultValue: "DoraZoom Permissions"
        )
        window.level = .normal
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 560, height: 360)
        window.delegate = self
        window.center()
        self.window = window
        return window
    }

    private func render(_ plan: PermissionCenterPlan, in window: NSWindow) {
        renderedPlan = plan

        let title = NSTextField(labelWithString: AppLocalization.string(
            "permission_center.title",
            defaultValue: "Permissions"
        ))
        title.font = .systemFont(ofSize: 22, weight: .semibold)

        let explanation = NSTextField(labelWithString: AppLocalization.string(
            "permission_center.explanation",
            defaultValue: "DoraZoom requests access only when you use the related feature. This page refreshes automatically when you return to DoraZoom."
        ))
        explanation.font = .systemFont(ofSize: 13)
        explanation.textColor = .secondaryLabelColor
        explanation.maximumNumberOfLines = 0
        explanation.lineBreakMode = .byWordWrapping

        let rows = plan.rows.enumerated().map { index, row in
            makeRow(row, index: index)
        }
        let rowStack = NSStackView(views: rows)
        rowStack.orientation = .vertical
        rowStack.alignment = .leading
        rowStack.spacing = 10
        rowStack.distribution = .fill

        let content = NSStackView(views: [title, explanation, rowStack])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 14
        content.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        content.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            content.topAnchor.constraint(equalTo: container.topAnchor),
            content.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
            rowStack.widthAnchor.constraint(equalTo: content.widthAnchor)
        ])
        window.contentView = container
    }

    private func makeRow(_ row: PermissionCenterRow, index: Int) -> NSView {
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: symbolName(for: row.kind), accessibilityDescription: title(for: row.kind))
        icon.contentTintColor = .secondaryLabelColor
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24)
        ])

        let title = NSTextField(labelWithString: title(for: row.kind))
        title.font = .systemFont(ofSize: 13, weight: .semibold)

        let purpose = NSTextField(labelWithString: row.purpose)
        purpose.font = .systemFont(ofSize: 12)
        purpose.textColor = .secondaryLabelColor
        purpose.maximumNumberOfLines = 0
        purpose.lineBreakMode = .byWordWrapping

        let status = NSTextField(labelWithString: statusText(for: row.state))
        status.font = .systemFont(ofSize: 12, weight: .medium)
        status.textColor = statusColor(for: row.state)

        let labels = NSStackView(views: [title, purpose, status])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 3

        var views: [NSView] = [icon, labels]
        if row.action != .none {
            let button = NSButton(title: actionTitle(for: row.action), target: self, action: #selector(rowAction(_:)))
            button.bezelStyle = .rounded
            button.tag = index
            views.append(button)
        }

        let rowStack = NSStackView(views: views)
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 12
        rowStack.edgeInsets = NSEdgeInsets(top: 11, left: 12, bottom: 11, right: 12)
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.wantsLayer = true
        container.layer?.borderWidth = 0.5
        container.layer?.borderColor = NSColor.separatorColor.cgColor
        container.layer?.cornerRadius = 9
        container.addSubview(rowStack)
        NSLayoutConstraint.activate([
            rowStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            rowStack.topAnchor.constraint(equalTo: container.topAnchor),
            rowStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 500)
        ])
        return container
    }

    @objc private func rowAction(_ sender: NSButton) {
        guard let rows = renderedPlan?.rows, rows.indices.contains(sender.tag) else { return }
        onSelectRowAction(rows[sender.tag].kind)
    }

    private func title(for kind: PermissionCenterKind) -> String {
        switch kind {
        case .screenCapture:
            AppLocalization.string("permission_center.kind.screen_recording", defaultValue: "Screen Recording")
        case .inputPosting:
            AppLocalization.string("permission_center.kind.accessibility", defaultValue: "Accessibility")
        case .inputListeningFallback:
            AppLocalization.string("permission_center.kind.input_monitoring_fallback", defaultValue: "Input Monitoring (Fallback)")
        case .microphone:
            AppLocalization.string("permission_center.kind.microphone", defaultValue: "Microphone")
        case .camera:
            AppLocalization.string("permission_center.kind.camera", defaultValue: "Camera")
        }
    }

    private func symbolName(for kind: PermissionCenterKind) -> String {
        switch kind {
        case .screenCapture: "rectangle.on.rectangle"
        case .inputPosting: "keyboard"
        case .inputListeningFallback: "keyboard.badge.ellipsis"
        case .microphone: "mic"
        case .camera: "video"
        }
    }

    private func statusText(for state: PermissionCenterRowState) -> String {
        switch state {
        case .ready:
            AppLocalization.string("permission_center.status.ready", defaultValue: "Ready")
        case .notRequested:
            AppLocalization.string("permission_center.status.not_requested", defaultValue: "Not Requested")
        case .optionalNotRequested:
            AppLocalization.string("permission_center.status.optional_not_enabled", defaultValue: "Optional · Not Enabled")
        case .needsSettings:
            AppLocalization.string("permission_center.status.needs_settings", defaultValue: "Open System Settings to Continue")
        case .restartRequired:
            AppLocalization.string("permission_center.status.restart_required", defaultValue: "Granted · Restart Required")
        }
    }

    private func statusColor(for state: PermissionCenterRowState) -> NSColor {
        switch state {
        case .ready: .systemGreen
        case .optionalNotRequested: .secondaryLabelColor
        case .notRequested: .secondaryLabelColor
        case .needsSettings: .systemOrange
        case .restartRequired: .systemBlue
        }
    }

    private func actionTitle(for action: PermissionCenterAction) -> String {
        switch action {
        case .none: ""
        case .requestPermission:
            AppLocalization.string("permission_center.action.request", defaultValue: "Request Permission")
        case .openSystemSettings:
            AppLocalization.string("permission_center.action.open_system_settings", defaultValue: "Open System Settings")
        case .restartApp:
            AppLocalization.string("permission_center.action.restart_app", defaultValue: "Restart DoraZoom")
        }
    }
}
