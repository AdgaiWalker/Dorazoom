import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private let hotkeys = HotkeyManager()
    private let coordinator = LayerCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Telemetry.shared.log("app.launch")
        setupStatusItem()

        coordinator.onStatusChange = { [weak self] in self?.refreshStatus() }
        coordinator.onNeedScreenPermission = { [weak self] feature in
            self?.promptScreenPermission(feature: feature)
        }

        // Ctrl+1~6 六件套
        hotkeys.register(digit: 1) { [weak self] in self?.coordinator.toggleZoom() }
        hotkeys.register(digit: 2) { [weak self] in self?.coordinator.toggleDraw() }
        hotkeys.register(digit: 3) { [weak self] in self?.coordinator.toggleType() }
        hotkeys.register(digit: 4) { [weak self] in self?.coordinator.toggleWhiteboard() }
        hotkeys.register(digit: 5) { [weak self] in self?.coordinator.toggleRecord() }
        hotkeys.register(digit: 6) { [weak self] in self?.coordinator.startSnip() }
        // 全局 Esc：无焦点 / 白板穿透 / 输入框中均能清场
        hotkeys.registerEscape { [weak self] in
            self?.coordinator.clearAll(trigger: "esc")
        }

        refreshStatus()
    }

    // MARK: - 权限引导

    private func promptScreenPermission(feature: String) {
        let alert = NSAlert()
        alert.messageText = "\(feature)需要屏幕录制权限"
        alert.informativeText = """
        1. 点「去授权」会弹出系统对话框或打开设置
        2. 在「隐私与安全性 → 屏幕录制」中打开 InkLayer
        3. 授权后请完全退出再重新打开 InkLayer.app
        """
        alert.addButton(withTitle: "去授权")
        alert.addButton(withTitle: "取消")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openScreenCaptureSettings()
        }
    }

    @objc private func openRecordingsFolder() {
        NSWorkspace.shared.open(ConfigStore.recordOutputDir())
    }

    // MARK: - 菜单栏

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "墨"

        let menu = NSMenu()
        statusMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())

        let openRec = NSMenuItem(title: "打开录屏文件夹…",
                                 action: #selector(openRecordingsFolder),
                                 keyEquivalent: "")
        openRec.target = self
        menu.addItem(openRec)

        let unlock = NSMenuItem(title: "解锁冻结态（授权录屏）…",
                                action: #selector(openScreenCaptureSettings),
                                keyEquivalent: "")
        unlock.target = self
        menu.addItem(unlock)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "退出 InkLayer",
                              action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func refreshStatus() {
        let p = coordinator.statusPresentation()
        if let color = p.color {
            statusItem.button?.attributedTitle = NSAttributedString(
                string: p.title, attributes: [.foregroundColor: color])
        } else {
            statusItem.button?.attributedTitle = NSAttributedString(string: p.title)
        }
        statusMenuItem.title = p.detail
    }

    @objc private func openScreenCaptureSettings() {
        Telemetry.shared.log("permission.screen.open_settings")
        // 主动请求：把本 app 登记进「屏幕录制」列表（.app 包名显示为 InkLayer）
        let granted = CGRequestScreenCaptureAccess()
        Telemetry.shared.log("permission.screen.request",
                             ["granted": granted ? "true" : "false"])
        // 打开系统设置对应页（macOS 13+ / 旧版 URL 各试一次）
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture"
        ]
        for s in urls {
            if let url = URL(string: s), NSWorkspace.shared.open(url) { break }
        }
    }
}
