import AppKit

@MainActor
final class AppController: NSObject {
    private let settingsStore: SettingsStore
    private let permissionService: PermissionService
    private let hotkeyService: HotkeyService
    private let modeCoordinator: ModeCoordinator
    private let permissionCenterCoordinator: PermissionCenterCoordinator
    private let onMenuNeedsUpdate: () -> Void
    private lazy var settingsWindowController = SettingsWindowController(
        settingsStore: settingsStore,
        onHotKeyChange: { [weak self] in self?.hotkeyService.reloadHotkey() },
        onSettingsChange: { [weak self] in self?.onMenuNeedsUpdate() },
        onSuspendHotkeys: { [weak self] in self?.hotkeyService.stop() },
        onResumeHotkeys: { [weak self] in self?.hotkeyService.start() },
        onRequestMicrophone: { [weak self] in self?.permissionService.requestMicrophoneAccess(completion: nil) },
        onRequestCamera: { [weak self] in self?.permissionService.requestCameraAccess(completion: nil) },
        onOpenTrimEditor: { [weak self] in self?.modeCoordinator.openTrimEditor() },
        onOpenPermissionCenter: { [weak self] in self?.permissionCenterCoordinator.show() }
    )

    init(
        settingsStore: SettingsStore,
        permissionService: PermissionService,
        hotkeyService: HotkeyService,
        modeCoordinator: ModeCoordinator,
        permissionCenterCoordinator: PermissionCenterCoordinator,
        onMenuNeedsUpdate: @escaping () -> Void
    ) {
        self.settingsStore = settingsStore
        self.permissionService = permissionService
        self.hotkeyService = hotkeyService
        self.modeCoordinator = modeCoordinator
        self.permissionCenterCoordinator = permissionCenterCoordinator
        self.onMenuNeedsUpdate = onMenuNeedsUpdate
        super.init()
    }

    @objc func activateStaticZoom() {
        modeCoordinator.handle(.activateStaticZoom)
    }

    @objc func activateDrawWithoutZoom() {
        modeCoordinator.handle(.activateDrawWithoutZoom)
    }

    @objc func activateLiveZoom() {
        modeCoordinator.handle(.activateLiveZoom)
    }

    @objc func toggleRecording() {
        modeCoordinator.handle(.toggleRecording(region: false))
    }

    @objc func toggleRecordingPause() {
        modeCoordinator.handle(.toggleRecordingPause)
    }

    @objc func snipRegion() {
        modeCoordinator.handle(.snipRegion(save: false))
    }

    @objc func snipPreviousRegion() {
        modeCoordinator.handle(.snipPreviousRegion)
    }

    @objc func snipWindowAtPointer() {
        modeCoordinator.handle(.snipWindowAtPointer)
    }

    @objc func snipOCR() {
        modeCoordinator.handle(.snipOcr)
    }

    @objc func startPanorama() {
        modeCoordinator.handle(.startPanorama(save: false))
    }

    @objc func startDemoType() {
        modeCoordinator.handle(.startDemoType)
    }

    @objc func toggleBreakTimer() {
        modeCoordinator.handle(.toggleBreakTimer)
    }

    @objc func openAdvancedEditor() {
        modeCoordinator.openTrimEditor()
    }

    @objc func showSettings() {
        settingsWindowController.show()
    }

    @objc func checkPermissions() {
        permissionCenterCoordinator.show()
    }

    func applicationBecameActive() {
        permissionCenterCoordinator.applicationBecameActive()
    }

    @objc func quit() {
        hotkeyService.stop()
        NSApplication.shared.terminate(nil)
    }
}
