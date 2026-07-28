import CoreGraphics
import Foundation

enum SettingsManagementCategory: Equatable, Hashable, Sendable {
    case zoom
    case draw
    case text
    case snip
    case record
    case webcam
    case panorama
    case launch
}

struct SettingsManagementCategorySnapshot: Equatable, Sendable {
    var category: SettingsManagementCategory
    var values: [String: String]
}

struct SettingsManagementSnapshot: Equatable, Sendable {
    var categories: [SettingsManagementCategorySnapshot]
    var platformBoundary: AutomationPlatformBoundary

    func value(for category: SettingsManagementCategory, key: String) -> String? {
        categories.first { $0.category == category }?.values[key]
    }
}

struct SettingsManagementMemoryStore {
    private var settings: AppSettings

    init(initial: AppSettings) {
        self.settings = initial
    }

    func load() -> AppSettings {
        settings
    }

    mutating func save(_ settings: AppSettings) {
        self.settings = settings
    }

    func simulateRestart() -> SettingsManagementMemoryStore {
        SettingsManagementMemoryStore(initial: settings)
    }
}

enum SettingsHotkeyCommand: Equatable, Hashable, Sendable {
    case staticZoom
    case drawWithoutZoom
    case liveZoom
    case snipToClipboard
    case snipToFile
    case snipOCRToClipboard
    case recordFullScreen
    case recordRegion
    case demoType
    case demoTypePreviousSegment
    case panoramaToClipboard
    case panoramaToFile
    case breakTimer
}

struct SettingsHotkeyKey: Equatable, Hashable, Sendable {
    var code: Int
    var modifiers: Set<KeyboardModifier>
}

struct SettingsHotkeyBinding: Equatable, Sendable {
    var command: SettingsHotkeyCommand
    var key: SettingsHotkeyKey
}

struct SettingsHotkeyConflict: Equatable, Sendable {
    var key: SettingsHotkeyKey
    var commands: [SettingsHotkeyCommand]
}

struct SettingsHotkeyPlan: Equatable, Sendable {
    var bindings: [SettingsHotkeyBinding]
    var conflicts: [SettingsHotkeyConflict]
    var canSave: Bool
    var platformBoundary: AutomationPlatformBoundary
}

enum SettingsPermissionGrantState: Equatable, Sendable {
    case granted
    case denied
    case notDetermined
}

struct SettingsPermissionSimulationInput: Equatable {
    var screenCapture: SettingsPermissionGrantState
    var input: KeyboardEventAccess
    var microphone: MicrophonePermission
    var camera: MicrophonePermission
}

enum SettingsPermissionRowKind: Equatable, Hashable, Sendable {
    case screenRecording
    case inputMonitoringListen
    case inputMonitoringPost
    case microphone
    case camera
}

enum SettingsPermissionRowStatus: Equatable, Sendable {
    case granted
    case missing
    case needsSettings
    case notDetermined
}

enum SettingsPermissionAction: Equatable, Sendable {
    case none
    case openSystemSettings
    case requestPermission
}

struct SettingsPermissionRow: Equatable, Sendable {
    var kind: SettingsPermissionRowKind
    var status: SettingsPermissionRowStatus
    var action: SettingsPermissionAction
}

struct SettingsPermissionPage: Equatable, Sendable {
    var rows: [SettingsPermissionRow]
    var platformBoundary: AutomationPlatformBoundary
    var touchesRealTCC: Bool
    var opensSystemSettings: Bool
}

enum SettingsManagementSimulation {
    static func snapshot(for settings: AppSettings) -> SettingsManagementSnapshot {
        SettingsManagementSnapshot(
            categories: [
                .init(category: .zoom, values: [
                    "defaultZoomFactor": decimal(settings.defaultZoomFactor),
                    "maximumZoomFactor": decimal(settings.maximumZoomFactor),
                    "minimumZoomFactor": decimal(settings.minimumZoomFactor),
                    "animateZoom": switchText(settings.animateZoom),
                    "smoothImage": switchText(settings.smoothImage)
                ]),
                .init(category: .draw, values: [
                    "rootPenWidth": decimal(settings.rootPenWidth)
                ]),
                .init(category: .text, values: [
                    "fontName": settings.typingFontName,
                    "fontSize": decimal(settings.typingFontSize)
                ]),
                .init(category: .snip, values: [
                    "copyToClipboardOnSave": switchText(settings.copySnipToClipboardOnSave),
                    "saveToDirectory": switchText(settings.saveSnipToDirectory),
                    "saveDirectory": settings.snipSaveDirectory
                ]),
                .init(category: .record, values: [
                    "systemAudio": switchText(settings.recordSystemAudio),
                    "microphone": switchText(settings.recordMicrophone),
                    "noiseCancellation": switchText(settings.recordNoiseCancellation),
                    "microphoneDeviceID": settings.microphoneDeviceID
                ]),
                .init(category: .webcam, values: [
                    "enabled": switchText(settings.webcamEnabled),
                    "deviceID": settings.webcamDeviceID,
                    "position": "\(settings.webcamPosition)",
                    "size": "\(settings.webcamSize)",
                    "shape": "\(settings.webcamShape)"
                ]),
                .init(category: .panorama, values: [
                    "hotKeyCode": "\(settings.panoramaHotKeyCode)"
                ]),
                .init(category: .launch, values: [
                    "launchAtLogin": switchText(settings.launchAtLogin)
                ])
            ],
            platformBoundary: .simulatedOnly
        )
    }

    static func hotkeyPlan(for settings: AppSettings) -> SettingsHotkeyPlan {
        let bindings = [
            binding(.staticZoom, code: settings.hotKeyCode, modifiers: settings.hotKeyModifiers),
            binding(.drawWithoutZoom, code: settings.drawHotKeyCode, modifiers: settings.drawHotKeyModifiers),
            binding(.liveZoom, code: settings.liveHotKeyCode, modifiers: settings.liveHotKeyModifiers),
            binding(.snipToClipboard, code: settings.snipHotKeyCode, modifiers: settings.snipHotKeyModifiers),
            binding(.snipToFile, code: settings.snipHotKeyCode, modifiers: addShift(to: settings.snipHotKeyModifiers)),
            binding(.snipOCRToClipboard, code: settings.snipOcrHotKeyCode, modifiers: settings.snipOcrHotKeyModifiers),
            binding(.recordFullScreen, code: settings.recordHotKeyCode, modifiers: settings.recordHotKeyModifiers),
            binding(.recordRegion, code: settings.recordHotKeyCode, modifiers: addShift(to: settings.recordHotKeyModifiers)),
            binding(.demoType, code: settings.demoTypeHotKeyCode, modifiers: settings.demoTypeHotKeyModifiers),
            binding(.demoTypePreviousSegment, code: settings.demoTypeHotKeyCode, modifiers: addShift(to: settings.demoTypeHotKeyModifiers)),
            binding(.panoramaToClipboard, code: settings.panoramaHotKeyCode, modifiers: settings.panoramaHotKeyModifiers),
            binding(.panoramaToFile, code: settings.panoramaHotKeyCode, modifiers: addShift(to: settings.panoramaHotKeyModifiers)),
            binding(.breakTimer, code: settings.breakHotKeyCode, modifiers: settings.breakHotKeyModifiers)
        ].compactMap { $0 }

        let conflicts = hotkeyConflicts(in: bindings)
        return SettingsHotkeyPlan(
            bindings: bindings,
            conflicts: conflicts,
            canSave: conflicts.isEmpty,
            platformBoundary: .simulatedOnly
        )
    }

    static func permissionPage(permissions: SettingsPermissionSimulationInput) -> SettingsPermissionPage {
        SettingsPermissionPage(
            rows: [
                screenRecordingRow(permissions.screenCapture),
                inputRow(kind: .inputMonitoringListen, isGranted: permissions.input.canListen),
                inputRow(kind: .inputMonitoringPost, isGranted: permissions.input.canPost),
                mediaRow(kind: .microphone, permissions.microphone),
                mediaRow(kind: .camera, permissions.camera)
            ],
            platformBoundary: .simulatedOnly,
            touchesRealTCC: false,
            opensSystemSettings: false
        )
    }

    private static func binding(
        _ command: SettingsHotkeyCommand,
        code: Int,
        modifiers: UInt
    ) -> SettingsHotkeyBinding? {
        guard code != 0 else { return nil }
        return SettingsHotkeyBinding(
            command: command,
            key: SettingsHotkeyKey(code: code, modifiers: keyboardModifiers(from: modifiers))
        )
    }

    private static func hotkeyConflicts(in bindings: [SettingsHotkeyBinding]) -> [SettingsHotkeyConflict] {
        var conflicts: [SettingsHotkeyConflict] = []

        for binding in bindings {
            guard bindings.filter({ $0.key == binding.key }).count > 1 else { continue }
            guard !conflicts.contains(where: { $0.key == binding.key }) else { continue }
            conflicts.append(SettingsHotkeyConflict(
                key: binding.key,
                commands: bindings.filter { $0.key == binding.key }.map(\.command)
            ))
        }

        return conflicts
    }

    private static func screenRecordingRow(_ state: SettingsPermissionGrantState) -> SettingsPermissionRow {
        switch state {
        case .granted:
            return .init(kind: .screenRecording, status: .granted, action: .none)
        case .denied:
            return .init(kind: .screenRecording, status: .needsSettings, action: .openSystemSettings)
        case .notDetermined:
            return .init(kind: .screenRecording, status: .notDetermined, action: .requestPermission)
        }
    }

    private static func inputRow(kind: SettingsPermissionRowKind, isGranted: Bool) -> SettingsPermissionRow {
        SettingsPermissionRow(
            kind: kind,
            status: isGranted ? .granted : .missing,
            action: isGranted ? .none : .openSystemSettings
        )
    }

    private static func mediaRow(kind: SettingsPermissionRowKind, _ permission: MicrophonePermission) -> SettingsPermissionRow {
        switch permission {
        case .granted:
            return .init(kind: kind, status: .granted, action: .none)
        case .denied:
            return .init(kind: kind, status: .needsSettings, action: .openSystemSettings)
        case .notDetermined:
            return .init(kind: kind, status: .notDetermined, action: .requestPermission)
        }
    }

    private static func keyboardModifiers(from rawValue: UInt) -> Set<KeyboardModifier> {
        var modifiers: Set<KeyboardModifier> = []
        if rawValue & Self.controlModifierFlag != 0 { modifiers.insert(.control) }
        if rawValue & Self.commandModifierFlag != 0 { modifiers.insert(.command) }
        if rawValue & Self.shiftModifierFlag != 0 { modifiers.insert(.shift) }
        if rawValue & Self.optionModifierFlag != 0 { modifiers.insert(.option) }
        return modifiers
    }

    private static func addShift(to rawValue: UInt) -> UInt {
        rawValue | Self.shiftModifierFlag
    }

    private static func decimal(_ value: CGFloat) -> String {
        String(format: "%.1f", Double(value))
    }

    private static func switchText(_ isOn: Bool) -> String {
        isOn ? "on" : "off"
    }

    private static let shiftModifierFlag: UInt = 1 << 17
    private static let controlModifierFlag: UInt = 1 << 18
    private static let optionModifierFlag: UInt = 1 << 19
    private static let commandModifierFlag: UInt = 1 << 20
}
