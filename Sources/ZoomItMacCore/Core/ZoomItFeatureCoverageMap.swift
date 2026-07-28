import Foundation

enum ZoomItFeatureCapability: CaseIterable, Hashable, Sendable {
    case staticZoom
    case liveZoom
    case drawWithoutZoom
    case liveDraw
    case freehandPen
    case shapeTools
    case colorPensAndTranslucentHighlight
    case whiteAndBlackPens
    case whiteboardAndBlackboard
    case textInputAlignmentAndFontSize
    case undoAndClearAnnotations
    case currentViewportCopyAndSave
    case regionSnipToClipboard
    case regionSnipToFile
    case regionOCRToClipboard
    case fullScreenRecording
    case regionRecording
    case windowRecording
    case systemAudioAndMicrophoneRecording
    case webcamPictureInPicture
    case postRecordingEditor
    case breakTimer
    case demoType
    case panoramaClipboardOrFile
    case settingsAndHotkeyCustomization
    case drawingTextRecordingWebcamPanoramaAndLaunchSettings
    case singleInstance
    case menuBarStatus
    case permissionChecks
    case launchAtLogin
    case pasteCompatibility
    case cursorFeedback

    static let prdSection5_1: [ZoomItFeatureCapability] = [
        .staticZoom,
        .liveZoom,
        .drawWithoutZoom,
        .liveDraw,
        .freehandPen,
        .shapeTools,
        .colorPensAndTranslucentHighlight,
        .whiteAndBlackPens,
        .whiteboardAndBlackboard,
        .textInputAlignmentAndFontSize,
        .undoAndClearAnnotations,
        .currentViewportCopyAndSave,
        .regionSnipToClipboard,
        .regionSnipToFile,
        .regionOCRToClipboard,
        .fullScreenRecording,
        .regionRecording,
        .windowRecording,
        .systemAudioAndMicrophoneRecording,
        .webcamPictureInPicture,
        .postRecordingEditor,
        .breakTimer,
        .demoType,
        .panoramaClipboardOrFile,
        .settingsAndHotkeyCustomization,
        .drawingTextRecordingWebcamPanoramaAndLaunchSettings,
        .singleInstance,
        .menuBarStatus,
        .permissionChecks,
        .launchAtLogin
    ]
}

enum ZoomItFeatureCoverageStatus: Equatable, Sendable {
    case unknown
    case localSimulationAccepted
    case phase6ImplementationGap
}

enum ZoomItFeaturePhase7Ref: Equatable, Hashable, Sendable {
    case localSimulationAcceptance
    case mediaCompatibilityMatrix
}

struct ZoomItFeatureCoverageEntry: Equatable, Sendable {
    var capability: ZoomItFeatureCapability
    var isPRDRequired: Bool
    var implementationRefs: [String]
    var simulatedTestRefs: [String]
    var phase7Refs: [ZoomItFeaturePhase7Ref]
    var status: ZoomItFeatureCoverageStatus
}

struct ZoomItFeatureCoverageMap: Equatable, Sendable {
    var requiredCapabilities: [ZoomItFeatureCapability]
    var entries: [ZoomItFeatureCoverageEntry]
    var platformBoundary: AutomationPlatformBoundary

    var gaps: [ZoomItFeatureCoverageEntry] {
        entries.filter { $0.status == .phase6ImplementationGap || $0.status == .unknown }
    }

    func entry(for capability: ZoomItFeatureCapability) -> ZoomItFeatureCoverageEntry? {
        entries.first { $0.capability == capability }
    }

    static var phase6Default: ZoomItFeatureCoverageMap {
        let required = ZoomItFeatureCapability.prdSection5_1
        let requiredSet = Set(required)
        var entries: [ZoomItFeatureCoverageEntry] = [
            .complete(.staticZoom, implementationRefs: [
                "Sources/ZoomItMacCore/Overlay/ZoomViewportController.swift",
                "Sources/ZoomItMacCore/Overlay/OverlayInteractionLifecycle.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase4StaticZoomLifecycleTests.swift",
                "Tests/ZoomItMacCoreTests/Phase4OverlayHUDPresentationTests.swift"
            ]),
            .complete(.liveZoom, implementationRefs: [
                "Sources/ZoomItMacCore/Overlay/LiveZoomInteractionPolicy.swift",
                "Sources/ZoomItMacCore/Core/LiveZoomCommandPolicy.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase4LiveZoomInteractionPolicyTests.swift",
                "Tests/ZoomItMacCoreTests/Phase4LiveZoomCommandPolicyTests.swift"
            ]),
            .complete(.drawWithoutZoom, implementationRefs: [
                "Sources/ZoomItMacCore/Core/AppSessionState.swift",
                "Sources/ZoomItMacCore/Annotations/AnnotationController.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase2ContractTests.swift",
                "Tests/ZoomItMacCoreTests/Phase4AnnotationRenderPlanTests.swift"
            ]),
            .complete(.liveDraw, implementationRefs: [
                "Sources/ZoomItMacCore/Core/AppSessionState.swift",
                "Sources/ZoomItMacCore/Capture/LiveCaptureSession.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase4LiveZoomInteractionPolicyTests.swift",
                "Tests/ZoomItMacCoreTests/Phase5RecordingCompositionIsolationTests.swift"
            ]),
            .complete(.freehandPen, implementationRefs: [
                "Sources/ZoomItMacCore/Annotations/Annotation.swift",
                "Sources/ZoomItMacCore/Annotations/AnnotationRenderPlan.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase4AnnotationRenderPlanTests.swift"
            ], phase7Refs: []),
            .complete(.shapeTools, implementationRefs: [
                "Sources/ZoomItMacCore/Annotations/Annotation.swift",
                "Sources/ZoomItMacCore/Annotations/AnnotationRenderPlan.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase4AnnotationRenderPlanTests.swift"
            ], phase7Refs: []),
            .complete(.colorPensAndTranslucentHighlight, implementationRefs: [
                "Sources/ZoomItMacCore/Annotations/Annotation.swift",
                "Sources/ZoomItMacCore/Hotkeys/DrawingShortcutPolicy.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase2ContractTests.swift",
                "Tests/ZoomItMacCoreTests/Phase4AnnotationRenderPlanTests.swift"
            ], phase7Refs: []),
            .complete(.whiteAndBlackPens, implementationRefs: [
                "Sources/ZoomItMacCore/Annotations/Annotation.swift",
                "Sources/ZoomItMacCore/Hotkeys/DrawingShortcutPolicy.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase2ContractTests.swift"
            ], phase7Refs: []),
            .complete(.whiteboardAndBlackboard, implementationRefs: [
                "Sources/ZoomItMacCore/Core/AppSessionState.swift",
                "Sources/ZoomItMacCore/Hotkeys/DrawingShortcutCommandPolicy.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase2ContractTests.swift",
                "Tests/ZoomItMacCoreTests/Phase4CanvasBackgroundTests.swift"
            ]),
            .complete(.textInputAlignmentAndFontSize, implementationRefs: [
                "Sources/ZoomItMacCore/Annotations/Annotation.swift",
                "Sources/ZoomItMacCore/Hotkeys/DrawingShortcutCommandPolicy.swift",
                "Sources/ZoomItMacCore/Settings/SettingsStore.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase4AnnotationRenderPlanTests.swift"
            ], phase7Refs: []),
            .complete(.undoAndClearAnnotations, implementationRefs: [
                "Sources/ZoomItMacCore/Annotations/AnnotationController.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase4AnnotationRenderPlanTests.swift"
            ], phase7Refs: []),
            .complete(.currentViewportCopyAndSave, implementationRefs: [
                "Sources/ZoomItMacCore/Capture/ImageExporter.swift",
                "Sources/ZoomItMacCore/Overlay/ZoomCanvasView.swift",
                "Sources/ZoomItMacCore/Capture/ImageExportSimulation.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase6ImageExportSimulationTests.swift"
            ]),
            .complete(.regionSnipToClipboard, implementationRefs: [
                "Sources/ZoomItMacCore/Capture/SnipController.swift",
                "Sources/ZoomItMacCore/Capture/SnipExportPlan.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase3SnipExportPlanTests.swift",
                "Tests/ZoomItMacCoreTests/Phase3RegionSelectionLifecycleTests.swift"
            ]),
            .complete(.regionSnipToFile, implementationRefs: [
                "Sources/ZoomItMacCore/Capture/SnipController.swift",
                "Sources/ZoomItMacCore/Capture/SnipExportPlan.swift",
                "Sources/ZoomItMacCore/Capture/ImageExportSimulation.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase3SnipExportPlanTests.swift",
                "Tests/ZoomItMacCoreTests/Phase6ImageExportSimulationTests.swift"
            ]),
            .complete(.regionOCRToClipboard, implementationRefs: [
                "Sources/ZoomItMacCore/Capture/OcrService.swift",
                "Sources/ZoomItMacCore/Capture/SnipController.swift",
                "Sources/ZoomItMacCore/Capture/ImageExportSimulation.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase3SnipExportPlanTests.swift",
                "Tests/ZoomItMacCoreTests/Phase6ImageExportSimulationTests.swift"
            ]),
            .complete(.fullScreenRecording, implementationRefs: [
                "Sources/ZoomItMacCore/Capture/RecordingController.swift",
                "Sources/ZoomItMacCore/Capture/RecordingCaptureRequestPlan.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase5RecordingTargetRequestPlanTests.swift"
            ]),
            .complete(.regionRecording, implementationRefs: [
                "Sources/ZoomItMacCore/Capture/RecordingController.swift",
                "Sources/ZoomItMacCore/Capture/RecordingCaptureRequestPlan.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase5RecordingTargetRequestPlanTests.swift"
            ]),
            .complete(.windowRecording, implementationRefs: [
                "Sources/ZoomItMacCore/Capture/RecordingController.swift",
                "Sources/ZoomItMacCore/Capture/RecordingCaptureRequestPlan.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase5RecordingTargetRequestPlanTests.swift"
            ]),
            .complete(.systemAudioAndMicrophoneRecording, implementationRefs: [
                "Sources/ZoomItMacCore/Capture/RecordingMediaInputPlan.swift",
                "Sources/ZoomItMacCore/Capture/RecordingController.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase5RecordingMediaInputPlanTests.swift"
            ]),
            .complete(.webcamPictureInPicture, implementationRefs: [
                "Sources/ZoomItMacCore/Capture/WebcamOverlayController.swift",
                "Sources/ZoomItMacCore/Capture/RecordingMediaInputPlan.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase5RecordingMediaInputPlanTests.swift",
                "Tests/ZoomItMacCoreTests/Phase5RecordingCompositionIsolationTests.swift"
            ]),
            .complete(.postRecordingEditor, implementationRefs: [
                "Sources/ZoomItMacCore/Capture/VideoClipEditorController.swift",
                "Sources/ZoomItMacCore/Capture/RecordingEditorDecisionGraph.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase5RecordingEditorDecisionPlanTests.swift"
            ], phase7Refs: [.localSimulationAcceptance, .mediaCompatibilityMatrix]),
            .complete(.breakTimer, implementationRefs: [
                "Sources/ZoomItMacCore/Overlay/BreakTimerController.swift",
                "Sources/ZoomItMacCore/Core/ModeCoordinator.swift",
                "Sources/ZoomItMacCore/Core/Phase6InteractionReplaySimulation.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase6TimerDemoTypeSimulationTests.swift"
            ]),
            .complete(.demoType, implementationRefs: [
                "Sources/ZoomItMacCore/App/DemoTypeController.swift",
                "Sources/ZoomItMacCore/Core/ModeCoordinator.swift",
                "Sources/ZoomItMacCore/Core/Phase6InteractionReplaySimulation.swift"
            ], simulatedTestRefs: [
                "Sources/ZoomItMacCore/SelfTest/SelfTestRunner.swift",
                "Tests/ZoomItMacCoreTests/Phase6TimerDemoTypeSimulationTests.swift"
            ]),
            .complete(.panoramaClipboardOrFile, implementationRefs: [
                "Sources/ZoomItMacCore/Capture/PanoramaController.swift",
                "Sources/ZoomItMacCore/Capture/PanoramaStitcher.swift",
                "Sources/ZoomItMacCore/Capture/PanoramaSimulation.swift"
            ], simulatedTestRefs: [
                "Sources/ZoomItMacCore/SelfTest/SelfTestRunner.swift",
                "Tests/ZoomItMacCoreTests/Phase6PanoramaSimulationTests.swift"
            ]),
            .complete(.settingsAndHotkeyCustomization, implementationRefs: [
                "Sources/ZoomItMacCore/Settings/SettingsStore.swift",
                "Sources/ZoomItMacCore/Settings/SettingsWindowController.swift",
                "Sources/ZoomItMacCore/Hotkeys/HotkeyService.swift",
                "Sources/ZoomItMacCore/Settings/SettingsManagementSimulation.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase6SettingsPermissionsSimulationTests.swift"
            ]),
            .complete(.drawingTextRecordingWebcamPanoramaAndLaunchSettings, implementationRefs: [
                "Sources/ZoomItMacCore/Settings/SettingsStore.swift",
                "Sources/ZoomItMacCore/Settings/SettingsWindowController.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase2ContractTests.swift",
                "Tests/ZoomItMacCoreTests/Phase5RecordingMediaInputPlanTests.swift"
            ], phase7Refs: [.localSimulationAcceptance]),
            .complete(.singleInstance, implementationRefs: [
                "Sources/ZoomItMacCore/App/SingleInstance.swift",
                "Sources/ZoomItMacCore/App/AppDelegate.swift",
                "Sources/ZoomItMacCore/App/AppLifecycleManagementSimulation.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase6AppLifecycleSimulationTests.swift"
            ]),
            .complete(.menuBarStatus, implementationRefs: [
                "Sources/ZoomItMacCore/App/AppDelegate.swift",
                "Sources/ZoomItMacCore/Core/AppSessionState.swift",
                "Sources/ZoomItMacCore/App/AppLifecycleManagementSimulation.swift"
            ], simulatedTestRefs: [
                "Sources/ZoomItMacCore/SelfTest/SelfTestRunner.swift",
                "Tests/ZoomItMacCoreTests/Phase6AppLifecycleSimulationTests.swift"
            ]),
            .complete(.permissionChecks, implementationRefs: [
                "Sources/ZoomItMacCore/Permissions/PermissionService.swift",
                "Sources/ZoomItMacCore/App/AppController.swift",
                "Sources/ZoomItMacCore/Settings/SettingsManagementSimulation.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase3PastePermissionMatrixTests.swift",
                "Tests/ZoomItMacCoreTests/Phase3PastePermissionPresentationTests.swift",
                "Tests/ZoomItMacCoreTests/Phase6SettingsPermissionsSimulationTests.swift"
            ]),
            .complete(.launchAtLogin, implementationRefs: [
                "Sources/ZoomItMacCore/App/LaunchAtLogin.swift",
                "Sources/ZoomItMacCore/Settings/SettingsWindowController.swift",
                "Sources/ZoomItMacCore/App/AppLifecycleManagementSimulation.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase6AppLifecycleSimulationTests.swift"
            ]),
            .complete(.pasteCompatibility, implementationRefs: [
                "Sources/ZoomItMacCore/App/PasteCompatibilityService.swift",
                "Sources/ZoomItMacCore/App/PasteCompatibilityEventTap.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase2ContractTests.swift",
                "Tests/ZoomItMacCoreTests/Phase3EventTapTests.swift"
            ]),
            .complete(.cursorFeedback, implementationRefs: [
                "Sources/ZoomItMacCore/Core/AppSessionState.swift",
                "Sources/ZoomItMacCore/Overlay/OverlayPointerPresentation.swift",
                "Sources/ZoomItMacCore/Capture/SnipController.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase2ContractTests.swift",
                "Tests/ZoomItMacCoreTests/Phase4OverlayPointerPresentationTests.swift",
                "Tests/ZoomItMacCoreTests/Phase4PointerResourceTests.swift"
            ])
        ]

        for index in entries.indices {
            entries[index].isPRDRequired = requiredSet.contains(entries[index].capability)
        }

        return ZoomItFeatureCoverageMap(
            requiredCapabilities: required,
            entries: entries,
            platformBoundary: .simulatedOnly
        )
    }
}

private extension ZoomItFeatureCoverageEntry {
    static func complete(
        _ capability: ZoomItFeatureCapability,
        implementationRefs: [String],
        simulatedTestRefs: [String],
        phase7Refs: [ZoomItFeaturePhase7Ref] = [.localSimulationAcceptance]
    ) -> ZoomItFeatureCoverageEntry {
        ZoomItFeatureCoverageEntry(
            capability: capability,
            isPRDRequired: false,
            implementationRefs: implementationRefs,
            simulatedTestRefs: simulatedTestRefs,
            phase7Refs: phase7Refs,
            status: .localSimulationAccepted
        )
    }

    static func gap(
        _ capability: ZoomItFeatureCapability,
        implementationRefs: [String],
        simulatedTestRefs: [String]
    ) -> ZoomItFeatureCoverageEntry {
        ZoomItFeatureCoverageEntry(
            capability: capability,
            isPRDRequired: false,
            implementationRefs: implementationRefs,
            simulatedTestRefs: simulatedTestRefs,
            phase7Refs: [.localSimulationAcceptance],
            status: .phase6ImplementationGap
        )
    }
}
