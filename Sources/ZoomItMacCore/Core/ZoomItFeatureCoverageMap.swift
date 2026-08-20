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
    case permissionCenter
    case macSettingsNavigation
    case transientModeFeedback
    case displaySynchronizedZoom
    case blurAndRedact
    case previousRegionSnip
    case windowSnipToClipboard
    case numberedCallouts
    case multiDisplayTargeting
    case recordingPreflight
    case recordingPauseAndResume
    case recordingRecovery
    case recordingClickAndShortcutOverlay
    case lightweightRecordingResult

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
        .launchAtLogin,
        .pasteCompatibility,
        .cursorFeedback,
        .permissionCenter,
        .macSettingsNavigation,
        .transientModeFeedback,
        .displaySynchronizedZoom,
        .blurAndRedact,
        .previousRegionSnip,
        .windowSnipToClipboard,
        .numberedCallouts,
        .multiDisplayTargeting,
        .recordingPreflight,
        .recordingPauseAndResume,
        .recordingRecovery,
        .recordingClickAndShortcutOverlay,
        .lightweightRecordingResult
    ]
}

enum ZoomItFeatureCoverageStatus: Equatable, Sendable {
    case unknown
    case localSimulationAccepted
    case implementationGap
}

enum ZoomItFeatureProductTier: Equatable, Sendable {
    case unclassified
    case defaultCore
    case advancedCompatibility
    case sharedPlatform
}

enum ZoomItFeatureEvidenceRef: Equatable, Hashable, Sendable {
    case localSimulationAcceptance
    case mediaCompatibilityMatrix
    case userManualAcceptance
}

enum ZoomItFeatureCoverageValidationIssue: Equatable, Sendable {
    case missingRequiredEntry(ZoomItFeatureCapability)
    case unclassifiedRequiredCapability(ZoomItFeatureCapability)
    case unknownStatus(ZoomItFeatureCapability)
    case acceptedWithoutImplementationEvidence(ZoomItFeatureCapability)
    case acceptedWithoutSimulationEvidence(ZoomItFeatureCapability)
    case acceptedWithoutLocalSimulationEvidence(ZoomItFeatureCapability)
    case acceptedStillHasPlannedWork(ZoomItFeatureCapability)
    case gapWithoutPlannedImplementation(ZoomItFeatureCapability)
    case gapWithoutPlannedSimulationTest(ZoomItFeatureCapability)
    case gapClaimsCompletedEvidence(ZoomItFeatureCapability)
}

struct ZoomItFeatureCoverageEntry: Equatable, Sendable {
    var capability: ZoomItFeatureCapability
    var isPRDRequired: Bool
    var productTier: ZoomItFeatureProductTier
    var implementationRefs: [String]
    var simulatedTestRefs: [String]
    var plannedImplementationRefs: [String]
    var plannedSimulatedTestRefs: [String]
    var evidenceRefs: [ZoomItFeatureEvidenceRef]
    var status: ZoomItFeatureCoverageStatus
}

struct ZoomItFeatureCoverageMap: Equatable, Sendable {
    var requiredCapabilities: [ZoomItFeatureCapability]
    var entries: [ZoomItFeatureCoverageEntry]
    var platformBoundary: AutomationPlatformBoundary

    var gaps: [ZoomItFeatureCoverageEntry] {
        entries.filter { $0.status == .implementationGap || $0.status == .unknown }
    }

    var validationIssues: [ZoomItFeatureCoverageValidationIssue] {
        var issues: [ZoomItFeatureCoverageValidationIssue] = []

        for capability in requiredCapabilities {
            guard let entry = entry(for: capability) else {
                issues.append(.missingRequiredEntry(capability))
                continue
            }

            if entry.productTier == .unclassified {
                issues.append(.unclassifiedRequiredCapability(capability))
            }

            switch entry.status {
            case .unknown:
                issues.append(.unknownStatus(capability))
            case .localSimulationAccepted:
                if entry.implementationRefs.isEmpty {
                    issues.append(.acceptedWithoutImplementationEvidence(capability))
                }
                if entry.simulatedTestRefs.isEmpty {
                    issues.append(.acceptedWithoutSimulationEvidence(capability))
                }
                if !entry.evidenceRefs.contains(.localSimulationAcceptance) {
                    issues.append(.acceptedWithoutLocalSimulationEvidence(capability))
                }
                if !entry.plannedImplementationRefs.isEmpty || !entry.plannedSimulatedTestRefs.isEmpty {
                    issues.append(.acceptedStillHasPlannedWork(capability))
                }
            case .implementationGap:
                if entry.plannedImplementationRefs.isEmpty {
                    issues.append(.gapWithoutPlannedImplementation(capability))
                }
                if entry.plannedSimulatedTestRefs.isEmpty {
                    issues.append(.gapWithoutPlannedSimulationTest(capability))
                }
                if !entry.implementationRefs.isEmpty || !entry.simulatedTestRefs.isEmpty {
                    issues.append(.gapClaimsCompletedEvidence(capability))
                }
            }
        }

        return issues
    }

    func entry(for capability: ZoomItFeatureCapability) -> ZoomItFeatureCoverageEntry? {
        entries.first { $0.capability == capability }
    }

    static var current: ZoomItFeatureCoverageMap {
        let required = ZoomItFeatureCapability.prdSection5_1
        let requiredSet = Set(required)
        var entries: [ZoomItFeatureCoverageEntry] = [
            .complete(.staticZoom, implementationRefs: [
                "Sources/ZoomItMacCore/Overlay/ZoomViewportController.swift",
                "Sources/ZoomItMacCore/Overlay/OverlayInteractionLifecycle.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase4StaticZoomLifecycleTests.swift",
                "Tests/ZoomItMacCoreTests/AppleTransientFeedbackTests.swift",
                "Tests/ZoomItMacCoreTests/AppleDisplaySynchronizedZoomTests.swift"
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
            ]),
            .complete(.shapeTools, implementationRefs: [
                "Sources/ZoomItMacCore/Annotations/Annotation.swift",
                "Sources/ZoomItMacCore/Annotations/AnnotationRenderPlan.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase4AnnotationRenderPlanTests.swift"
            ]),
            .complete(.colorPensAndTranslucentHighlight, implementationRefs: [
                "Sources/ZoomItMacCore/Annotations/Annotation.swift",
                "Sources/ZoomItMacCore/Hotkeys/DrawingShortcutPolicy.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase2ContractTests.swift",
                "Tests/ZoomItMacCoreTests/Phase4AnnotationRenderPlanTests.swift"
            ]),
            .complete(.whiteAndBlackPens, implementationRefs: [
                "Sources/ZoomItMacCore/Annotations/Annotation.swift",
                "Sources/ZoomItMacCore/Hotkeys/DrawingShortcutPolicy.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase2ContractTests.swift"
            ]),
            .complete(.whiteboardAndBlackboard, implementationRefs: [
                "Sources/ZoomItMacCore/Core/AppSessionState.swift",
                "Sources/ZoomItMacCore/Hotkeys/DrawingShortcutCommandPolicy.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase2ContractTests.swift",
                "Tests/ZoomItMacCoreTests/Phase4CanvasBackgroundTests.swift"
            ]),
            .complete(.textInputAlignmentAndFontSize, implementationRefs: [
                "Sources/ZoomItMacCore/Annotations/Annotation.swift",
                "Sources/ZoomItMacCore/Annotations/AnnotationController.swift",
                "Sources/ZoomItMacCore/App/ControlVPasteHotkeyService.swift",
                "Sources/ZoomItMacCore/App/PasteCompatibilityService.swift",
                "Sources/ZoomItMacCore/Hotkeys/DrawingShortcutCommandPolicy.swift",
                "Sources/ZoomItMacCore/Overlay/CanvasTextEditingSession.swift",
                "Sources/ZoomItMacCore/Overlay/ZoomCanvasView.swift",
                "Sources/ZoomItMacCore/Settings/SettingsStore.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/AppleNativeTextEditingTests.swift",
                "Tests/ZoomItMacCoreTests/AppleShortcutGuideConsistencyTests.swift",
                "Tests/ZoomItMacCoreTests/Phase3EventTapTests.swift",
                "Tests/ZoomItMacCoreTests/Phase4AnnotationRenderPlanTests.swift"
            ], evidenceRefs: [.localSimulationAcceptance, .userManualAcceptance]),
            .complete(.undoAndClearAnnotations, implementationRefs: [
                "Sources/ZoomItMacCore/Annotations/AnnotationController.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase4AnnotationRenderPlanTests.swift"
            ]),
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
            .complete(.regionSnipToFile, productTier: .advancedCompatibility, implementationRefs: [
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
                "Sources/ZoomItMacCore/Capture/SnipExportPlan.swift",
                "Sources/ZoomItMacCore/Core/ModeCoordinator.swift",
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
            .complete(.webcamPictureInPicture, productTier: .advancedCompatibility, implementationRefs: [
                "Sources/ZoomItMacCore/Capture/WebcamOverlayController.swift",
                "Sources/ZoomItMacCore/Capture/RecordingMediaInputPlan.swift",
                "Sources/ZoomItMacCore/Capture/WebcamDirectManipulationPolicy.swift",
                "Sources/ZoomItMacCore/Overlay/DisplaySynchronizedMotionClock.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase5RecordingMediaInputPlanTests.swift",
                "Tests/ZoomItMacCoreTests/Phase5RecordingCompositionIsolationTests.swift",
                "Tests/ZoomItMacCoreTests/AppleWebcamDirectManipulationTests.swift"
            ]),
            .complete(.postRecordingEditor, productTier: .advancedCompatibility, implementationRefs: [
                "Sources/ZoomItMacCore/Capture/VideoClipEditorController.swift",
                "Sources/ZoomItMacCore/Capture/RecordingEditorDecisionGraph.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase5RecordingEditorDecisionPlanTests.swift"
            ], evidenceRefs: [.localSimulationAcceptance, .mediaCompatibilityMatrix, .userManualAcceptance]),
            .complete(.breakTimer, productTier: .advancedCompatibility, implementationRefs: [
                "Sources/ZoomItMacCore/Overlay/BreakTimerController.swift",
                "Sources/ZoomItMacCore/Core/ModeCoordinator.swift",
                "Sources/ZoomItMacCore/Core/Phase6InteractionReplaySimulation.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase6TimerDemoTypeSimulationTests.swift"
            ]),
            .complete(.demoType, productTier: .advancedCompatibility, implementationRefs: [
                "Sources/ZoomItMacCore/App/DemoTypeController.swift",
                "Sources/ZoomItMacCore/Core/ModeCoordinator.swift",
                "Sources/ZoomItMacCore/Core/Phase6InteractionReplaySimulation.swift"
            ], simulatedTestRefs: [
                "Sources/ZoomItMacCore/SelfTest/SelfTestRunner.swift",
                "Tests/ZoomItMacCoreTests/Phase6TimerDemoTypeSimulationTests.swift"
            ]),
            .complete(.panoramaClipboardOrFile, productTier: .advancedCompatibility, implementationRefs: [
                "Sources/ZoomItMacCore/Capture/PanoramaController.swift",
                "Sources/ZoomItMacCore/Capture/PanoramaStitcher.swift",
                "Sources/ZoomItMacCore/Capture/PanoramaSimulation.swift"
            ], simulatedTestRefs: [
                "Sources/ZoomItMacCore/SelfTest/SelfTestRunner.swift",
                "Tests/ZoomItMacCoreTests/Phase6PanoramaSimulationTests.swift"
            ]),
            .complete(.settingsAndHotkeyCustomization, productTier: .sharedPlatform, implementationRefs: [
                "Sources/ZoomItMacCore/Settings/SettingsStore.swift",
                "Sources/ZoomItMacCore/Settings/SettingsWindowController.swift",
                "Sources/ZoomItMacCore/Hotkeys/HotkeyService.swift",
                "Sources/ZoomItMacCore/Settings/SettingsManagementSimulation.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase6SettingsPermissionsSimulationTests.swift"
            ]),
            .complete(.drawingTextRecordingWebcamPanoramaAndLaunchSettings, productTier: .advancedCompatibility, implementationRefs: [
                "Sources/ZoomItMacCore/Settings/SettingsStore.swift",
                "Sources/ZoomItMacCore/Settings/SettingsWindowController.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase2ContractTests.swift",
                "Tests/ZoomItMacCoreTests/Phase5RecordingMediaInputPlanTests.swift"
            ], evidenceRefs: [.localSimulationAcceptance, .userManualAcceptance]),
            .complete(.singleInstance, productTier: .sharedPlatform, implementationRefs: [
                "Sources/ZoomItMacCore/App/SingleInstance.swift",
                "Sources/ZoomItMacCore/App/AppDelegate.swift",
                "Sources/ZoomItMacCore/App/AppLifecycleManagementSimulation.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase6AppLifecycleSimulationTests.swift"
            ]),
            .complete(.menuBarStatus, productTier: .sharedPlatform, implementationRefs: [
                "Sources/ZoomItMacCore/App/AppDelegate.swift",
                "Sources/ZoomItMacCore/App/StatusMenuPlan.swift",
                "Sources/ZoomItMacCore/Core/AppSessionState.swift",
                "Sources/ZoomItMacCore/App/AppLifecycleManagementSimulation.swift"
            ], simulatedTestRefs: [
                "Sources/ZoomItMacCore/SelfTest/SelfTestRunner.swift",
                "Tests/ZoomItMacCoreTests/Phase6AppLifecycleSimulationTests.swift"
            ]),
            .complete(.permissionChecks, productTier: .sharedPlatform, implementationRefs: [
                "Sources/ZoomItMacCore/Permissions/PermissionService.swift",
                "Sources/ZoomItMacCore/App/AppController.swift",
                "Sources/ZoomItMacCore/Settings/SettingsManagementSimulation.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase3PastePermissionMatrixTests.swift",
                "Tests/ZoomItMacCoreTests/Phase3PastePermissionPresentationTests.swift",
                "Tests/ZoomItMacCoreTests/Phase6SettingsPermissionsSimulationTests.swift"
            ]),
            .complete(.launchAtLogin, productTier: .advancedCompatibility, implementationRefs: [
                "Sources/ZoomItMacCore/App/LaunchAtLogin.swift",
                "Sources/ZoomItMacCore/Settings/SettingsWindowController.swift",
                "Sources/ZoomItMacCore/App/AppLifecycleManagementSimulation.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase6AppLifecycleSimulationTests.swift"
            ]),
            .complete(.pasteCompatibility, productTier: .sharedPlatform, implementationRefs: [
                "Sources/ZoomItMacCore/App/PasteCompatibilityService.swift",
                "Sources/ZoomItMacCore/App/PasteCompatibilityEventTap.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase2ContractTests.swift",
                "Tests/ZoomItMacCoreTests/Phase3EventTapTests.swift"
            ]),
            .complete(.cursorFeedback, productTier: .sharedPlatform, implementationRefs: [
                "Sources/ZoomItMacCore/Core/AppSessionState.swift",
                "Sources/ZoomItMacCore/Overlay/OverlayPointerPresentation.swift",
                "Sources/ZoomItMacCore/Overlay/FeedbackPresentationAdapter.swift",
                "Sources/ZoomItMacCore/Capture/SnipController.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/Phase2ContractTests.swift",
                "Tests/ZoomItMacCoreTests/Phase4OverlayPointerPresentationTests.swift",
                "Tests/ZoomItMacCoreTests/Phase4PointerResourceTests.swift",
                "Tests/ZoomItMacCoreTests/ApplePointerPresentationTests.swift"
            ]),
            .complete(.permissionCenter, productTier: .sharedPlatform, implementationRefs: [
                "Sources/ZoomItMacCore/Permissions/PermissionCenterModel.swift",
                "Sources/ZoomItMacCore/Permissions/PermissionCenterCoordinator.swift",
                "Sources/ZoomItMacCore/Permissions/PermissionCenterWindowController.swift",
                "Sources/ZoomItMacCore/Permissions/PermissionCenterSystemAdapter.swift",
                "Sources/ZoomItMacCore/App/AppController.swift",
                "Sources/ZoomItMacCore/App/AppDelegate.swift",
                "Sources/ZoomItMacCore/App/PasteCompatibilityService.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/ApplePermissionCenterTests.swift",
                "Tests/ZoomItMacCoreTests/Phase2ContractTests.swift",
                "Tests/ZoomItMacCoreTests/Phase3PastePermissionMatrixTests.swift"
            ]),
            .complete(.macSettingsNavigation, productTier: .sharedPlatform, implementationRefs: [
                "Sources/ZoomItMacCore/Settings/SettingsNavigationModel.swift",
                "Sources/ZoomItMacCore/Settings/HotkeyCaptureSession.swift",
                "Sources/ZoomItMacCore/Settings/SettingsWindowController.swift",
                "Sources/ZoomItMacCore/App/AppController.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/AppleSettingsNavigationTests.swift"
            ]),
            .complete(.transientModeFeedback, productTier: .sharedPlatform, implementationRefs: [
                "Sources/ZoomItMacCore/Overlay/FeedbackPresentationAdapter.swift",
                "Sources/ZoomItMacCore/Overlay/TransientFeedbackWindowController.swift",
                "Sources/ZoomItMacCore/Core/ModeCoordinator.swift",
                "Sources/ZoomItMacCore/Overlay/ZoomCanvasView.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/AppleTransientFeedbackTests.swift"
            ]),
            .complete(.displaySynchronizedZoom, productTier: .sharedPlatform, implementationRefs: [
                "Sources/ZoomItMacCore/Overlay/DisplaySynchronizedMotionClock.swift",
                "Sources/ZoomItMacCore/Overlay/ZoomViewportController.swift",
                "Sources/ZoomItMacCore/Overlay/OverlayWindowController.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/AppleDisplaySynchronizedZoomTests.swift"
            ]),
            .complete(.blurAndRedact, implementationRefs: [
                "Sources/ZoomItMacCore/Annotations/Annotation.swift",
                "Sources/ZoomItMacCore/Annotations/AnnotationRenderPlan.swift",
                "Sources/ZoomItMacCore/Annotations/AnnotationController.swift",
                "Sources/ZoomItMacCore/Annotations/PrivacyAnnotationCompositor.swift",
                "Sources/ZoomItMacCore/Overlay/ZoomCanvasView.swift",
                "Sources/ZoomItMacCore/Hotkeys/DrawingShortcutPolicy.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/AppleBlurAndRedactTests.swift"
            ]),
            .complete(.previousRegionSnip, implementationRefs: [
                "Sources/ZoomItMacCore/Capture/PreviousRegionSnipPolicy.swift",
                "Sources/ZoomItMacCore/Capture/SnipController.swift",
                "Sources/ZoomItMacCore/Core/ModeCoordinator.swift",
                "Sources/ZoomItMacCore/App/AppController.swift",
                "Sources/ZoomItMacCore/App/AppDelegate.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/ApplePreviousRegionSnipTests.swift"
            ]),
            .complete(.windowSnipToClipboard, implementationRefs: [
                "Sources/ZoomItMacCore/Capture/WindowSnipRequestPlan.swift",
                "Sources/ZoomItMacCore/Capture/WindowCaptureService.swift",
                "Sources/ZoomItMacCore/Capture/SnipController.swift",
                "Sources/ZoomItMacCore/Settings/SettingsStore.swift",
                "Sources/ZoomItMacCore/Core/ModeCoordinator.swift",
                "Sources/ZoomItMacCore/App/AppDelegate.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/AppleWindowSnipTests.swift"
            ]),
            .complete(.numberedCallouts, implementationRefs: [
                "Sources/ZoomItMacCore/Annotations/Annotation.swift",
                "Sources/ZoomItMacCore/Annotations/AnnotationController.swift",
                "Sources/ZoomItMacCore/Annotations/AnnotationRenderPlan.swift",
                "Sources/ZoomItMacCore/Overlay/ZoomCanvasView.swift",
                "Sources/ZoomItMacCore/Hotkeys/DrawingShortcutPolicy.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/AppleNumberedCalloutTests.swift"
            ]),
            .complete(.multiDisplayTargeting, productTier: .sharedPlatform, implementationRefs: [
                "Sources/ZoomItMacCore/Display/DisplayManager.swift",
                "Sources/ZoomItMacCore/Core/MultiDisplayTargetingPolicy.swift",
                "Sources/ZoomItMacCore/Capture/SnipController.swift",
                "Sources/ZoomItMacCore/Capture/WindowCaptureService.swift",
                "Sources/ZoomItMacCore/Overlay/TransientFeedbackWindowController.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/AppleMultiDisplayTargetingTests.swift"
            ]),
            .complete(.recordingPreflight, implementationRefs: [
                "Sources/ZoomItMacCore/Capture/RecordingPreflightPlan.swift",
                "Sources/ZoomItMacCore/Capture/RecordingPreflightCoordinator.swift",
                "Sources/ZoomItMacCore/Capture/RecordingController.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/AppleRecordingPreflightTests.swift"
            ]),
            .complete(.recordingPauseAndResume, implementationRefs: [
                "Sources/ZoomItMacCore/Capture/RecordingPauseTimeline.swift",
                "Sources/ZoomItMacCore/Capture/RecordingController.swift",
                "Sources/ZoomItMacCore/Core/ModeCoordinator.swift",
                "Sources/ZoomItMacCore/App/AppDelegate.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/AppleRecordingPauseResumeTests.swift"
            ]),
            .complete(.recordingRecovery, implementationRefs: [
                "Sources/ZoomItMacCore/Capture/RecordingRecoveryPlan.swift",
                "Sources/ZoomItMacCore/Capture/RecordingRecoveryCoordinator.swift",
                "Sources/ZoomItMacCore/Capture/RecordingController.swift",
                "Sources/ZoomItMacCore/App/AppDelegate.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/AppleRecordingRecoveryTests.swift"
            ]),
            .complete(.recordingClickAndShortcutOverlay, implementationRefs: [
                "Sources/ZoomItMacCore/Capture/RecordingInputOverlayPlan.swift",
                "Sources/ZoomItMacCore/Capture/RecordingInputOverlayController.swift",
                "Sources/ZoomItMacCore/Capture/RecordingController.swift",
                "Sources/ZoomItMacCore/Settings/SettingsStore.swift",
                "Sources/ZoomItMacCore/Settings/SettingsWindowController.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/AppleRecordingInputOverlayTests.swift"
            ]),
            .complete(.lightweightRecordingResult, implementationRefs: [
                "Sources/ZoomItMacCore/Capture/RecordingResultController.swift",
                "Sources/ZoomItMacCore/Capture/VideoClipEditorController.swift",
                "Sources/ZoomItMacCore/Capture/RecordingController.swift"
            ], simulatedTestRefs: [
                "Tests/ZoomItMacCoreTests/AppleRecordingResultTests.swift"
            ], evidenceRefs: [.localSimulationAcceptance, .userManualAcceptance])
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
        productTier: ZoomItFeatureProductTier = .defaultCore,
        implementationRefs: [String],
        simulatedTestRefs: [String],
        evidenceRefs: [ZoomItFeatureEvidenceRef] = [.localSimulationAcceptance]
    ) -> ZoomItFeatureCoverageEntry {
        ZoomItFeatureCoverageEntry(
            capability: capability,
            isPRDRequired: false,
            productTier: productTier,
            implementationRefs: implementationRefs,
            simulatedTestRefs: simulatedTestRefs,
            plannedImplementationRefs: [],
            plannedSimulatedTestRefs: [],
            evidenceRefs: evidenceRefs,
            status: .localSimulationAccepted
        )
    }

    static func gap(
        _ capability: ZoomItFeatureCapability,
        productTier: ZoomItFeatureProductTier = .defaultCore,
        plannedImplementationRefs: [String],
        plannedSimulatedTestRefs: [String],
        evidenceRefs: [ZoomItFeatureEvidenceRef] = [.localSimulationAcceptance, .userManualAcceptance]
    ) -> ZoomItFeatureCoverageEntry {
        ZoomItFeatureCoverageEntry(
            capability: capability,
            isPRDRequired: false,
            productTier: productTier,
            implementationRefs: [],
            simulatedTestRefs: [],
            plannedImplementationRefs: plannedImplementationRefs,
            plannedSimulatedTestRefs: plannedSimulatedTestRefs,
            evidenceRefs: evidenceRefs,
            status: .implementationGap
        )
    }
}
