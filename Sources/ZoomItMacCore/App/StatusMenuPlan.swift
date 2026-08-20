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
        settings: AppSettings
    ) -> StatusMenuPlan {
        let permissionNeedsAttention = permissions.rows.contains {
            switch $0.state {
            case .ready, .optionalNotRequested:
                false
            case .notRequested, .needsSettings, .restartRequired:
                true
            }
        }

        return StatusMenuPlan(topLevelItems: [
            StatusMenuItemPlan(
                id: .status,
                title: statusTitle(status),
                isEnabled: false
            ),
            command(.draw, "圈画", shortcut: shortcut(
                keyCode: settings.drawHotKeyCode,
                rawModifiers: settings.drawHotKeyModifiers
            )),
            command(.staticZoom, "静态缩放", shortcut: shortcut(
                keyCode: settings.hotKeyCode,
                rawModifiers: settings.hotKeyModifiers
            )),
            command(.liveZoom, "实时缩放", shortcut: shortcut(
                keyCode: settings.liveHotKeyCode,
                rawModifiers: settings.liveHotKeyModifiers
            )),
            StatusMenuItemPlan(
                id: .screenshot,
                title: "截图",
                children: [
                    command(.snipRegion, "区域截图", shortcut: shortcut(
                        keyCode: settings.snipHotKeyCode,
                        rawModifiers: settings.snipHotKeyModifiers
                    )),
                    command(.snipOCR, "OCR 识别", shortcut: shortcut(
                        keyCode: settings.snipOcrHotKeyCode,
                        rawModifiers: settings.snipOcrHotKeyModifiers
                    )),
                    command(.snipPreviousRegion, "重复上一次区域"),
                    command(.snipWindow, "鼠标所在窗口")
                ]
            ),
            command(.recordScreen, "录制屏幕", shortcut: shortcut(
                keyCode: settings.recordHotKeyCode,
                rawModifiers: settings.recordHotKeyModifiers
            )),
            command(.toggleRecordingPause, "暂停/继续录制"),
            StatusMenuItemPlan(id: .coreSeparator, title: ""),
            StatusMenuItemPlan(
                id: .moreFeatures,
                title: "更多功能",
                children: [
                    command(.panorama, "全景截图", shortcut: shortcut(
                        keyCode: settings.panoramaHotKeyCode,
                        rawModifiers: settings.panoramaHotKeyModifiers
                    )),
                    command(.demoType, "DemoType", shortcut: shortcut(
                        keyCode: settings.demoTypeHotKeyCode,
                        rawModifiers: settings.demoTypeHotKeyModifiers
                    )),
                    command(.breakTimer, "休息倒计时", shortcut: shortcut(
                        keyCode: settings.breakHotKeyCode,
                        rawModifiers: settings.breakHotKeyModifiers
                    )),
                    command(.advancedEditor, "高级视频编辑器…")
                ]
            ),
            StatusMenuItemPlan(id: .managementSeparator, title: ""),
            StatusMenuItemPlan(
                id: .permissions,
                title: permissionNeedsAttention ? "权限 · 需要设置" : "权限",
                needsAttention: permissionNeedsAttention
            ),
            command(
                .settings,
                "设置…",
                shortcut: .init(key: ",", modifiers: [.command])
            ),
            StatusMenuItemPlan(id: .quitSeparator, title: ""),
            command(
                .quit,
                "退出 DoraZoom",
                shortcut: .init(key: "q", modifiers: [.command])
            )
        ])
    }

    private static func statusTitle(_ status: StatusMenuRuntimeStatus) -> String {
        switch status {
        case .idle:
            "就绪"
        case .active:
            "圈画中"
        case .recording:
            "正在录制"
        }
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
