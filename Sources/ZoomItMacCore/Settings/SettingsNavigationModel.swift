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
                title: "通用",
                symbolName: "gearshape",
                destinations: [.launchAtLogin, .zoomBehavior]
            ),
            SettingsNavigationSection(
                id: .shortcuts,
                title: "快捷键",
                symbolName: "keyboard",
                destinations: [.coreHotkeys]
            ),
            SettingsNavigationSection(
                id: .captureAndDraw,
                title: "截图与圈画",
                symbolName: "pencil.and.outline",
                destinations: [.snip, .drawing, .text]
            ),
            SettingsNavigationSection(
                id: .recording,
                title: "录制",
                symbolName: "record.circle",
                destinations: [.recordingCore]
            ),
            SettingsNavigationSection(
                id: .permissions,
                title: "权限",
                symbolName: "checkmark.shield",
                destinations: [.permissionCenter]
            ),
            SettingsNavigationSection(
                id: .advanced,
                title: "高级",
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
}
