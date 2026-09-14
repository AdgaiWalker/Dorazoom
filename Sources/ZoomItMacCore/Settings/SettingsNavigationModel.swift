import Foundation

enum SettingsNavigationSectionID: CaseIterable, Equatable, Hashable, Sendable {
    case general
    case shortcuts
    case captureAndDraw
    case recording
    case permissions
    case advanced
}

enum SettingsDestination: CaseIterable, Equatable, Hashable, Sendable {
    case launchAtLogin
    case zoomBehavior
    case coreHotkeys
    case snip
    case drawing
    case text
    case recordingCore
    case permissionCenter
    case demoType
    case breakTimer
    case panorama
    case webcamDetails
    case recordingFormats
    case complexEditor
}

struct SettingsNavigationSection: Equatable, Sendable {
    var id: SettingsNavigationSectionID
    var title: String
    var symbolName: String
    var destinations: [SettingsDestination]
}

struct SettingsNavigationPlan: Equatable, Sendable {
    var sections: [SettingsNavigationSection]
    var platformBoundary: AutomationPlatformBoundary

    func section(for id: SettingsNavigationSectionID) -> SettingsNavigationSection? {
        sections.first { $0.id == id }
    }

    func section(containing destination: SettingsDestination) -> SettingsNavigationSection? {
        sections.first { $0.destinations.contains(destination) }
    }
}

enum SettingsNavigationModel {
    static let defaultPlan = SettingsNavigationPlan(
        sections: [
            SettingsNavigationSection(
                id: .general,
                title: text("settings_navigation.general", "General"),
                symbolName: "gearshape",
                destinations: [.launchAtLogin, .zoomBehavior]
            ),
            SettingsNavigationSection(
                id: .shortcuts,
                title: text("settings_navigation.shortcuts", "Shortcuts"),
                symbolName: "keyboard",
                destinations: [.coreHotkeys]
            ),
            SettingsNavigationSection(
                id: .captureAndDraw,
                title: text("settings_navigation.capture_and_draw", "Capture & Draw"),
                symbolName: "pencil.and.outline",
                destinations: [.snip, .drawing, .text]
            ),
            SettingsNavigationSection(
                id: .recording,
                title: text("settings_navigation.recording", "Recording"),
                symbolName: "record.circle",
                destinations: [.recordingCore]
            ),
            SettingsNavigationSection(
                id: .permissions,
                title: text("settings_navigation.permissions", "Permissions"),
                symbolName: "checkmark.shield",
                destinations: [.permissionCenter]
            ),
            SettingsNavigationSection(
                id: .advanced,
                title: text("settings_navigation.advanced", "Advanced"),
                symbolName: "slider.horizontal.3",
                destinations: [
                    .demoType,
                    .breakTimer,
                    .panorama,
                    .webcamDetails,
                    .recordingFormats,
                    .complexEditor
                ]
            )
        ],
        platformBoundary: .simulatedOnly
    )

    private static func text(_ key: String, _ defaultValue: String) -> String {
        AppLocalization.string(key, defaultValue: defaultValue)
    }
}
