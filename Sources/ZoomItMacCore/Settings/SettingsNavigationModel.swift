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
    /// The navigation shape for this build.
    static var defaultPlan: SettingsNavigationPlan {
        plan(demoTypeAvailable: DemoTypeBuildAvailability.isIncludedInBuild)
    }

    /// Takes DemoType availability as a parameter so both build shapes stay
    /// testable from the one test target the package builds. App Store builds
    /// compile DemoType out, and the Advanced group must not advertise a
    /// settings surface that the same binary cannot open.
    static func plan(
        demoTypeAvailable: Bool = DemoTypeBuildAvailability.isIncludedInBuild
    ) -> SettingsNavigationPlan {
        SettingsNavigationPlan(
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
                    destinations: advancedDestinations(demoTypeAvailable: demoTypeAvailable)
                )
            ],
            platformBoundary: .simulatedOnly
        )
    }

    private static func advancedDestinations(demoTypeAvailable: Bool) -> [SettingsDestination] {
        var destinations: [SettingsDestination] = []
        if demoTypeAvailable {
            destinations.append(.demoType)
        }
        destinations.append(contentsOf: [
            .breakTimer,
            .panorama,
            .webcamDetails,
            .recordingFormats,
            .complexEditor
        ])
        return destinations
    }

    private static func text(_ key: String, _ defaultValue: String) -> String {
        AppLocalization.string(key, defaultValue: defaultValue)
    }
}
