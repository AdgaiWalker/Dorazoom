import AppKit
import UniformTypeIdentifiers

@MainActor
private final class SettingsWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        close()
    }
}

@MainActor
private final class SettingsDocumentView: NSView {
    override var isFlipped: Bool { true }
}

@MainActor
private final class SettingsClipView: NSClipView {
    override var isFlipped: Bool { true }
}

/// Native macOS settings window with six product-oriented navigation groups.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private let settingsStore: SettingsStore
    private let fileAccess: FileAccessService
    private let onHotKeyChange: () -> Void
    private let onSettingsChange: () -> Void
    private let onSuspendHotkeys: () -> Void
    private let onResumeHotkeys: () -> Void
    private let onRequestMicrophone: () -> Void
    private let onRequestCamera: () -> Void
    private let onOpenTrimEditor: () -> Void
    private let onOpenPermissionCenter: () -> Void
    private var settings: AppSettings
    private let navigationPlan = SettingsNavigationModel.defaultPlan
    private lazy var hotkeyCaptureSession = HotkeyCaptureSession(
        suspendHotkeys: onSuspendHotkeys,
        resumeHotkeys: onResumeHotkeys
    )

    private static let contentWidth: CGFloat = 620
    private static let panelHorizontalInset: CGFloat = 28
    private static let wrappedLabelWidth: CGFloat = contentWidth - panelHorizontalInset * 2

    private var window: NSWindow?
    private weak var navigationTableView: NSTableView?
    private weak var sectionContentContainer: NSView?
    private var sectionViews: [SettingsNavigationSectionID: NSView] = [:]

    var windowLevel: NSWindow.Level? { window?.level }
    var usesSplitNavigation: Bool { window?.contentViewController is NSSplitViewController }
    var renderedSectionIDs: [SettingsNavigationSectionID] { navigationPlan.sections.map(\.id) }
    var windowFrameAutosaveName: String? { window?.frameAutosaveName }

    // Type tab controls.
    private weak var fontSampleLabel: NSTextField?

    // General tab controls.
    private weak var launchAtLoginCheckbox: NSButton?

    // Record tab controls.
    private weak var microphonePopup: NSPopUpButton?
    private weak var noiseCancellationCheckbox: NSButton?

    // Snip tab controls.
    private weak var snipSaveDirectoryField: NSTextField?
    private weak var snipSaveDirectoryBrowseButton: NSButton?

#if !DORAZOOM_APP_STORE
    // DemoType tab controls.
    private weak var demoTypeFileField: NSTextField?
#endif

    // Webcam controls.
    private weak var webcamDevicePopup: NSPopUpButton?
    private weak var webcamPositionPopup: NSPopUpButton?
    private weak var webcamSizePopup: NSPopUpButton?
    private weak var webcamShapePopup: NSPopUpButton?

    // Break tab controls.
    private weak var breakDurationLabel: NSTextField?
    private weak var breakSoundFileField: NSTextField?
    private weak var breakBackgroundModePopup: NSPopUpButton?
    private weak var breakBackgroundFileField: NSTextField?
    private weak var breakBackgroundBrowseButton: NSButton?
    private weak var breakBackgroundStretchCheckbox: NSButton?

    // Hotkey recorders.
    private enum HotKeyTarget {
        case zoom
        case draw
        case live
        case breakTimer
        case snip
        case snipOcr
        case record
#if !DORAZOOM_APP_STORE
        case demoType
#endif
        case panorama
    }
    private weak var hotKeyButton: NSButton?
    private weak var drawHotKeyButton: NSButton?
    private weak var liveHotKeyButton: NSButton?
    private weak var breakHotKeyButton: NSButton?
    private weak var snipHotKeyButton: NSButton?
    private weak var snipOcrHotKeyButton: NSButton?
    private weak var recordHotKeyButton: NSButton?
#if !DORAZOOM_APP_STORE
    private weak var demoTypeHotKeyButton: NSButton?
#endif
    private weak var panoramaHotKeyButton: NSButton?
    private weak var activeHotKeyButton: NSButton?
    private var hotKeyMonitor: Any?
    private var recordingTarget: HotKeyTarget?

    init(
        settingsStore: SettingsStore,
        fileAccess: FileAccessService = FileAccessService(),
        onHotKeyChange: @escaping () -> Void,
        onSettingsChange: @escaping () -> Void,
        onSuspendHotkeys: @escaping () -> Void,
        onResumeHotkeys: @escaping () -> Void,
        onRequestMicrophone: @escaping () -> Void,
        onRequestCamera: @escaping () -> Void,
        onOpenTrimEditor: @escaping () -> Void,
        onOpenPermissionCenter: @escaping () -> Void
    ) {
        self.settingsStore = settingsStore
        self.fileAccess = fileAccess
        self.onHotKeyChange = onHotKeyChange
        self.onSettingsChange = onSettingsChange
        self.onSuspendHotkeys = onSuspendHotkeys
        self.onResumeHotkeys = onResumeHotkeys
        self.onRequestMicrophone = onRequestMicrophone
        self.onRequestCamera = onRequestCamera
        self.onOpenTrimEditor = onOpenTrimEditor
        self.onOpenPermissionCenter = onOpenPermissionCenter
        self.settings = settingsStore.load()
        super.init()
    }

    func show() {
        // Always reflect the latest persisted values when re-opening.
        settings = settingsStore.load()

        if window == nil {
            window = makeWindow()
        }

        guard let window else { return }
        Self.ensureUsableFrame(
            window,
            defaultContentSize: NSSize(width: 860, height: 640),
            minimumContentSize: NSSize(width: 760, height: 520)
        )
        hotKeyButton?.title = zoomHotKeyDisplayString()
        drawHotKeyButton?.title = drawHotKeyDisplayString()
        liveHotKeyButton?.title = liveHotKeyDisplayString()
        breakHotKeyButton?.title = breakHotKeyDisplayString()
        snipHotKeyButton?.title = snipHotKeyDisplayString()
        snipOcrHotKeyButton?.title = snipOcrHotKeyDisplayString()
        recordHotKeyButton?.title = recordHotKeyDisplayString()
#if !DORAZOOM_APP_STORE
        demoTypeHotKeyButton?.title = demoTypeHotKeyDisplayString()
#endif
        panoramaHotKeyButton?.title = panoramaHotKeyDisplayString()
        launchAtLoginCheckbox?.state = settings.launchAtLogin ? .on : .off
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        // Closing the window only resumes hotkeys when a capture session was active.
        finishRecording()
    }

    // MARK: - Window construction

    private func makeWindow() -> NSWindow {
        sectionViews = Dictionary(uniqueKeysWithValues: navigationPlan.sections.map { section in
            (section.id, makeSectionView(for: section.id))
        })

        let table = NSTableView()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("settings-navigation"))
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = 36
        table.style = .sourceList
        table.dataSource = self
        table.delegate = self
        navigationTableView = table

        let sidebarScroll = NSScrollView()
        sidebarScroll.drawsBackground = false
        sidebarScroll.hasVerticalScroller = true
        sidebarScroll.documentView = table

        let sidebarController = NSViewController()
        sidebarController.view = sidebarScroll

        let contentContainer = NSView()
        sectionContentContainer = contentContainer
        let contentController = NSViewController()
        contentController.view = contentContainer

        let splitController = NSSplitViewController()
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarController)
        sidebarItem.minimumThickness = 170
        sidebarItem.maximumThickness = 220
        sidebarItem.canCollapse = false
        splitController.addSplitViewItem(sidebarItem)
        splitController.addSplitViewItem(NSSplitViewItem(viewController: contentController))

        let defaultContentSize = NSSize(width: 860, height: 640)
        let minimumContentSize = NSSize(width: 760, height: 520)
        let window = SettingsWindow(
            contentRect: NSRect(origin: .zero, size: defaultContentSize),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = localized("settings.window.title", "DoraZoom Settings")
        window.contentViewController = splitController
        window.isReleasedWhenClosed = false
        window.minSize = minimumContentSize
        window.delegate = self
        Self.configureAsNormalWindow(window)
        // Autosave can restore a collapsed frame (seen as ~170x42 on newer macOS
        // when NSSplitViewController reports a near-zero fitting size). Reject it.
        window.setFrameAutosaveName("DoraZoom.SettingsWindow")
        Self.ensureUsableFrame(
            window,
            defaultContentSize: defaultContentSize,
            minimumContentSize: minimumContentSize
        )

        table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        showSection(at: 0)
        return window
    }

    static func configureAsNormalWindow(_ window: NSWindow) {
        window.level = .normal
        window.hidesOnDeactivate = false
    }

    /// Restores a sane frame when autosave/split-view layout collapses the window
    /// below its designed minimum (title-bar-only height or sidebar-only width).
    static func ensureUsableFrame(
        _ window: NSWindow,
        defaultContentSize: NSSize,
        minimumContentSize: NSSize
    ) {
        let frame = window.frame
        let tooNarrow = frame.width + 0.5 < minimumContentSize.width
        let tooShort = frame.height + 0.5 < minimumContentSize.height
        guard tooNarrow || tooShort else { return }

        var restored = frame
        restored.size = defaultContentSize
        if let screen = window.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            restored.origin.x = visible.midX - restored.width / 2
            restored.origin.y = visible.midY - restored.height / 2
            restored.origin.x = min(max(restored.origin.x, visible.minX), visible.maxX - restored.width)
            restored.origin.y = min(max(restored.origin.y, visible.minY), visible.maxY - restored.height)
        }
        window.setFrame(restored, display: true)
        window.center()
        // Overwrite the bad autosaved frame so the next launch does not re-collapse.
        window.saveFrame(usingName: window.frameAutosaveName)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        navigationPlan.sections.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard navigationPlan.sections.indices.contains(row) else { return nil }
        let section = navigationPlan.sections[row]
        let identifier = NSUserInterfaceItemIdentifier("settings-navigation-cell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView ?? NSTableCellView()
        cell.identifier = identifier

        if cell.textField == nil {
            let label = NSTextField(labelWithString: "")
            label.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(label)
            cell.textField = label
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 12),
                label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }
        cell.textField?.stringValue = section.title
        cell.imageView?.image = NSImage(systemSymbolName: section.symbolName, accessibilityDescription: section.title)
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let table = notification.object as? NSTableView else { return }
        showSection(at: table.selectedRow)
    }

    private func showSection(at index: Int) {
        guard navigationPlan.sections.indices.contains(index), let container = sectionContentContainer else { return }
        let section = navigationPlan.sections[index]
        guard let view = sectionViews[section.id] else { return }
        container.subviews.forEach { $0.removeFromSuperview() }
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }

    private func makeSectionView(for id: SettingsNavigationSectionID) -> NSView {
        let section = navigationPlan.section(for: id)!
        let title = NSTextField(labelWithString: section.title)
        title.font = .systemFont(ofSize: 22, weight: .semibold)

        let contentViews: [NSView]
        switch id {
        case .general:
            contentViews = [makeGeneralTab(), makeZoomTab(), makeLiveZoomTab()]
        case .shortcuts:
            contentViews = [makeShortcutsView()]
        case .captureAndDraw:
            contentViews = [makeDrawTab(), makeTypeTab(), makeSnipTab()]
        case .recording:
            contentViews = [makeRecordTab()]
        case .permissions:
            let explanation = makeLabel(
                localized(
                    "settings.permissions.description",
                    "Review Screen Recording, Accessibility, Input Monitoring, microphone, and camera permissions."
                ),
                wraps: true
            )
            let button = NSButton(
                title: localized("settings.permissions.open_center", "Open Permission Center…"),
                target: self,
                action: #selector(openPermissionCenter)
            )
            button.bezelStyle = .rounded
            contentViews = [explanation, button]
        case .advanced:
            // App Store builds compile DemoType out, so the Advanced page must
            // not carry its tab, help text, file picker, or speed slider.
#if DORAZOOM_APP_STORE
            contentViews = [makeAdvancedCaptureView(), makeBreakTab(), makePanoramaTab(), makeAdvancedRecordingView()]
#else
            contentViews = [makeAdvancedCaptureView(), makeDemoTypeTab(), makeBreakTab(), makePanoramaTab(), makeAdvancedRecordingView()]
#endif
        }

        let stack = NSStackView(views: [title] + contentViews + [makeFooter()])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 22
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 28, bottom: 24, right: 28)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let document = SettingsDocumentView()
        document.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            stack.topAnchor.constraint(equalTo: document.topAnchor),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor),
            stack.widthAnchor.constraint(greaterThanOrEqualToConstant: Self.contentWidth)
        ])

        let scroll = NSScrollView()
        scroll.contentView = SettingsClipView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.drawsBackground = false
        document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document
        let clipView = scroll.contentView
        NSLayoutConstraint.activate([
            document.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            document.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
            document.topAnchor.constraint(equalTo: clipView.topAnchor),
            document.widthAnchor.constraint(equalTo: clipView.widthAnchor)
        ])
        return scroll
    }

    @objc private func openPermissionCenter() {
        onOpenPermissionCenter()
    }

    private func makeShortcutsView() -> NSView {
        let explanation = makeLabel(
            localized(
                "settings.shortcuts.description",
                "Click a shortcut, then enter a new key combination. Global shortcuts pause only while recording; press Escape to cancel."
            ),
            wraps: true
        )
        // App Store builds register no DemoType shortcut, so the row is omitted
        // rather than shown as a recorder that can never take effect.
        var rows: [[NSView]] = [
            [makeLabel(localized("settings.shortcuts.zoom", "Static Zoom:")), makeShortcutButton(zoomHotKeyDisplayString(), action: #selector(toggleZoomHotKeyRecording(_:)))],
            [makeLabel(localized("settings.shortcuts.draw", "Draw:")), makeShortcutButton(drawHotKeyDisplayString(), action: #selector(toggleDrawHotKeyRecording(_:)))],
            [makeLabel(localized("settings.shortcuts.live_zoom", "Live Zoom:")), makeShortcutButton(liveHotKeyDisplayString(), action: #selector(toggleLiveHotKeyRecording(_:)))],
            [makeLabel(localized("settings.shortcuts.snip", "Snip:")), makeShortcutButton(snipHotKeyDisplayString(), action: #selector(toggleSnipHotKeyRecording(_:)))],
            [makeLabel(localized("settings.shortcuts.ocr", "OCR:")), makeShortcutButton(snipOcrHotKeyDisplayString(), action: #selector(toggleSnipOcrHotKeyRecording(_:)))],
            [makeLabel(localized("settings.shortcuts.record", "Record:")), makeShortcutButton(recordHotKeyDisplayString(), action: #selector(toggleRecordHotKeyRecording(_:)))]
        ]
#if !DORAZOOM_APP_STORE
        rows.append([makeLabel(localized("settings.shortcuts.demo_type", "DemoType:")), makeShortcutButton(demoTypeHotKeyDisplayString(), action: #selector(toggleDemoTypeHotKeyRecording(_:)))])
#endif
        rows.append(contentsOf: [
            [makeLabel(localized("settings.shortcuts.panorama", "Panorama:")), makeShortcutButton(panoramaHotKeyDisplayString(), action: #selector(togglePanoramaHotKeyRecording(_:)))],
            [makeLabel(localized("settings.shortcuts.break_timer", "Break Timer:")), makeShortcutButton(breakHotKeyDisplayString(), action: #selector(toggleBreakHotKeyRecording(_:)))]
        ])
        return makeColumn([explanation, makeFormGrid(rows)], spacing: 16)
    }

    private func makeShortcutButton(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        return button
    }

    private func makeFooter() -> NSView {
        let title = makeLabel("\(AppInfo.productName) \(AppInfo.version)")
        title.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        title.textColor = .secondaryLabelColor
        title.alignment = .center

        let copyright = makeLabel(AppInfo.copyright)
        copyright.font = NSFont.systemFont(ofSize: 11)
        copyright.textColor = .secondaryLabelColor
        copyright.alignment = .center

        let links = NSStackView(views: [
            makeLinkButton("Privacy", action: #selector(openPrivacyPolicy(_:))),
            makeLinkButton("Terms", action: #selector(openTerms(_:))),
            makeLinkButton("Support", action: #selector(openSupport(_:)))
        ])
        links.orientation = .horizontal
        links.alignment = .centerY
        links.spacing = 12

        let stack = NSStackView(views: [title, copyright, links])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 2
        return stack
    }

    private func makeLinkButton(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        button.bezelStyle = .inline
        button.isBordered = false
        button.font = NSFont.systemFont(ofSize: 11)
        button.contentTintColor = .controlAccentColor
        button.target = self
        button.action = action
        return button
    }

    @objc private func openPrivacyPolicy(_ sender: Any?) {
        openExternalURL("https://dorazoom.iwalk.pro/privacy/")
    }

    @objc private func openTerms(_ sender: Any?) {
        openExternalURL("https://dorazoom.iwalk.pro/terms/")
    }

    @objc private func openSupport(_ sender: Any?) {
        openExternalURL("https://dorazoom.iwalk.pro/support/")
    }

    private func openExternalURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }

    private func makeColumn(_ rows: [NSView], spacing: CGFloat = 14) -> NSView {
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.edgeInsets = NSEdgeInsets(top: 8, left: Self.panelHorizontalInset, bottom: 12, right: Self.panelHorizontalInset)
        return stack
    }

    private func localized(_ key: String, _ defaultValue: String) -> String {
        AppLocalization.string(key, defaultValue: defaultValue)
    }

    private func makeLabel(_ text: String, wraps: Bool = false) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.translatesAutoresizingMaskIntoConstraints = false
        if wraps {
            field.lineBreakMode = .byWordWrapping
            field.maximumNumberOfLines = 0
            field.preferredMaxLayoutWidth = Self.wrappedLabelWidth
        }
        return field
    }

    private func makeSectionLabel(_ text: String) -> NSTextField {
        let field = makeLabel(text)
        field.font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        return field
    }

    private func makeRow(_ views: [NSView]) -> NSView {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        return stack
    }

    private func makeCheckbox(_ title: String, action: Selector, state: Bool) -> NSButton {
        let button = NSButton(checkboxWithTitle: title, target: self, action: action)
        button.imagePosition = .imageLeft
        button.state = state ? .on : .off
        return button
    }

    private func makeCheckboxColumn(_ checkboxes: [NSView], spacing: CGFloat = 6) -> NSView {
        let stack = NSStackView(views: checkboxes)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        return stack
    }

    private func makeIndentedColumn(_ rows: [NSView], indent: CGFloat = 18, spacing: CGFloat = 6) -> NSView {
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        stack.edgeInsets = NSEdgeInsets(top: 0, left: indent, bottom: 0, right: 0)
        return stack
    }

    /// Lays out label/control rows in a grid so the leading labels form a
    /// right-aligned column and the controls line up in consistent columns.
    /// Rows may have differing numbers of cells; trailing cells are left empty.
    private func makeFormGrid(_ rows: [[NSView]], rowSpacing: CGFloat = 10, columnSpacing: CGFloat = 8) -> NSGridView {
        let grid = NSGridView(views: rows)
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = rowSpacing
        grid.columnSpacing = columnSpacing
        // Center controls vertically within each row so labels line up with
        // popups, steppers and checkboxes regardless of their heights.
        grid.rowAlignment = .none
        for r in 0..<grid.numberOfRows {
            for c in 0..<grid.numberOfColumns {
                grid.cell(atColumnIndex: c, rowIndex: r).yPlacement = .center
            }
        }
        if grid.numberOfColumns > 0 {
            // Right-align the leading label column so the controls in column 1
            // share a common left edge.
            grid.column(at: 0).xPlacement = .trailing
        }
        return grid
    }

    // MARK: - General tab

    private func makeGeneralTab() -> NSView {
        let help = makeLabel(
            localized(
                "settings.general.description",
                "DoraZoom runs in the menu bar. Use the Zoom and Draw settings to choose the keyboard shortcuts that activate it."
            ),
            wraps: true
        )

        let launchCheck = NSButton(
            checkboxWithTitle: localized("settings.general.launch_at_login", "Launch DoraZoom when I log in"),
            target: self,
            action: #selector(toggleLaunchAtLogin(_:))
        )
        launchCheck.state = settings.launchAtLogin ? .on : .off
        launchCheck.isEnabled = LaunchAtLogin.isAvailable
        if !LaunchAtLogin.isAvailable {
            launchCheck.toolTip = LaunchAtLogin.unavailableMessage
        }
        launchAtLoginCheckbox = launchCheck

        return makeColumn([help, launchCheck])
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        let enable = sender.state == .on
        settings.launchAtLogin = enable
        persist()
        do {
            try LaunchAtLogin.setEnabled(enable)
        } catch {
            let alert = NSAlert()
            alert.messageText = localized("settings.general.login_item_error.title", "Couldn’t update the login item")
            alert.informativeText = AppLocalization.format(
                "settings.general.login_item_error.message",
                defaultValue: "DoraZoom saved your startup preference and will try again next launch. macOS reported: %@",
                error.localizedDescription
            )
            alert.addButton(withTitle: localized("common.ok", "OK"))
            alert.runModal()
        }
    }

    // MARK: - Zoom tab

    private func makeZoomTab() -> NSView {
        let help = makeLabel(
            localized(
                "settings.zoom.description",
                "After activating DoraZoom, zoom with the mouse wheel or Option+Up and Option+Down, then pan by moving the mouse. Exit zoom mode with Escape or the right mouse button."
            ),
            wraps: true
        )

        let hotKeyButton = NSButton(title: zoomHotKeyDisplayString(), target: self, action: #selector(toggleZoomHotKeyRecording(_:)))
        hotKeyButton.bezelStyle = .rounded
        hotKeyButton.setButtonType(.momentaryPushIn)
        hotKeyButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
        self.hotKeyButton = hotKeyButton
        let hotKeyRow = makeRow([makeLabel(localized("settings.zoom.shortcut", "Zoom shortcut:")), hotKeyButton])

        let magHelp = makeLabel(localized("settings.zoom.initial_magnification.help", "Choose the initial magnification level:"), wraps: true)

        let magPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        magPopup.translatesAutoresizingMaskIntoConstraints = false
        for level in AppSettings.zoomLevels {
            magPopup.addItem(withTitle: String(format: "%gx", level))
        }
        let selectedIndex = AppSettings.zoomLevels.firstIndex(where: {
            abs($0 - settings.defaultZoomFactor) < 0.001
        }) ?? AppSettings.zoomLevels.firstIndex(of: 2.0) ?? 0
        magPopup.selectItem(at: selectedIndex)
        magPopup.target = self
        magPopup.action = #selector(zoomLevelChanged(_:))
        let magRow = makeRow([makeLabel(localized("settings.zoom.initial_magnification", "Initial magnification:")), magPopup])

        let animateCheck = makeCheckbox(localized("settings.zoom.animate", "Animate zooming"), action: #selector(animateZoomChanged(_:)), state: settings.animateZoom)
        let smoothCheck = makeCheckbox(localized("settings.zoom.smooth_image", "Smooth the zoomed image"), action: #selector(smoothImageChanged(_:)), state: settings.smoothImage)

        return makeColumn([help, hotKeyRow, magHelp, magRow, makeCheckboxColumn([animateCheck, smoothCheck])])
    }

    // MARK: - Live Zoom tab

    private func makeLiveZoomTab() -> NSView {
        let liveHelp = makeLabel(
            localized(
                "settings.live_zoom.description",
                "Live Zoom magnifies the live screen, so motion and updates remain visible. Use the same zoom and pan controls."
            ),
            wraps: true
        )

        let liveHotKeyButton = NSButton(title: liveHotKeyDisplayString(), target: self, action: #selector(toggleLiveHotKeyRecording(_:)))
        liveHotKeyButton.bezelStyle = .rounded
        liveHotKeyButton.setButtonType(.momentaryPushIn)
        liveHotKeyButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
        self.liveHotKeyButton = liveHotKeyButton
        let liveHotKeyRow = makeRow([makeLabel(localized("settings.live_zoom.shortcut", "Live Zoom shortcut:")), liveHotKeyButton])

        return makeColumn([liveHelp, liveHotKeyRow])
    }

    @objc private func zoomLevelChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard AppSettings.zoomLevels.indices.contains(index) else { return }
        settings.defaultZoomFactor = AppSettings.zoomLevels[index]
        persist()
    }

    @objc private func animateZoomChanged(_ sender: NSButton) {
        settings.animateZoom = (sender.state == .on)
        persist()
    }

    @objc private func smoothImageChanged(_ sender: NSButton) {
        settings.smoothImage = (sender.state == .on)
        persist()
    }

    // MARK: - Hotkey recorder

    @objc private func toggleZoomHotKeyRecording(_ sender: NSButton) {
        beginRecording(target: .zoom, sender: sender)
    }

    @objc private func toggleDrawHotKeyRecording(_ sender: NSButton) {
        beginRecording(target: .draw, sender: sender)
    }

    @objc private func toggleLiveHotKeyRecording(_ sender: NSButton) {
        beginRecording(target: .live, sender: sender)
    }

    @objc private func toggleBreakHotKeyRecording(_ sender: NSButton) {
        beginRecording(target: .breakTimer, sender: sender)
    }

    @objc private func toggleSnipHotKeyRecording(_ sender: NSButton) {
        beginRecording(target: .snip, sender: sender)
    }

    @objc private func toggleSnipOcrHotKeyRecording(_ sender: NSButton) {
        beginRecording(target: .snipOcr, sender: sender)
    }

    @objc private func toggleRecordHotKeyRecording(_ sender: NSButton) {
        beginRecording(target: .record, sender: sender)
    }

#if !DORAZOOM_APP_STORE
    @objc private func toggleDemoTypeHotKeyRecording(_ sender: NSButton) {
        beginRecording(target: .demoType, sender: sender)
    }
#endif

    @objc private func togglePanoramaHotKeyRecording(_ sender: NSButton) {
        beginRecording(target: .panorama, sender: sender)
    }

    private func beginRecording(target: HotKeyTarget, sender: NSButton) {
        if recordingTarget != nil {
            // A recording is already in progress; clicking any recorder stops it.
            finishRecording()
            return
        }
        recordingTarget = target
        activeHotKeyButton = sender
        hotkeyCaptureSession.begin()
        sender.title = localized("settings.shortcuts.recording_prompt", "Type shortcut… (Esc cancels)")
        hotKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            return self.captureHotKey(event)
        }
    }

    private func captureHotKey(_ event: NSEvent) -> NSEvent? {
        if event.keyCode == 53 { // Escape cancels recording.
            finishRecording()
            return nil
        }

        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard !modifiers.isEmpty else {
            // A global hotkey needs at least one modifier.
            NSSound.beep()
            return nil
        }

        let newCode = Int(event.keyCode)
        let newModifiers = modifiers.rawValue

        switch recordingTarget {
        case .zoom:
            // Reject a shortcut already assigned to another ZoomIt hotkey.
            if conflictsWithDraw(code: newCode, modifiers: newModifiers) ||
                conflictsWithLive(code: newCode, modifiers: newModifiers) ||
                conflictsWithBreak(code: newCode, modifiers: newModifiers) ||
                conflictsWithDemoType(code: newCode, modifiers: newModifiers) {
                return rejectHotKeyConflict()
            }
            settings.hotKeyCode = newCode
            settings.hotKeyModifiers = newModifiers
        case .draw:
            if conflictsWithZoom(code: newCode, modifiers: newModifiers) ||
                conflictsWithLive(code: newCode, modifiers: newModifiers) ||
                conflictsWithBreak(code: newCode, modifiers: newModifiers) ||
                conflictsWithDemoType(code: newCode, modifiers: newModifiers) {
                return rejectHotKeyConflict()
            }
            settings.drawHotKeyCode = newCode
            settings.drawHotKeyModifiers = newModifiers
        case .live:
            if conflictsWithZoom(code: newCode, modifiers: newModifiers) ||
                conflictsWithDraw(code: newCode, modifiers: newModifiers) ||
                conflictsWithBreak(code: newCode, modifiers: newModifiers) ||
                conflictsWithDemoType(code: newCode, modifiers: newModifiers) {
                return rejectHotKeyConflict()
            }
            settings.liveHotKeyCode = newCode
            settings.liveHotKeyModifiers = newModifiers
        case .breakTimer:
            if conflictsWithZoom(code: newCode, modifiers: newModifiers) ||
                conflictsWithDraw(code: newCode, modifiers: newModifiers) ||
                conflictsWithLive(code: newCode, modifiers: newModifiers) ||
                conflictsWithSnip(code: newCode, modifiers: newModifiers) ||
                conflictsWithRecord(code: newCode, modifiers: newModifiers) ||
                conflictsWithDemoType(code: newCode, modifiers: newModifiers) ||
                conflictsWithPanorama(code: newCode, modifiers: newModifiers) {
                return rejectHotKeyConflict()
            }
            settings.breakHotKeyCode = newCode
            settings.breakHotKeyModifiers = newModifiers
        case .snip:
            if conflictsWithZoom(code: newCode, modifiers: newModifiers) ||
                conflictsWithDraw(code: newCode, modifiers: newModifiers) ||
                conflictsWithLive(code: newCode, modifiers: newModifiers) ||
                conflictsWithBreak(code: newCode, modifiers: newModifiers) ||
                conflictsWithDemoType(code: newCode, modifiers: newModifiers) {
                return rejectHotKeyConflict()
            }
            settings.snipHotKeyCode = newCode
            settings.snipHotKeyModifiers = newModifiers
        case .snipOcr:
            if conflictsWithZoom(code: newCode, modifiers: newModifiers) ||
                conflictsWithDraw(code: newCode, modifiers: newModifiers) ||
                conflictsWithLive(code: newCode, modifiers: newModifiers) ||
                conflictsWithBreak(code: newCode, modifiers: newModifiers) ||
                conflictsWithSnip(code: newCode, modifiers: newModifiers) ||
                conflictsWithDemoType(code: newCode, modifiers: newModifiers) {
                return rejectHotKeyConflict()
            }
            settings.snipOcrHotKeyCode = newCode
            settings.snipOcrHotKeyModifiers = newModifiers
        case .record:
            if conflictsWithZoom(code: newCode, modifiers: newModifiers) ||
                conflictsWithDraw(code: newCode, modifiers: newModifiers) ||
                conflictsWithLive(code: newCode, modifiers: newModifiers) ||
                conflictsWithBreak(code: newCode, modifiers: newModifiers) ||
                conflictsWithDemoType(code: newCode, modifiers: newModifiers) {
                return rejectHotKeyConflict()
            }
            settings.recordHotKeyCode = newCode
            settings.recordHotKeyModifiers = newModifiers
#if !DORAZOOM_APP_STORE
        case .demoType:
            if conflictsWithZoom(code: newCode, modifiers: newModifiers) ||
                conflictsWithDraw(code: newCode, modifiers: newModifiers) ||
                conflictsWithLive(code: newCode, modifiers: newModifiers) ||
                conflictsWithBreak(code: newCode, modifiers: newModifiers) ||
                conflictsWithSnip(code: newCode, modifiers: newModifiers) ||
                conflictsWithSnipOcr(code: newCode, modifiers: newModifiers) ||
                conflictsWithRecord(code: newCode, modifiers: newModifiers) ||
                conflictsWithPanorama(code: newCode, modifiers: newModifiers) {
                return rejectHotKeyConflict()
            }
            settings.demoTypeHotKeyCode = newCode
            settings.demoTypeHotKeyModifiers = newModifiers
#endif
        case .panorama:
            if conflictsWithZoom(code: newCode, modifiers: newModifiers) ||
                conflictsWithDraw(code: newCode, modifiers: newModifiers) ||
                conflictsWithLive(code: newCode, modifiers: newModifiers) ||
                conflictsWithBreak(code: newCode, modifiers: newModifiers) ||
                conflictsWithDemoType(code: newCode, modifiers: newModifiers) {
                return rejectHotKeyConflict()
            }
            settings.panoramaHotKeyCode = newCode
            settings.panoramaHotKeyModifiers = newModifiers
        case nil:
            return nil
        }
        persist()
        finishRecording()
        onHotKeyChange()
        return nil
    }

    private func rejectHotKeyConflict() -> NSEvent? {
        NSSound.beep()
        finishRecording()
        return nil
    }

    private func conflictsWithZoom(code: Int, modifiers: UInt) -> Bool {
        code == settings.hotKeyCode && modifiers == settings.hotKeyModifiers
    }

    private func conflictsWithDraw(code: Int, modifiers: UInt) -> Bool {
        code == settings.drawHotKeyCode && modifiers == settings.drawHotKeyModifiers
    }

    private func conflictsWithLive(code: Int, modifiers: UInt) -> Bool {
        code == settings.liveHotKeyCode && modifiers == settings.liveHotKeyModifiers
    }

    private func conflictsWithBreak(code: Int, modifiers: UInt) -> Bool {
        code == settings.breakHotKeyCode && modifiers == settings.breakHotKeyModifiers
    }

    private func conflictsWithSnip(code: Int, modifiers: UInt) -> Bool {
        code == settings.snipHotKeyCode && modifiers == settings.snipHotKeyModifiers
    }

    private func conflictsWithSnipOcr(code: Int, modifiers: UInt) -> Bool {
        settings.snipOcrHotKeyCode != 0 &&
            code == settings.snipOcrHotKeyCode && modifiers == settings.snipOcrHotKeyModifiers
    }

    private func conflictsWithRecord(code: Int, modifiers: UInt) -> Bool {
        code == settings.recordHotKeyCode && modifiers == settings.recordHotKeyModifiers
    }

    private func conflictsWithDemoType(code: Int, modifiers: UInt) -> Bool {
#if DORAZOOM_APP_STORE
        // App Store builds register no DemoType shortcut, so DemoType owns no
        // key combination and cannot conflict with one. Reporting a conflict
        // here would block a shortcut that is actually free.
        return false
#else
        settings.demoTypeHotKeyCode != 0 &&
            code == settings.demoTypeHotKeyCode && modifiers == settings.demoTypeHotKeyModifiers
#endif
    }

    private func conflictsWithPanorama(code: Int, modifiers: UInt) -> Bool {
        code == settings.panoramaHotKeyCode && modifiers == settings.panoramaHotKeyModifiers
    }

    private func finishRecording() {
        let finishedTarget = recordingTarget
        if let hotKeyMonitor {
            NSEvent.removeMonitor(hotKeyMonitor)
        }
        hotKeyMonitor = nil
        recordingTarget = nil
        hotkeyCaptureSession.finish()
        if let finishedTarget {
            activeHotKeyButton?.title = hotKeyDisplayString(for: finishedTarget)
        }
        activeHotKeyButton = nil
        hotKeyButton?.title = zoomHotKeyDisplayString()
        drawHotKeyButton?.title = drawHotKeyDisplayString()
        liveHotKeyButton?.title = liveHotKeyDisplayString()
        breakHotKeyButton?.title = breakHotKeyDisplayString()
        snipHotKeyButton?.title = snipHotKeyDisplayString()
        snipOcrHotKeyButton?.title = snipOcrHotKeyDisplayString()
        recordHotKeyButton?.title = recordHotKeyDisplayString()
#if !DORAZOOM_APP_STORE
        demoTypeHotKeyButton?.title = demoTypeHotKeyDisplayString()
#endif
        panoramaHotKeyButton?.title = panoramaHotKeyDisplayString()
    }

    private func hotKeyDisplayString(for target: HotKeyTarget) -> String {
        switch target {
        case .zoom: zoomHotKeyDisplayString()
        case .draw: drawHotKeyDisplayString()
        case .live: liveHotKeyDisplayString()
        case .breakTimer: breakHotKeyDisplayString()
        case .snip: snipHotKeyDisplayString()
        case .snipOcr: snipOcrHotKeyDisplayString()
        case .record: recordHotKeyDisplayString()
#if !DORAZOOM_APP_STORE
        case .demoType: demoTypeHotKeyDisplayString()
#endif
        case .panorama: panoramaHotKeyDisplayString()
        }
    }

    private func zoomHotKeyDisplayString() -> String {
        Self.describe(keyCode: settings.hotKeyCode, modifiers: NSEvent.ModifierFlags(rawValue: settings.hotKeyModifiers))
    }

    private func drawHotKeyDisplayString() -> String {
        Self.describe(keyCode: settings.drawHotKeyCode, modifiers: NSEvent.ModifierFlags(rawValue: settings.drawHotKeyModifiers))
    }

    private func liveHotKeyDisplayString() -> String {
        Self.describe(keyCode: settings.liveHotKeyCode, modifiers: NSEvent.ModifierFlags(rawValue: settings.liveHotKeyModifiers))
    }

    private func breakHotKeyDisplayString() -> String {
        Self.describe(keyCode: settings.breakHotKeyCode, modifiers: NSEvent.ModifierFlags(rawValue: settings.breakHotKeyModifiers))
    }

    private func snipHotKeyDisplayString() -> String {
        Self.describe(keyCode: settings.snipHotKeyCode, modifiers: NSEvent.ModifierFlags(rawValue: settings.snipHotKeyModifiers))
    }

    private func snipOcrHotKeyDisplayString() -> String {
        guard settings.snipOcrHotKeyCode != 0 else { return localized("common.none", "None") }
        return Self.describe(keyCode: settings.snipOcrHotKeyCode, modifiers: NSEvent.ModifierFlags(rawValue: settings.snipOcrHotKeyModifiers))
    }

    private func recordHotKeyDisplayString() -> String {
        Self.describe(keyCode: settings.recordHotKeyCode, modifiers: NSEvent.ModifierFlags(rawValue: settings.recordHotKeyModifiers))
    }

#if !DORAZOOM_APP_STORE
    private func demoTypeHotKeyDisplayString() -> String {
        guard settings.demoTypeHotKeyCode != 0 else { return localized("common.none", "None") }
        return Self.describe(keyCode: settings.demoTypeHotKeyCode, modifiers: NSEvent.ModifierFlags(rawValue: settings.demoTypeHotKeyModifiers))
    }
#endif

    private func panoramaHotKeyDisplayString() -> String {
        Self.describe(keyCode: settings.panoramaHotKeyCode, modifiers: NSEvent.ModifierFlags(rawValue: settings.panoramaHotKeyModifiers))
    }

    // MARK: - Draw tab

    private func makeDrawTab() -> NSView {
        let help = makeLabel(
            localized(
                "settings.draw.description",
                "While zoomed, press the left mouse button to start drawing and the right mouse button to stop. Undo with Command-Z or Control-Z, and press E to erase all drawing."
            ),
            wraps: true
        )

        let penSection = makeSectionLabel(localized("settings.draw.pen.title", "Pen Control"))
        let penHelp = makeLabel(
            localized(
                "settings.draw.pen.description",
                "Change pen width with the mouse wheel, the [ and ] keys, or Shift with the Up and Down Arrow keys."
            ),
            wraps: true
        )

        let colorsSection = makeSectionLabel(localized("settings.draw.colors.title", "Colors"))
        let colorsHelp = makeLabel(
            DrawingShortcutGuide.colors,
            wraps: true
        )

        let highlightSection = makeSectionLabel(localized("settings.draw.highlight.title", "Highlight"))
        let highlightHelp = makeLabel(
            localized(
                "settings.draw.highlight.description",
                "Hold Shift with a color key, such as Shift+R, to draw with a translucent highlighter. Press the color key again without Shift to return to a solid pen."
            ),
            wraps: true
        )

        let privacySection = makeSectionLabel(localized("settings.draw.privacy_tools.title", "Privacy Tools"))
        let privacyHelp = makeLabel(
            localized(
                "settings.draw.privacy_tools.description",
                "Press M for the blur pen, X for a solid redaction, or N to add an automatically numbered marker. These remain only in the current drawing session and are composited into copied or recorded pixels. Undo with Command-Z or Control-Z before sharing."
            ),
            wraps: true
        )

        let shapesSection = makeSectionLabel(localized("settings.draw.shapes.title", "Shapes"))
        let shapesHelp = makeLabel(
            localized(
                "settings.draw.shapes.description",
                "While dragging, hold Shift for a line, Control for a rectangle, Tab for an ellipse, or Shift+Control for an arrow."
            ),
            wraps: true
        )

        let screenSection = makeSectionLabel(localized("settings.draw.screen.title", "Screen"))
        let screenHelp = makeLabel(
            DrawingShortcutGuide.canvas,
            wraps: true
        )

        let drawHotKeyButton = NSButton(title: drawHotKeyDisplayString(), target: self, action: #selector(toggleDrawHotKeyRecording(_:)))
        drawHotKeyButton.bezelStyle = .rounded
        drawHotKeyButton.setButtonType(.momentaryPushIn)
        drawHotKeyButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
        self.drawHotKeyButton = drawHotKeyButton
        let drawHotKeyRow = makeRow([makeLabel(localized("settings.draw.shortcut", "Draw without zoom:")), drawHotKeyButton])

        return makeColumn([
            help,
            penSection,
            makeIndentedColumn([penHelp]),
            colorsSection,
            makeIndentedColumn([colorsHelp]),
            highlightSection,
            makeIndentedColumn([highlightHelp]),
            privacySection,
            makeIndentedColumn([privacyHelp]),
            shapesSection,
            makeIndentedColumn([shapesHelp]),
            screenSection,
            makeIndentedColumn([screenHelp]),
            drawHotKeyRow
        ], spacing: 6)
    }

    // MARK: - Type tab

    private func makeTypeTab() -> NSView {
        let help = makeLabel(
            DrawingShortcutGuide.text + " " + localized("settings.type.color_note", "Text uses the current pen color."),
            wraps: true
        )

        let sample = makeLabel("")
        fontSampleLabel = sample
        updateFontSample()

        let fontButton = NSButton(title: localized("settings.type.select_font", "Select Font…"), target: self, action: #selector(selectFont(_:)))
        fontButton.bezelStyle = .rounded

        let fontRow = makeRow([makeLabel(localized("settings.type.font", "Typing font:")), fontButton])

        return makeColumn([help, fontRow, sample])
    }

    // MARK: - Break tab

    private func makeBreakTab() -> NSView {
        let help = makeLabel(
            localized(
                "settings.break_timer.description",
                "Press the break timer shortcut to show a full-screen countdown. Use the Arrow keys or mouse wheel to adjust the time, color keys to change the timer color, and Escape or right-click to exit."
            ),
            wraps: true
        )

        let hotKeyButton = NSButton(title: breakHotKeyDisplayString(), target: self, action: #selector(toggleBreakHotKeyRecording(_:)))
        hotKeyButton.bezelStyle = .rounded
        hotKeyButton.setButtonType(.momentaryPushIn)
        hotKeyButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
        breakHotKeyButton = hotKeyButton

        let durationStepper = NSStepper()
        durationStepper.minValue = 1
        durationStepper.maxValue = 99
        durationStepper.integerValue = settings.breakDurationMinutes
        durationStepper.increment = 1
        durationStepper.target = self
        durationStepper.action = #selector(breakDurationChanged(_:))
        let durationLabel = makeLabel("")
        breakDurationLabel = durationLabel
        updateBreakDurationLabel()
        let durationControls = makeRow([durationStepper, durationLabel])

        let expiredCheck = makeCheckbox(localized("settings.break_timer.show_elapsed", "Show elapsed time after expiration"), action: #selector(breakShowExpiredChanged(_:)), state: settings.breakShowExpiredTime)

        let textColorPopup = makeColorPopup(selected: settings.breakTextColorRGB, action: #selector(breakTextColorChanged(_:)))
        let backgroundColorPopup = makeColorPopup(selected: settings.breakBackgroundColorRGB, action: #selector(breakBackgroundColorChanged(_:)))

        let positionPopup = makeIndexedPopup(
            titles: [
                localized("position.top_left", "Top Left"),
                localized("position.top", "Top"),
                localized("position.top_right", "Top Right"),
                localized("position.left", "Left"),
                localized("position.center", "Center"),
                localized("position.right", "Right"),
                localized("position.bottom_left", "Bottom Left"),
                localized("position.bottom", "Bottom"),
                localized("position.bottom_right", "Bottom Right")
            ],
            selected: settings.breakTimerPosition,
            action: #selector(breakPositionChanged(_:))
        )
        positionPopup.widthAnchor.constraint(equalToConstant: 150).isActive = true
        let opacityPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        opacityPopup.translatesAutoresizingMaskIntoConstraints = false
        for value in stride(from: 10, through: 100, by: 10) {
            opacityPopup.addItem(withTitle: "\(value)%")
            opacityPopup.lastItem?.representedObject = value
        }
        opacityPopup.selectItem(withTitle: "\(min(max(settings.breakOpacity, 10), 100))%")
        opacityPopup.target = self
        opacityPopup.action = #selector(breakOpacityChanged(_:))

        let soundCheck = makeCheckbox(localized("settings.break_timer.play_sound", "Play a sound on expiration"), action: #selector(breakPlaySoundChanged(_:)), state: settings.breakPlaySound)
        let soundField = makePathField(settings.breakSoundFile)
        breakSoundFileField = soundField
        let soundBrowse = NSButton(title: localized("common.browse", "Browse…"), target: self, action: #selector(chooseBreakSoundFile(_:)))
        soundBrowse.bezelStyle = .rounded

        let backgroundModePopup = makeIndexedPopup(
            titles: [
                localized("settings.break_timer.backdrop.none", "No Image"),
                localized("settings.break_timer.backdrop.faded_desktop", "Faded Desktop"),
                localized("settings.break_timer.backdrop.image_file", "Image File")
            ],
            selected: settings.breakBackgroundMode,
            action: #selector(breakBackgroundModeChanged(_:))
        )
        breakBackgroundModePopup = backgroundModePopup
        backgroundModePopup.widthAnchor.constraint(equalToConstant: 150).isActive = true
        let backgroundField = makePathField(settings.breakBackgroundFile)
        breakBackgroundFileField = backgroundField
        let backgroundBrowse = NSButton(title: localized("common.browse", "Browse…"), target: self, action: #selector(chooseBreakBackgroundFile(_:)))
        backgroundBrowse.bezelStyle = .rounded
        breakBackgroundBrowseButton = backgroundBrowse
        let stretchCheck = makeCheckbox(localized("settings.break_timer.scale_to_screen", "Scale to screen"), action: #selector(breakBackgroundStretchChanged(_:)), state: settings.breakBackgroundStretch)
        breakBackgroundStretchCheckbox = stretchCheck

        // A single grid keeps every label/control pair in aligned columns:
        // column 0 = right-aligned labels, column 1 = primary control,
        // column 2 = secondary label, column 3 = secondary control.
        let grid = makeFormGrid([
            [makeLabel(localized("settings.break_timer.shortcut", "Start timer:")), hotKeyButton, makeLabel(localized("settings.break_timer.duration", "Duration:")), durationControls],
            [makeLabel(localized("settings.break_timer.timer_color", "Timer color:")), textColorPopup, makeLabel(localized("settings.break_timer.background_color", "Background:")), backgroundColorPopup],
            [makeLabel(localized("settings.break_timer.position", "Position:")), positionPopup, makeLabel(localized("settings.break_timer.opacity", "Opacity:")), opacityPopup],
            [makeLabel(localized("settings.break_timer.backdrop", "Backdrop:")), backgroundModePopup, stretchCheck],
            [makeLabel(localized("settings.break_timer.image_file", "Image file:")), backgroundField, backgroundBrowse],
            [makeLabel(localized("settings.break_timer.sound", "Sound:")), soundField, soundBrowse]
        ])

        updateBreakBackgroundControlsEnabled()
        return makeColumn([
            help,
            grid,
            makeCheckboxColumn([expiredCheck, soundCheck])
        ], spacing: 12)
    }

    private func updateBreakDurationLabel() {
        let key = settings.breakDurationMinutes == 1
            ? "settings.break_timer.minute"
            : "settings.break_timer.minutes"
        let defaultValue = settings.breakDurationMinutes == 1
            ? "%d minute"
            : "%d minutes"
        breakDurationLabel?.stringValue = AppLocalization.format(
            key,
            defaultValue: defaultValue,
            settings.breakDurationMinutes
        )
    }

    private func makePathField(_ path: String) -> NSTextField {
        let field = NSTextField(labelWithString: path.isEmpty ? localized("common.no_file_selected", "No file selected") : path)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.lineBreakMode = .byTruncatingMiddle
        field.widthAnchor.constraint(equalToConstant: 220).isActive = true
        return field
    }

    private func makeColorPopup(selected: UInt32, action: Selector) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.translatesAutoresizingMaskIntoConstraints = false
        for option in Self.breakColorOptions {
            popup.addItem(withTitle: localized(option.key, option.defaultName))
            popup.lastItem?.representedObject = Int(option.rgb)
        }
        let selectedIndex = Self.breakColorOptions.firstIndex { $0.rgb == selected } ?? 0
        popup.selectItem(at: selectedIndex)
        popup.target = self
        popup.action = action
        return popup
    }

    private func updateBreakBackgroundControlsEnabled() {
        let usesImageFile = settings.breakBackgroundMode == 2
        breakBackgroundFileField?.isEnabled = usesImageFile
        breakBackgroundBrowseButton?.isEnabled = usesImageFile
        breakBackgroundStretchCheckbox?.isEnabled = usesImageFile
    }

    @objc private func breakDurationChanged(_ sender: NSStepper) {
        settings.breakDurationMinutes = min(max(sender.integerValue, 1), 99)
        updateBreakDurationLabel()
        persist()
    }

    @objc private func breakShowExpiredChanged(_ sender: NSButton) {
        settings.breakShowExpiredTime = sender.state == .on
        persist()
    }

    @objc private func breakTextColorChanged(_ sender: NSPopUpButton) {
        settings.breakTextColorRGB = UInt32((sender.selectedItem?.representedObject as? Int) ?? Int(settings.breakTextColorRGB))
        persist()
    }

    @objc private func breakBackgroundColorChanged(_ sender: NSPopUpButton) {
        settings.breakBackgroundColorRGB = UInt32((sender.selectedItem?.representedObject as? Int) ?? Int(settings.breakBackgroundColorRGB))
        persist()
    }

    @objc private func breakPositionChanged(_ sender: NSPopUpButton) {
        settings.breakTimerPosition = sender.indexOfSelectedItem
        persist()
    }

    @objc private func breakOpacityChanged(_ sender: NSPopUpButton) {
        settings.breakOpacity = (sender.selectedItem?.representedObject as? Int) ?? settings.breakOpacity
        persist()
    }

    @objc private func breakPlaySoundChanged(_ sender: NSButton) {
        settings.breakPlaySound = sender.state == .on
        persist()
    }

    @objc private func chooseBreakSoundFile(_ sender: NSButton) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio]
        panel.title = localized("settings.break_timer.sound_picker.title", "DoraZoom: Choose Sound File")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settings.breakSoundFile = url.path
        breakSoundFileField?.stringValue = url.path
        persist()
    }

    @objc private func breakBackgroundModeChanged(_ sender: NSPopUpButton) {
        settings.breakBackgroundMode = sender.indexOfSelectedItem
        updateBreakBackgroundControlsEnabled()
        persist()
    }

    @objc private func chooseBreakBackgroundFile(_ sender: NSButton) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        panel.title = localized("settings.break_timer.background_picker.title", "DoraZoom: Choose Background Image")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settings.breakBackgroundFile = url.path
        breakBackgroundFileField?.stringValue = url.path
        persist()
    }

    @objc private func breakBackgroundStretchChanged(_ sender: NSButton) {
        settings.breakBackgroundStretch = sender.state == .on
        persist()
    }

    private static let breakColorOptions: [(key: String, defaultName: String, rgb: UInt32)] = [
        ("color.red", "Red", 0xFF0000),
        ("color.green", "Green", 0x00FF00),
        ("color.blue", "Blue", 0x0000FF),
        ("color.orange", "Orange", 0xFFA500),
        ("color.yellow", "Yellow", 0xFFFF00),
        ("color.pink", "Pink", 0xFF69B4),
        ("color.white", "White", 0xFFFFFF),
        ("color.black", "Black", 0x000000)
    ]

    // MARK: - Snip tab

    private func makeSnipTab() -> NSView {
        let help = makeLabel(
            localized(
                "settings.snip.description",
                """
            While zoomed, press Command+S to save the entire viewport to a file or Command+C to copy it to the clipboard.

            To capture part of the screen at any time, press the snip shortcut and drag a rectangle. Releasing the drag copies the selected region to the clipboard. Hold Shift with the shortcut to save the region to a file instead. Press Escape to cancel.

            The OCR shortcut works the same way, but recognizes the text in the selected region and copies that text to the clipboard.

            Saved images are PNG files named with the current date and time.
            """
            ),
            wraps: true
        )

        let snipHotKeyButton = NSButton(title: snipHotKeyDisplayString(), target: self, action: #selector(toggleSnipHotKeyRecording(_:)))
        snipHotKeyButton.bezelStyle = .rounded
        snipHotKeyButton.setButtonType(.momentaryPushIn)
        snipHotKeyButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
        self.snipHotKeyButton = snipHotKeyButton
        let snipHotKeyRow = makeRow([makeLabel(localized("settings.snip.shortcut", "Snip shortcut:")), snipHotKeyButton])

        let snipOcrHotKeyButton = NSButton(title: snipOcrHotKeyDisplayString(), target: self, action: #selector(toggleSnipOcrHotKeyRecording(_:)))
        snipOcrHotKeyButton.bezelStyle = .rounded
        snipOcrHotKeyButton.setButtonType(.momentaryPushIn)
        snipOcrHotKeyButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
        self.snipOcrHotKeyButton = snipOcrHotKeyButton
        let snipOcrHotKeyRow = makeRow([makeLabel(localized("settings.snip.ocr_shortcut", "OCR shortcut:")), snipOcrHotKeyButton])

        let copyOnSaveCheck = makeCheckbox(
            localized("settings.snip.copy_when_saving", "Also copy to the clipboard when saving a file"),
            action: #selector(copySnipToClipboardOnSaveChanged(_:)),
            state: settings.copySnipToClipboardOnSave
        )

        let saveToDirectoryCheck = makeCheckbox(
            localized("settings.snip.save_to_folder", "Save to a folder instead of asking each time"),
            action: #selector(saveSnipToDirectoryChanged(_:)),
            state: settings.saveSnipToDirectory
        )

        let directoryField = NSTextField(labelWithString: snipSaveDirectoryDisplayPath())
        directoryField.translatesAutoresizingMaskIntoConstraints = false
        directoryField.lineBreakMode = .byTruncatingMiddle
        directoryField.widthAnchor.constraint(equalToConstant: 380).isActive = true
        snipSaveDirectoryField = directoryField
        let directoryBrowse = NSButton(title: localized("common.browse", "Browse…"), target: self, action: #selector(chooseSnipSaveDirectory(_:)))
        directoryBrowse.bezelStyle = .rounded
        snipSaveDirectoryBrowseButton = directoryBrowse
        let directoryRow = makeIndentedColumn([makeRow([makeLabel(localized("settings.snip.folder", "Folder:")), directoryField, directoryBrowse])])

        updateSnipSaveDirectoryControlsEnabled()

        return makeColumn([help, snipHotKeyRow, snipOcrHotKeyRow, makeCheckboxColumn([copyOnSaveCheck, saveToDirectoryCheck]), directoryRow])
    }

    private func snipSaveDirectoryDisplayPath() -> String {
        if settings.snipSaveDirectory.trimmingCharacters(in: .whitespaces).isEmpty {
            return ImageExporter.defaultSaveDirectory().path
        }
        return settings.snipSaveDirectory
    }

    private func updateSnipSaveDirectoryControlsEnabled() {
        snipSaveDirectoryField?.isEnabled = settings.saveSnipToDirectory
        snipSaveDirectoryBrowseButton?.isEnabled = settings.saveSnipToDirectory
    }

    @objc private func copySnipToClipboardOnSaveChanged(_ sender: NSButton) {
        settings.copySnipToClipboardOnSave = (sender.state == .on)
        persist()
    }

    @objc private func saveSnipToDirectoryChanged(_ sender: NSButton) {
        settings.saveSnipToDirectory = (sender.state == .on)
        updateSnipSaveDirectoryControlsEnabled()
        persist()
    }

    @objc private func chooseSnipSaveDirectory(_ sender: NSButton) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = localized("common.choose", "Choose")
        panel.title = localized("settings.snip.folder_picker.title", "DoraZoom: Choose Snip Folder")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        applyChosenSaveDirectory(url)
    }

    /// Applies a folder the user just picked in the open panel.
    ///
    /// The chosen path is stored for display, but the path alone is not an
    /// authorization: under the sandbox it stops working after a relaunch. The
    /// security-scoped bookmark recorded here is what actually carries the
    /// grant. Split out of the panel handler so this path stays testable.
    func applyChosenSaveDirectory(_ url: URL) {
        settings.snipSaveDirectory = url.path
        snipSaveDirectoryField?.stringValue = url.path
        do {
            _ = try fileAccess.grantAccess(to: url)
        } catch {
            presentSaveDirectoryGrantFailure()
        }
        persist()
    }

    private func presentSaveDirectoryGrantFailure() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = localized(
            "settings.snip.folder_grant_failed.title",
            "DoraZoom could not remember this folder"
        )
        alert.informativeText = localized(
            "settings.snip.folder_grant_failed.message",
            "DoraZoom could not record a lasting permission for this folder, so saving into it may stop working after DoraZoom restarts. Choose a folder inside your home folder, or let DoraZoom ask where to save each time."
        )
        alert.addButton(withTitle: localized("common.ok", "OK"))
        alert.runModal()
    }

    // MARK: - Record tab

    private func makeRecordTab() -> NSView {
        let help = makeLabel(
            localized(
                "settings.record.description",
                """
            Press the record shortcut to record the whole screen to a MOV file; hold Shift with the shortcut to drag a rectangle and record just that region. Press the shortcut again to stop, then choose where to save the recording.

            Enable system audio to capture what you hear, and choose a microphone to also record your voice. Microphone recording requires the bundled app and microphone permission.
            """
            ),
            wraps: true
        )

        let recordHotKeyButton = NSButton(title: recordHotKeyDisplayString(), target: self, action: #selector(toggleRecordHotKeyRecording(_:)))
        recordHotKeyButton.bezelStyle = .rounded
        recordHotKeyButton.setButtonType(.momentaryPushIn)
        recordHotKeyButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
        self.recordHotKeyButton = recordHotKeyButton
        let recordHotKeyRow = makeRow([makeLabel(localized("settings.record.shortcut", "Record shortcut:")), recordHotKeyButton])

        let systemAudioCheck = makeCheckbox(localized("settings.record.system_audio", "Capture system audio"), action: #selector(recordSystemAudioChanged(_:)), state: settings.recordSystemAudio)

        let micCheck = makeCheckbox(localized("settings.record.microphone", "Capture microphone audio"), action: #selector(recordMicrophoneChanged(_:)), state: settings.recordMicrophone)

        let clickCheck = makeCheckbox(
            localized("settings.record.mouse_clicks", "Show mouse clicks"),
            action: #selector(recordMouseClicksChanged(_:)),
            state: settings.recordMouseClicks
        )
        let shortcutCheck = makeCheckbox(
            localized("settings.record.shortcut_keys", "Show shortcuts (never ordinary typing)"),
            action: #selector(recordShortcutKeysChanged(_:)),
            state: settings.recordShortcutKeys
        )

        let windNoiseCheck = makeCheckbox(localized("settings.record.noise_cancellation", "Noise cancellation"), action: #selector(recordNoiseCancellationChanged(_:)), state: settings.recordNoiseCancellation)
        noiseCancellationCheckbox = windNoiseCheck

        let micPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        micPopup.translatesAutoresizingMaskIntoConstraints = false
        let microphones = AudioDevices.availableMicrophones()
        var selectedIndex = 0
        for (index, device) in microphones.enumerated() {
            micPopup.addItem(withTitle: device.name)
            micPopup.lastItem?.representedObject = device.id
            if device.id == settings.microphoneDeviceID {
                selectedIndex = index
            }
        }
        micPopup.selectItem(at: selectedIndex)
        micPopup.target = self
        micPopup.action = #selector(microphoneChanged(_:))
        micPopup.isEnabled = settings.recordMicrophone
        micPopup.widthAnchor.constraint(equalToConstant: 220).isActive = true
        microphonePopup = micPopup
        let micDeviceRow = makeRow([makeLabel(localized("settings.record.microphone_device", "Microphone:")), micPopup])
        let micOptions = makeIndentedColumn([windNoiseCheck, micDeviceRow])
        updateMicrophoneOptionControls()

        return makeColumn([
            help,
            recordHotKeyRow,
            makeCheckboxColumn([systemAudioCheck, micCheck, clickCheck, shortcutCheck]),
            micOptions
        ], spacing: 10)
    }

    private func makeAdvancedRecordingView() -> NSView {
        let heading = makeSectionLabel(localized("settings.advanced_recording.title", "Advanced Recording"))
        let format = makeLabel(
            localized(
                "settings.advanced_recording.description",
                "Standard recordings use MOV / H.264 / AAC. MP4, GIF, and more complex editing are available in the advanced workflow."
            ),
            wraps: true
        )
        let trimButton = NSButton(title: localized("settings.advanced_recording.open_editor", "Open Advanced Editor…"), target: self, action: #selector(openTrimEditor(_:)))
        trimButton.bezelStyle = .rounded
        let trimRow = makeRow([makeLabel(localized("settings.advanced_recording.edit_video", "Edit an existing video:")), trimButton])
        return makeColumn([heading, format] + makeWebcamRows() + [trimRow], spacing: 10)
    }

    private func makeAdvancedCaptureView() -> NSView {
        let heading = makeSectionLabel(localized("settings.advanced_capture.title", "Advanced Capture"))
        let explanation = makeLabel(
            localized(
                "settings.advanced_capture.description",
                "Capture Window Under Pointer copies the frontmost standard window beneath the pointer without creating a local file."
            ),
            wraps: true
        )
        let shadow = makeCheckbox(
            localized("settings.advanced_capture.include_shadow", "Include window shadow"),
            action: #selector(includeWindowShadowChanged(_:)),
            state: settings.includeWindowShadow
        )
        return makeColumn([heading, explanation, makeCheckboxColumn([shadow])], spacing: 10)
    }

    @objc private func includeWindowShadowChanged(_ sender: NSButton) {
        settings.includeWindowShadow = sender.state == .on
        persist()
    }

    // MARK: - Panorama tab

    private func makePanoramaTab() -> NSView {
        let help = makeLabel(
            localized(
                "settings.panorama.description",
                """
            Press the panorama shortcut and drag a rectangle over scrollable content (for example, a long web page or document). DoraZoom then captures the region repeatedly while you scroll.

            Scroll smoothly in one direction—vertically or horizontally—and press the shortcut again to finish. The captured frames are aligned and stitched into a single tall or wide image.

            The base shortcut copies the stitched panorama to the clipboard; hold Shift with the shortcut to save it as a PNG file instead.
            """
            ),
            wraps: true
        )

        let panoramaHotKeyButton = NSButton(title: panoramaHotKeyDisplayString(), target: self, action: #selector(togglePanoramaHotKeyRecording(_:)))
        panoramaHotKeyButton.bezelStyle = .rounded
        panoramaHotKeyButton.setButtonType(.momentaryPushIn)
        panoramaHotKeyButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
        self.panoramaHotKeyButton = panoramaHotKeyButton
        let panoramaHotKeyRow = makeRow([makeLabel(localized("settings.panorama.shortcut", "Panorama shortcut:")), panoramaHotKeyButton])

        return makeColumn([help, panoramaHotKeyRow])
    }

    @objc private func recordSystemAudioChanged(_ sender: NSButton) {
        settings.recordSystemAudio = (sender.state == .on)
        persist()
    }

    @objc private func recordMicrophoneChanged(_ sender: NSButton) {
        settings.recordMicrophone = (sender.state == .on)
        updateMicrophoneOptionControls()
        persist()
        // Trigger the microphone permission prompt the first time it's enabled.
        if settings.recordMicrophone {
            onRequestMicrophone()
        }
    }

    @objc private func recordMouseClicksChanged(_ sender: NSButton) {
        settings.recordMouseClicks = sender.state == .on
        persist()
        if settings.recordMouseClicks {
            onOpenPermissionCenter()
        }
    }

    @objc private func recordShortcutKeysChanged(_ sender: NSButton) {
        settings.recordShortcutKeys = sender.state == .on
        persist()
        if settings.recordShortcutKeys {
            onOpenPermissionCenter()
        }
    }

    @objc private func microphoneChanged(_ sender: NSPopUpButton) {
        settings.microphoneDeviceID = (sender.selectedItem?.representedObject as? String) ?? ""
        updateMicrophoneOptionControls()
        persist()
    }

    @objc private func recordNoiseCancellationChanged(_ sender: NSButton) {
        settings.recordNoiseCancellation = (sender.state == .on)
        persist()
    }

    private func updateMicrophoneOptionControls() {
        microphonePopup?.isEnabled = settings.recordMicrophone
        let supported = settings.recordMicrophone && AudioDevices.supportsWindNoiseRemoval(deviceID: settings.microphoneDeviceID)
        noiseCancellationCheckbox?.title = supported
            ? localized("settings.record.noise_cancellation", "Noise cancellation")
            : localized("settings.record.noise_cancellation.unsupported", "Noise cancellation (not supported by this microphone)")
        noiseCancellationCheckbox?.isEnabled = supported
        noiseCancellationCheckbox?.state = (settings.recordNoiseCancellation && supported) ? .on : .off
        noiseCancellationCheckbox?.toolTip = supported
            ? localized("settings.record.noise_cancellation.supported_help", "Uses AVFoundation wind noise removal for the selected microphone.")
            : localized("settings.record.noise_cancellation.unsupported_help", "Wind noise removal requires macOS 15 and a compatible microphone.")
    }

    @objc private func openTrimEditor(_ sender: NSButton) {
        onOpenTrimEditor()
    }

    // MARK: - Webcam controls

    private func makeWebcamRows() -> [NSView] {
        let heading = makeLabel(localized("settings.webcam.title", "Camera overlay"))
        heading.font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)

        let enableCheck = makeCheckbox("", action: #selector(webcamEnabledChanged(_:)), state: settings.webcamEnabled)

        let devicePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        devicePopup.translatesAutoresizingMaskIntoConstraints = false
        var selectedDevice = 0
        for (index, camera) in VideoDevices.availableCameras().enumerated() {
            devicePopup.addItem(withTitle: camera.name)
            devicePopup.lastItem?.representedObject = camera.id
            if camera.id == settings.webcamDeviceID { selectedDevice = index }
        }
        devicePopup.selectItem(at: selectedDevice)
        devicePopup.target = self
        devicePopup.action = #selector(webcamDeviceChanged(_:))
        webcamDevicePopup = devicePopup

        let positionPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        positionPopup.translatesAutoresizingMaskIntoConstraints = false
        for item in [
            (localized("position.top_left", "Top Left"), 0),
            (localized("position.top_right", "Top Right"), 1),
            (localized("position.center", "Center"), 4),
            (localized("position.bottom_left", "Bottom Left"), 2),
            (localized("position.bottom_right", "Bottom Right"), 3)
        ] {
            positionPopup.addItem(withTitle: item.0)
            positionPopup.lastItem?.representedObject = item.1
            if item.1 == settings.webcamPosition {
                positionPopup.select(positionPopup.lastItem)
            }
        }
        positionPopup.target = self
        positionPopup.action = #selector(webcamPositionChanged(_:))
        webcamPositionPopup = positionPopup

        let sizePopup = makeIndexedPopup(
            titles: [
                localized("size.small", "Small"),
                localized("size.medium", "Medium"),
                localized("size.large", "Large"),
                localized("size.extra_large", "Extra Large"),
                localized("size.full_screen", "Full Screen")
            ],
            selected: settings.webcamSize,
            action: #selector(webcamSizeChanged(_:))
        )
        webcamSizePopup = sizePopup

        let shapePopup = makeIndexedPopup(
            titles: [
                localized("shape.rectangle", "Rectangle"),
                localized("shape.rounded_rectangle", "Rounded Rectangle"),
                localized("shape.rounded_square", "Rounded Square"),
                localized("shape.circle", "Circle")
            ],
            selected: settings.webcamShape,
            action: #selector(webcamShapeChanged(_:))
        )
        webcamShapePopup = shapePopup

        devicePopup.widthAnchor.constraint(equalToConstant: 185).isActive = true
        positionPopup.widthAnchor.constraint(equalToConstant: 120).isActive = true
        sizePopup.widthAnchor.constraint(equalToConstant: 115).isActive = true
        shapePopup.widthAnchor.constraint(equalToConstant: 165).isActive = true

        let webcamEnableRow = makeRow([heading, enableCheck])
        // A grid keeps the two placement/appearance columns aligned so the
        // Position and Shape labels (and their popups) line up vertically.
        let webcamGrid = makeFormGrid([
            [makeLabel(localized("settings.webcam.camera", "Camera:")), devicePopup, makeLabel(localized("settings.webcam.position", "Position:")), positionPopup],
            [makeLabel(localized("settings.webcam.size", "Size:")), sizePopup, makeLabel(localized("settings.webcam.shape", "Shape:")), shapePopup]
        ])

        updateWebcamControlsEnabled()
        return [webcamEnableRow, webcamGrid]
    }

    /// Builds a popup whose item indices map directly to a settings integer.
    private func makeIndexedPopup(titles: [String], selected: Int, action: Selector) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.translatesAutoresizingMaskIntoConstraints = false
        for title in titles {
            popup.addItem(withTitle: title)
        }
        popup.selectItem(at: min(max(selected, 0), titles.count - 1))
        popup.target = self
        popup.action = action
        return popup
    }

    private func updateWebcamControlsEnabled() {
        let enabled = settings.webcamEnabled
        webcamDevicePopup?.isEnabled = enabled
        webcamPositionPopup?.isEnabled = enabled
        webcamSizePopup?.isEnabled = enabled
        // Shape doesn't apply to full screen.
        webcamShapePopup?.isEnabled = enabled && settings.webcamSize != 4
    }

    @objc private func webcamEnabledChanged(_ sender: NSButton) {
        settings.webcamEnabled = (sender.state == .on)
        updateWebcamControlsEnabled()
        persist()
        if settings.webcamEnabled {
            onRequestCamera()
        }
    }

    @objc private func webcamDeviceChanged(_ sender: NSPopUpButton) {
        settings.webcamDeviceID = (sender.selectedItem?.representedObject as? String) ?? ""
        persist()
    }

    @objc private func webcamPositionChanged(_ sender: NSPopUpButton) {
        settings.webcamPosition = (sender.selectedItem?.representedObject as? Int) ?? 3
        persist()
    }

    @objc private func webcamSizeChanged(_ sender: NSPopUpButton) {
        settings.webcamSize = sender.indexOfSelectedItem
        updateWebcamControlsEnabled()
        persist()
    }

    @objc private func webcamShapeChanged(_ sender: NSPopUpButton) {
        settings.webcamShape = sender.indexOfSelectedItem
        persist()
    }

    private func currentTypingFont() -> NSFont {
        AnnotationController.typingFont(named: settings.typingFontName, size: settings.typingFontSize)
    }

    private func updateFontSample() {
        let font = Self.fontSamplePreviewFont(name: settings.typingFontName, size: settings.typingFontSize)
        // Render the sample in the actually-selected font so choosing a new font
        // is reflected immediately (it previously always used the system font).
        fontSampleLabel?.font = font
        fontSampleLabel?.stringValue = AppLocalization.format(
            "settings.type.sample",
            defaultValue: "Sample — %@ %d pt",
            font.displayName ?? font.fontName,
            Int(settings.typingFontSize)
        )
    }

    /// Font used for the Type tab's live "Sample" preview. Uses the selected
    /// typing font, clamped to a legible on-screen preview size.
    static func fontSamplePreviewFont(name: String, size: CGFloat) -> NSFont {
        let previewSize = min(max(size, 12), 36)
        return AnnotationController.typingFont(named: name, size: previewSize)
    }

    @objc private func selectFont(_ sender: NSButton) {
        let manager = NSFontManager.shared
        manager.target = self
        manager.action = #selector(changeFont(_:))
        manager.setSelectedFont(currentTypingFont(), isMultiple: false)
        guard let window else { return }
        window.makeFirstResponder(window)
        manager.orderFrontFontPanel(sender)
    }

    @objc func changeFont(_ sender: Any?) {
        let manager = sender as? NSFontManager ?? NSFontManager.shared
        let newFont = manager.convert(currentTypingFont())
        settings.typingFontName = newFont.fontName
        settings.typingFontSize = newFont.pointSize
        updateFontSample()
        persist()
    }

    // MARK: - DemoType tab

#if !DORAZOOM_APP_STORE
    private func makeDemoTypeTab() -> NSView {
        let help = makeLabel(
            localized(
                "settings.demo_type.description",
                "DemoType types text from an input file when you activate its shortcut. Separate snippets with [end], or insert clipboard text after a [start] prefix."
            ),
            wraps: true
        )

        let controlsHelp = makeLabel(
            localized(
                "settings.demo_type.commands_help",
                """
            - Insert pauses with the [pause:n] keyword where 'n' is seconds.
            - Send text via the clipboard with [paste] and [/paste].
            - Send keystrokes with [enter], [up], [down], [left], and [right].

            You can have DoraZoom send text automatically, or select the option to drive input with typing. When driving input, your key releases advance the script. Press Escape to stop.

            When you reach the end of the file, DoraZoom reloads the file and starts at the beginning. Enter the hotkey with Shift toggled to step back to the last [end].
            """
            ),
            wraps: true
        )

        let demoTypeHotKeyButton = NSButton(title: demoTypeHotKeyDisplayString(), target: self, action: #selector(toggleDemoTypeHotKeyRecording(_:)))
        demoTypeHotKeyButton.bezelStyle = .rounded
        demoTypeHotKeyButton.setButtonType(.momentaryPushIn)
        demoTypeHotKeyButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
        self.demoTypeHotKeyButton = demoTypeHotKeyButton
        let hotKeyRow = makeRow([makeLabel(localized("settings.demo_type.shortcut", "DemoType shortcut:")), demoTypeHotKeyButton])

        let fileField = makePathField(settings.demoTypeFile)
        demoTypeFileField = fileField
        let browseButton = NSButton(
            title: localized("common.browse", "Browse…"),
            target: self,
            action: #selector(chooseDemoTypeFile(_:))
        )
        browseButton.bezelStyle = .rounded
        let fileRow = makeRow([makeLabel(localized("settings.demo_type.input_file", "Input file:")), fileField, browseButton])

        let speedSlider = NSSlider(value: Double(min(max(settings.demoTypeSpeed, 10), 100)), minValue: 10, maxValue: 100, target: self, action: #selector(demoTypeSpeedChanged(_:)))
        speedSlider.translatesAutoresizingMaskIntoConstraints = false
        speedSlider.widthAnchor.constraint(equalToConstant: 240).isActive = true
        let speedRow = makeRow([
            makeLabel(localized("settings.demo_type.typing_speed", "Typing speed:")),
            makeLabel(localized("settings.demo_type.speed.slow", "Slow")),
            speedSlider,
            makeLabel(localized("settings.demo_type.speed.fast", "Fast"))
        ])

        let userDrivenCheck = makeCheckbox(localized("settings.demo_type.drive_with_typing", "Drive input with typing"), action: #selector(demoTypeUserDrivenChanged(_:)), state: settings.demoTypeUserDriven)

        return makeColumn([help, controlsHelp, hotKeyRow, fileRow, speedRow, userDrivenCheck], spacing: 8)
    }

    @objc private func chooseDemoTypeFile(_ sender: NSButton) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = localized("settings.demo_type.file_picker.title", "DoraZoom: Choose DemoType File")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settings.demoTypeFile = url.path
        demoTypeFileField?.stringValue = url.path
        persist()
    }

    @objc private func demoTypeSpeedChanged(_ sender: NSSlider) {
        settings.demoTypeSpeed = min(max(sender.integerValue, 10), 100)
        persist()
    }

    @objc private func demoTypeUserDrivenChanged(_ sender: NSButton) {
        settings.demoTypeUserDriven = sender.state == .on
        persist()
    }
#endif

    // MARK: - Persistence

    private func persist() {
        settingsStore.save(settings)
        onSettingsChange()
    }

    // MARK: - Key formatting

    static func describe(keyCode: Int, modifiers: NSEvent.ModifierFlags) -> String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        result += keyName(forKeyCode: keyCode)
        return result
    }

    private static func keyName(forKeyCode code: Int) -> String {
        keyNames[code] ?? AppLocalization.format(
            "settings.shortcuts.unknown_key",
            defaultValue: "Key %d",
            code
        )
    }

    private static let keyNames: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C",
        9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9",
        26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[",
        34: "I", 35: "P", 36: "Return", 37: "L", 38: "J", 39: "'", 40: "K",
        41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
        48: "Tab", 49: "Space", 50: "`", 51: "Delete", 53: "Escape",
        123: "←", 124: "→", 125: "↓", 126: "↑"
    ]
}
