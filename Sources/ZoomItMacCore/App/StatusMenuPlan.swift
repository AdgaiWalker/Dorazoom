import Foundation

enum StatusMenuItemID: Equatable, Hashable, Sendable {
    case status
    case draw
    case staticZoom
    case liveZoom
    case screenshot
    case snipRegion
    case snipOCR
    case snipPreviousRegion
    case snipWindow
    case recordScreen
    case toggleRecordingPause
    case coreSeparator
    case moreFeatures
    case panorama
    case demoType
    case breakTimer
    case advancedEditor
    case managementSeparator
    case permissions
    case settings
    case quitSeparator
    case quit

    var isSeparator: Bool {
        self == .coreSeparator
            || self == .managementSeparator
            || self == .quitSeparator
    }
}

enum StatusMenuShortcutModifier: Equatable, Hashable, Sendable {
    case control
    case option
    case shift
    case command
}

struct StatusMenuShortcut: Equatable, Sendable {
    var key: String
    var modifiers: Set<StatusMenuShortcutModifier>
}

enum StatusMenuRuntimeStatus: Equatable, Sendable {
    case idle
    case active
    case recording
}

struct StatusMenuItemPlan: Equatable, Sendable {
    var id: StatusMenuItemID
    var title: String
    var isEnabled: Bool = true
    var needsAttention: Bool = false
    var shortcut: StatusMenuShortcut?
    var children: [StatusMenuItemPlan] = []

    var isSeparator: Bool { id.isSeparator }
}

struct StatusMenuPlan: Equatable, Sendable {
    var topLevelItems: [StatusMenuItemPlan]

    func item(_ id: StatusMenuItemID) -> StatusMenuItemPlan? {
        func find(in items: [StatusMenuItemPlan]) -> StatusMenuItemPlan? {
            for item in items {
                if item.id == id {
                    return item
                }
                if let child = find(in: item.children) {
                    return child
                }
            }
            return nil
        }

        return find(in: topLevelItems)
    }

    static func make(
        status: StatusMenuRuntimeStatus,
        permissions: PermissionCenterPlan,
        settings: AppSettings,
        demoTypeAvailable: Bool = DemoTypeBuildAvailability.isIncludedInBuild
    ) -> StatusMenuPlan {
        let permissionNeedsAttention = permissions.rows.contains {
            switch $0.state {
            case .ready, .optionalNotRequested:
                false
            case .notRequested, .needsSettings, .restartRequired:
                true
            }
        }

        // DemoType is compiled out of App Store builds, so the store menu must
        // not offer it: a menu item that cannot dispatch is a dead button.
        var moreFeatureItems: [StatusMenuItemPlan] = [
            command(.panorama, text("status_menu.panorama_capture", "Panorama Capture"), shortcut: shortcut(
                keyCode: settings.panoramaHotKeyCode,
                rawModifiers: settings.panoramaHotKeyModifiers
            ))
        ]
        if demoTypeAvailable {
            moreFeatureItems.append(command(.demoType, text("status_menu.demo_type", "DemoType"), shortcut: shortcut(
                keyCode: settings.demoTypeHotKeyCode,
                rawModifiers: settings.demoTypeHotKeyModifiers
            )))
        }
        moreFeatureItems.append(contentsOf: [
            command(.breakTimer, text("status_menu.break_timer", "Break Timer"), shortcut: shortcut(
                keyCode: settings.breakHotKeyCode,
                rawModifiers: settings.breakHotKeyModifiers
            )),
            command(.advancedEditor, text("status_menu.advanced_video_editor", "Advanced Video Editor…"))
        ])

        return StatusMenuPlan(topLevelItems: [
            StatusMenuItemPlan(
                id: .status,
                title: statusTitle(status),
                isEnabled: false
            ),
            command(.draw, text("status_menu.draw", "Draw"), shortcut: shortcut(
                keyCode: settings.drawHotKeyCode,
                rawModifiers: settings.drawHotKeyModifiers
            )),
            command(.staticZoom, text("status_menu.static_zoom", "Static Zoom"), shortcut: shortcut(
                keyCode: settings.hotKeyCode,
                rawModifiers: settings.hotKeyModifiers
            )),
            command(.liveZoom, text("status_menu.live_zoom", "Live Zoom"), shortcut: shortcut(
                keyCode: settings.liveHotKeyCode,
                rawModifiers: settings.liveHotKeyModifiers
            )),
            StatusMenuItemPlan(
                id: .screenshot,
                title: text("status_menu.screenshot", "Screenshot"),
                children: [
                    command(.snipRegion, text("status_menu.capture_region", "Capture Region"), shortcut: shortcut(
                        keyCode: settings.snipHotKeyCode,
                        rawModifiers: settings.snipHotKeyModifiers
                    )),
                    command(.snipOCR, text("status_menu.extract_text_ocr", "Extract Text (OCR)"), shortcut: shortcut(
                        keyCode: settings.snipOcrHotKeyCode,
                        rawModifiers: settings.snipOcrHotKeyModifiers
                    )),
                    command(.snipPreviousRegion, text("status_menu.capture_previous_region", "Capture Previous Region")),
                    command(.snipWindow, text("status_menu.capture_window_under_pointer", "Capture Window Under Pointer"))
                ]
            ),
            command(.recordScreen, text("status_menu.record_screen", "Record Screen"), shortcut: shortcut(
                keyCode: settings.recordHotKeyCode,
                rawModifiers: settings.recordHotKeyModifiers
            )),
            command(.toggleRecordingPause, text("status_menu.pause_resume_recording", "Pause/Resume Recording")),
            StatusMenuItemPlan(id: .coreSeparator, title: ""),
            StatusMenuItemPlan(
                id: .moreFeatures,
                title: text("status_menu.more_features", "More Features"),
                children: moreFeatureItems
            ),
            StatusMenuItemPlan(id: .managementSeparator, title: ""),
            StatusMenuItemPlan(
                id: .permissions,
                title: permissionNeedsAttention
                    ? text("status_menu.permissions.action_required", "Permissions · Action Required")
                    : text("status_menu.permissions", "Permissions"),
                needsAttention: permissionNeedsAttention
            ),
            command(
                .settings,
                text("status_menu.settings", "Settings…"),
                shortcut: .init(key: ",", modifiers: [.command])
            ),
            StatusMenuItemPlan(id: .quitSeparator, title: ""),
            command(
                .quit,
                text("status_menu.quit", "Quit DoraZoom"),
                shortcut: .init(key: "q", modifiers: [.command])
            )
        ])
    }

    private static func statusTitle(_ status: StatusMenuRuntimeStatus) -> String {
        switch status {
        case .idle:
            text("status_menu.status.ready", "Ready")
        case .active:
            text("status_menu.status.drawing", "Drawing")
        case .recording:
            text("status_menu.status.recording", "Recording")
        }
    }

    private static func text(_ key: String, _ defaultValue: String) -> String {
        AppLocalization.string(key, defaultValue: defaultValue)
    }

    private static func command(
        _ id: StatusMenuItemID,
        _ title: String,
        shortcut: StatusMenuShortcut? = nil
    ) -> StatusMenuItemPlan {
        StatusMenuItemPlan(
            id: id,
            title: title,
            shortcut: shortcut
        )
    }

    private static func shortcut(
        keyCode: Int,
        rawModifiers: UInt
    ) -> StatusMenuShortcut? {
        guard keyCode != 0, let key = keyEquivalents[keyCode] else {
            return nil
        }

        var modifiers: Set<StatusMenuShortcutModifier> = []
        if rawModifiers & (1 << 18) != 0 { modifiers.insert(.control) }
        if rawModifiers & (1 << 19) != 0 { modifiers.insert(.option) }
        if rawModifiers & (1 << 17) != 0 { modifiers.insert(.shift) }
        if rawModifiers & (1 << 20) != 0 { modifiers.insert(.command) }
        return StatusMenuShortcut(key: key, modifiers: modifiers)
    }

    private static let keyEquivalents: [Int: String] = [
        0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x",
        8: "c", 9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r",
        16: "y", 17: "t", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p", 36: "\r",
        37: "l", 38: "j", 39: "'", 40: "k", 41: ";", 42: "\\", 43: ",",
        44: "/", 45: "n", 46: "m", 47: ".", 48: "\t", 49: " ", 50: "`",
        51: "\u{8}", 53: "\u{1b}", 123: "←", 124: "→", 125: "↓", 126: "↑"
    ]
}
