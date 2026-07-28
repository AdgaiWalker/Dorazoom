# DoraZoom Validation Record

> Last updated: 2026-07-28 10:03:18 CST

## Phase 1 Baseline

### Upstream Source

- Repository: `https://github.com/microsoft/ZoomitForMac.git`
- Commit: `b03e43da91cd84eeb8f691fa65095e0304c3e660`
- Tree: `a52c6c41f002bf329635a14f1cfe563784046711`
- Commit date: `2026-07-23 16:24:26 -0700`
- Commit subject: `Merge pull request #38 from microsoft/optionslayout`
- License: `LICENSE` imported from upstream; MIT license present.

Imported upstream files:

- `.github/ISSUE_TEMPLATE/bug-report.yml`
- `.github/dependabot.yml`
- `.gitignore`
- `LICENSE`
- `Package.swift`
- `README.md`
- `SECURITY.md`
- `Scripts/ZoomIt.entitlements`
- `Scripts/build-app.sh`
- `Scripts/reset-first-run.sh`
- `Sources/ZoomItMacApp/main.swift`
- `Sources/ZoomItMacCore/**`
- `Sources/ZoomItMacSelfTest/main.swift`
- `ZoomItInfo.plist`

DoraZoom local documents preserved:

- `PRD.md`
- `ARCHITECTURE.md`
- `GOAL.md`
- `VALIDATION.md`

### Environment

- Xcode: `Xcode 26.6`, build `17F113`
- Swift: `Apple Swift version 6.3.3`, target `arm64-apple-macosx28.0`
- Code signing identities: one valid Apple Development identity found: `Apple Development: cong ni (33KBM3H2B8)`
- Phase 1 app build used ad-hoc signing, not the Apple Development certificate.

### Size And Code Volume

- Working source files, excluding `.git` and `.build`: 55 files
- Working source payload, excluding `.git` and `.build`: 856 KB
- Swift source lines under `Sources`: 14,097
- Counted text lines across Swift, shell, Markdown, plist, yml and entitlements: 16,527
- Debug executable size: `.build/debug/ZoomIt` is about 3.0 MB
- Debug self-test executable size: `.build/debug/ZoomItMacSelfTest` is about 3.1 MB
- Development app bundle: `.build/DoraZoom Dev.app` is about 3.5 MB

### Build Evidence

Command:

```sh
swift build
```

Result:

- Exit code: 0
- Build mode: debug
- Result: PASS
- Notes: build emits upstream warnings in `PanoramaStitcher.swift` for Swift Sendable captures and in `VideoClipEditorController.swift` for deprecated AVFoundation APIs. These were not introduced by DoraZoom changes and are not treated as Phase 1 blockers.

Command:

```sh
.build/debug/ZoomItMacSelfTest
```

Result:

- Exit code: 0
- Output: `ZoomItMacSelfTest: PASS`
- Coverage type: official offline/self-test paths, including viewport behavior, annotation lifecycle, settings round-trip, menu ordering, icon checks, video clip editor logic and panorama stitching.

Command:

```sh
swift test
```

Result:

- Exit code: 1
- Output summary: `error: no tests found; create a target in the 'Tests' directory`
- Interpretation: upstream currently ships `ZoomItMacSelfTest` as an executable self-test rather than a SwiftPM `Tests` target. This is recorded as a baseline gap, not as a DoraZoom regression.

### Simulated Benchmark Evidence

Command:

```sh
.build/debug/ZoomItMacSelfTest --bench-stitch 1200 900 80 90 1
```

Result:

- Exit code: 0
- Frames: 80
- Frame size: `1200x900`
- Scroll step: 90
- Document height: 8010
- Stitched output: `1200x7920`
- Elapsed: 29,489.1 ms
- Average: 29,489.1 ms

Interpretation:

- This is an offline CPU benchmark using generated frames and does not access the real screen, microphone, camera, global keyboard or TCC.
- It is suitable as an initial deterministic Phase 1 benchmark sample.
- It does not prove real capture latency, real recording performance, real cursor feedback or player compatibility.

### Development App Bundle

Command:

```sh
ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' \
ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' \
ZOOMIT_APP_NAME='DoraZoom Dev.app' \
ZOOMIT_ARCHS='' \
Scripts/build-app.sh debug
```

Result:

- Exit code: 0
- App path: `.build/DoraZoom Dev.app`
- Bundle ID: `com.duola.dorazoom.dev`
- Display name: `DoraZoom (Dev)`
- Signing: ad-hoc
- Architecture: arm64
- `codesign -dv` identifier: `com.duola.dorazoom.dev`
- Team identifier: not set

Interpretation:

- Development identity is isolated from the future daily-use bundle ID `com.duola.dorazoom`.
- This app was built but not installed or launched during Phase 1.

### Phase 1 Limits

The following remain intentionally unproven until later phases:

- Real TCC prompts and system settings behavior.
- Real ScreenCaptureKit screen/window capture.
- Real global keyboard event tap and `Control+V` conversion.
- Real screenshot paste into target apps.
- Real MOV/MP4/GIF export compatibility.
- Real CPU, memory and latency under live use.
- Notarization, public download and final distribution.

## Phase 2 Contract Core

### Target Behavior

建立纯逻辑契约，让 DoraZoom 能表达以下能力而不触发真实 macOS 副作用：

- 录制、绘画、白板、摄像头画中画可并存。
- 光标、HUD、录制状态、菜单栏和调色板反馈从会话状态派生。
- feedback lease 按通道独立管理，迟到或重复结束不会清掉当前反馈。
- MOV/MP4 走电影输出策略，GIF 走独立动态图像输出策略。
- `W/K` 固定为白板/黑板，白色/黑色画笔保留但无默认快捷键。
- `Control+V` 只在截图剪贴板仍被武装且 listen/post 均授权时转换；重复粘贴不解除，剪贴板变化解除，非精确按键和合成事件放行。

### RED

- Test added: `Tests/ZoomItMacCoreTests/Phase2ContractTests.swift`
- Command: `swift test --filter Phase2ContractTests`
- Observed failure: compile failed because `AppSessionState`, `InteractionPresentationSnapshot`, `InteractionFeedback`, `RecordingOutputStrategy`, `DrawingShortcutPolicy` and `PasteCompatibilityService` did not exist.
- Failure is correct because: the test target compiled, but the Phase 2 contract surface was absent. The failure was missing target behavior, not a malformed test environment.

### GREEN

Minimal implementation:

- Added `Sources/ZoomItMacCore/Core/AppSessionState.swift`.
- Added `Sources/ZoomItMacCore/Core/InteractionFeedback.swift`.
- Added `Sources/ZoomItMacCore/Capture/RecordingOutputStrategy.swift`.
- Added `Sources/ZoomItMacCore/Hotkeys/DrawingShortcutPolicy.swift`.
- Added `Sources/ZoomItMacCore/App/PasteCompatibilityService.swift`.
- Added `ZoomItMacCoreTests` test target in `Package.swift`.
- Marked upstream `AnnotationTool` and `AnnotationColor` as `Sendable` in their defining file to satisfy Swift 6 strict concurrency.

Command:

```sh
swift test --filter Phase2ContractTests
```

Observed pass:

- Exit code: 0
- Executed: 9 tests
- Failures: 0

### REFACTOR

- Refactor done: no broad refactor.
- Change: only moved `Sendable` conformance into the existing annotation enum definitions after Swift rejected retroactive conformance from another file.
- Command after refactor:

```sh
swift test
.build/debug/ZoomItMacSelfTest
ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug
```

Observed result:

- `swift test`: PASS, 9 tests.
- `ZoomItMacSelfTest`: PASS.
- Development app build: PASS, `com.duola.dorazoom.dev`, ad-hoc signed, arm64.

### Phase 2 Limits

- These contracts are not yet wired into `ModeCoordinator`, real overlay windows, real cursor resources, ScreenCaptureKit, AVFoundation writers, `NSPasteboard`, or `CGEventTap`.
- The tests prove policy and state-machine behavior only. Real TCC prompts, real keyboard conversion, real screenshot paste and live cursor appearance remain future-phase evidence.

## Phase 3 Partial: Screenshot Copy To Paste Compatibility

### Target Behavior

After a DoraZoom screenshot successfully writes image data to the pasteboard, the pasteboard `changeCount` must be handed to the paste compatibility coordinator. The coordinator may then request input compatibility access only after the first successful screenshot, and it must arm `Control+V` only when listen and post access are both available.

### RED

- Test added: additional paste coordinator tests in `Tests/ZoomItMacCoreTests/Phase2ContractTests.swift`.
- Command: `swift test --filter Phase2ContractTests/testPasteCoordinator`
- Observed failure: compile failed because `InputCompatibilityPermissionRequester` and `PasteCompatibilityCoordinator` did not exist.
- Failure is correct because: the existing `PasteCompatibilityService` could convert events, but there was no higher-level screenshot-success boundary or first-screenshot permission request policy.

### GREEN

Minimal implementation:

- Added `InputCompatibilityPermissionRequester`.
- Added `PasteCompatibilityCoordinator`.
- Added `SystemInputCompatibilityPermissionRequester` using `CGPreflightListenEventAccess`, `CGRequestListenEventAccess`, `CGPreflightPostEventAccess` and `CGRequestPostEventAccess`.
- Added a minimal native explanatory alert before requesting listen/post event access.
- Allowed `PasteCompatibilityService` to refresh access and disarm when access becomes incomplete.
- Changed `ImageExporter.copyToPasteboard(_:)` to return `NSPasteboard.changeCount`.
- Wired `SnipController`, `ModeCoordinator`, `OverlayWindowController` and `ZoomCanvasView` so copied screenshots and copied viewports notify the paste compatibility coordinator.

Command:

```sh
swift test --filter Phase2ContractTests/testPasteCoordinator
```

Observed pass:

- Exit code: 0
- Executed: 2 tests
- Failures: 0

### Regression Commands

```sh
swift test
.build/debug/ZoomItMacSelfTest
ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug
```

Observed result:

- `swift test`: PASS, 11 tests.
- `ZoomItMacSelfTest`: PASS.
- Development app build: PASS, `com.duola.dorazoom.dev`, ad-hoc signed, arm64.

### Phase 3 Remaining

- `CGEventTap` production adapter now exists and is wired to App startup/permission completion, but it has not been exercised against the real system event stream during automated testing.
- `Control+V` conversion is covered by simulated event tests and compiled production code, but real target-app paste remains Phase 7 evidence.
- `Command+V` pass-through is covered by simulated event tests in unarmed, unauthorized and armed states.
- A minimal native explanatory alert exists before requesting input compatibility access, but it has not received final copy/design review.
- Simulated export-plan proof now shows screenshot-to-clipboard performs only a pasteboard image operation and no file operation.
- No real target-app paste, TCC or cursor visual acceptance has been claimed.

## Phase 3 Partial: Control+V Event Tap Boundary

### Target Behavior

When input compatibility access is complete and the most recent DoraZoom screenshot is still armed, exact `Control+V` should suppress the original event and post a synthetic `Command+V`. Unarmed events, synthetic events and non-exact key combinations must pass through unchanged. The system event tap must start only when listen and post access are both available.

### RED

- Test added: `Tests/ZoomItMacCoreTests/Phase3EventTapTests.swift`
- Command: `swift test --filter Phase3EventTapTests`
- Observed failure: compile failed because `PasteCompatibilityEventTapController`, `KeyboardEventPoster`, `KeyboardPostCommand`, `EventTapHandlingDecision`, `SystemPasteCompatibilityEventTap` and `PasteCompatibilityEventTapInstalling` did not exist.
- Failure is correct because: Phase 3 already had a paste compatibility state machine, but no event-tap boundary that could suppress original `Control+V` and post synthetic `Command+V`.

### GREEN

Minimal implementation:

- Added `PasteCompatibilityEventTapController` to translate coordinator decisions into event-tap decisions.
- Added `KeyboardEventPoster` and `SystemKeyboardEventPoster`.
- Added `SystemPasteCompatibilityEventTap` with permission-gated startup and stop lifecycle.
- Added `PasteTapBridge`, a tiny C target that owns `CGEventTap` installation and synthetic `Command+V` posting.
- Wired `AppDelegate` so the event tap starts at launch only if access is already complete, and starts after first-screenshot permission completion when access becomes complete.
- Added `PasteCompatibilityCoordinator.onAccessBecameComplete`, guarded so it fires only once.

Implementation note:

- A Swift-only `CGEvent.tapCreate` adapter repeatedly triggered a Swift 6.3.3 compiler crash in the `SendNonSendable` SIL pass. Moving the raw `CGEventTap` and synthetic key posting to the C bridge avoids that compiler bug while keeping the policy and tests in Swift.

Command:

```sh
swift test --filter Phase3EventTapTests
```

Observed pass:

- Exit code: 0
- Executed: 4 tests
- Failures: 0

### Regression Commands

```sh
swift test
.build/debug/ZoomItMacSelfTest
ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug
```

Observed result:

- `swift test`: PASS, 15 tests.
- `ZoomItMacSelfTest`: PASS.
- Development app build: PASS, `com.duola.dorazoom.dev`, ad-hoc signed, arm64.
- Development app bundle size: about 3.7 MB.

### Current Size Snapshot

- Working source files, excluding `.git` and `.build`: 66 files
- Working source payload, excluding `.git` and `.build`: 936 KB
- Swift source lines under `Sources`: 14,765

### Remaining Evidence

- Real TCC listen/post behavior has not been exercised.
- Real global `Control+V` conversion has not been exercised.
- Real paste into target apps has not been exercised.
- Real accessibility of the explanatory alert has not been reviewed.

## Phase 3 Partial: Snip Export Plan And Native Command+V

### Target Behavior

The snip export path must make file side effects explicit. `copyImage` must only write image data to the pasteboard; it must not write to a directory or show a save panel. `saveImage` may write a file or show a save panel according to settings. OCR must write recognized text to the clipboard only. `Command+V` must always pass through in unarmed, unauthorized and armed states.

### RED

- Test added: `Tests/ZoomItMacCoreTests/Phase3SnipExportPlanTests.swift`
- Command: `swift test --filter Phase3SnipExportPlanTests`
- Observed failure: compile failed because `SnipExportPlan` and `SnipExportOperation` did not exist.
- Failure is correct because: production code had direct export calls, but no testable export plan that could prove copy-to-clipboard does not create local files.

### GREEN

Minimal implementation:

- Added `SnipExportPlan` and `SnipExportOperation`.
- Rewired `SnipController` and zoom overlay region snip to execute the same export plan.
- Split overlay save-panel presentation so planned save-panel operations do not repeat pasteboard or file side effects.
- Added `Command+V` pass-through coverage to `Phase3EventTapTests`.

Command:

```sh
swift test --filter Phase3SnipExportPlanTests
```

Observed pass:

- Exit code: 0
- Executed: 3 tests
- Failures: 0

### Regression Commands

```sh
swift test
.build/debug/ZoomItMacSelfTest
ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug
```

Observed result:

- `swift test`: PASS, 19 tests.
- `ZoomItMacSelfTest`: PASS.
- Development app build: PASS, `com.duola.dorazoom.dev`, ad-hoc signed, arm64.
- Development app bundle size: about 3.7 MB.

### Current Size Snapshot

- Working source files, excluding `.git` and `.build`: 68 files
- Working source payload, excluding `.git` and `.build`: 948 KB
- Swift source lines under `Sources`: 14,809

### Remaining Evidence

- `Control+6` visible dimension HUD/feedback is covered in the following Phase 3 section.
- Full permission-state matrix is covered in the following Phase 3 section.
- Real TCC, real global keyboard conversion and real target-app paste remain Phase 7 evidence.

## Phase 3 Partial: Region Selection Feedback And Permission Matrix

### Target Behavior

`Control+6` region selection must show immediate, ZoomIt-like feedback while dragging: crosshair cursor plus a compact pixel-size HUD that stays inside the selection container. The paste compatibility permission flow must be covered by simulated states only: unknown, allowed, denied, listen-only partial, post-only partial and previously allowed after restart. Denied or partial access must not arm paste compatibility, intercept `Control+V` or install an active event tap.

### RED

- Test added: `Tests/ZoomItMacCoreTests/Phase3SelectionFeedbackTests.swift`
- Command: `swift test --filter Phase3SelectionFeedbackTests`
- Observed failure: compile failed before `RegionSelectionFeedback` existed.
- Later regression caught the right semantic detail: `CGRect.integral` expanded the pixel rectangle and displayed `247 × 114` for a `123.4 × 56.6` point selection at `2x`, while the intended HUD value is `247 × 113`.
- Failure is correct because: the product needs user-visible size feedback during selection, and the displayed pixel dimensions must not be inflated by integral-rect expansion.

Additional permission matrix test:

- Test added: `Tests/ZoomItMacCoreTests/Phase3PastePermissionMatrixTests.swift`
- Command: `swift test --filter Phase3PastePermissionMatrixTests`
- Expected simulated behavior:
  - Unknown then allowed: request once, arm after screenshot, start fake event tap once.
  - Denied: request once, do not arm, do not intercept, do not install fake event tap.
  - Listen-only partial: do not arm, do not intercept, do not install fake event tap.
  - Post-only partial: do not arm, do not intercept, do not install fake event tap.
  - Previously allowed after restart: start fake event tap at launch, arm after screenshot, do not request again.

### GREEN

Minimal implementation:

- Added `RegionSelectionFeedback` as a pure geometry/presentation helper.
- Wired region selection drawing in `SnipController` and zoom overlay region snip to draw the size HUD.
- Kept crosshair cursor leases in the production region selection paths.
- Changed HUD pixel-size calculation to round width and height independently instead of using `CGRect.integral`.
- Added a pure simulated permission matrix using fake permission requester, fake keyboard poster and fake event tap installer.

Commands:

```sh
swift test --filter Phase3SelectionFeedbackTests
swift test --filter Phase3PastePermissionMatrixTests
```

Observed pass:

- `Phase3SelectionFeedbackTests`: PASS, 3 tests.
- `Phase3PastePermissionMatrixTests`: PASS, 5 tests.

### Regression Commands

```sh
swift test
.build/debug/ZoomItMacSelfTest
ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug
```

Observed result:

- `swift test`: PASS, 27 tests.
- `ZoomItMacSelfTest`: PASS.
- Development app build: PASS, `com.duola.dorazoom.dev`, ad-hoc signed, arm64.
- Development app bundle size: about 3.8 MB.

### Current Size Snapshot

- Working source files, excluding `.git` and `.build`: 69 files.
- Working source payload, excluding `.git` and `.build`: 825,412 bytes, about 806 KB.
- Swift source lines under `Sources`: 14,879.
- Development app bundle: `.build/DoraZoom Dev.app`, about 3.8 MB.

### Simulator / Simulated-Layer Boundary

- All automated tests in this phase use in-process simulation: fake permission requester, fake event tap installer, fake keyboard poster, deterministic keyboard events, pure geometry and export-plan assertions.
- No automated test requests real TCC permissions.
- No automated test installs a real global event tap.
- No automated test sends real synthetic keyboard events to another app.
- No automated test accesses the real screen, microphone, camera or target applications.

### Remaining Evidence

- `Control+6` cancellation/window cleanup is covered in the following Phase 3 completion section.
- The native explanatory alert and settings-state copy are covered in the following Phase 3 completion section.
- Real TCC, real global `Control+V`, real target-app paste and real cursor appearance remain Phase 7 evidence.

## Phase 3 Completion: Region Lifecycle, Export Execution And Permission Presentation

### Target Behavior

Phase 3 must prove the screenshot-to-paste slice without touching real macOS side effects:

- `Control+6` region selection has a simulated lifecycle with selection-window, crosshair cursor and size-HUD resources.
- Cancelling a region selection clears all virtual resources and returns no selected rectangle.
- Completing a valid region selection returns the selected rectangle and clears resources.
- Copy-image export execution writes only to the simulated memory pasteboard and does not touch simulated directory files, save panels or OCR.
- Paste compatibility settings can show either ready or waiting-for-authorization, including which keyboard-event access is missing.
- The access explanation names `⌃V` compatibility and preserves `⌘V` as the fallback.

### RED

Region selection lifecycle:

- **Test added**: `Tests/ZoomItMacCoreTests/Phase3RegionSelectionLifecycleTests.swift`
- **Command**: `swift test --filter Phase3RegionSelectionLifecycleTests`
- **Observed failure**: compile failed because `RegionSelectionLifecycle` and `RegionSelectionResource` did not exist.
- **Failure is correct because**: production selection state existed only inside AppKit event handlers, so there was no simulated lifecycle proving cancellation clears selection resources.

Export execution:

- **Test added**: `Phase3SnipExportPlanTests.testCopyImageExecutionTouchesOnlyMemoryPasteboard`
- **Command**: `swift test --filter Phase3SnipExportPlanTests/testCopyImageExecutionTouchesOnlyMemoryPasteboard`
- **Observed failure**: compile failed because `SnipExportExecutor` did not exist.
- **Failure is correct because**: earlier tests proved the export plan shape, but not that executing the plan avoids file, save-panel and OCR side effects.

Permission presentation:

- **Test added**: `Tests/ZoomItMacCoreTests/Phase3PastePermissionPresentationTests.swift`
- **Command**: `swift test --filter Phase3PastePermissionPresentationTests`
- **Observed failure**: compile failed because `PasteCompatibilityCoordinator.settingStatus`, `PasteCompatibilitySettingStatus` and `InputCompatibilityAccessExplanation` did not exist.
- **Failure is correct because**: permission request policy existed, but settings-state presentation and shared explanation copy were not explicit or testable.

### GREEN

Minimal implementation:

- Added `RegionSelectionLifecycle` and `RegionSelectionResource`.
- Rewired `SnipSelectionView` so AppKit mouse/key handlers use `RegionSelectionLifecycle` for drag state, cancel and finish.
- Added `SnipExportExecutor` and rewired both production region-snip paths (`SnipController` and zoom overlay region snip) through the same executor.
- Added `KeyboardEventAccessRequirement`, `PasteCompatibilitySettingStatus` and `InputCompatibilityAccessExplanation`.
- Reused `InputCompatibilityAccessExplanation.controlVPaste` in the native permission alert, so settings/copy tests and production alert share one source.

Commands:

```sh
swift test --filter Phase3RegionSelectionLifecycleTests
swift test --filter Phase3SnipExportPlanTests/testCopyImageExecutionTouchesOnlyMemoryPasteboard
swift test --filter Phase3PastePermissionPresentationTests
```

Observed pass:

- `Phase3RegionSelectionLifecycleTests`: PASS, 2 tests.
- `Phase3SnipExportPlanTests/testCopyImageExecutionTouchesOnlyMemoryPasteboard`: PASS, 1 test.
- `Phase3PastePermissionPresentationTests`: PASS, 3 tests.

### REFACTOR

- Refactor done: yes.
- Change: replaced duplicate region-snip export switch statements with `SnipExportExecutor` in both production region-snip paths; replaced `SnipSelectionView`'s private drag state with `RegionSelectionLifecycle`.
- Command after refactor:

```sh
swift test
.build/debug/ZoomItMacSelfTest
ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug
```

Observed result:

- `swift test`: PASS, 33 tests.
- `ZoomItMacSelfTest`: PASS.
- Development app build: PASS, `com.duola.dorazoom.dev`, ad-hoc signed, arm64.
- Development app bundle size: about 3.8 MB.

### Current Size Snapshot

- Working source files, excluding `.git` and `.build`: 71 files.
- Working source payload, excluding `.git` and `.build`: 838,189 bytes, about 819 KB.
- Swift source lines under `Sources`: 14,994.
- Development app bundle: `.build/DoraZoom Dev.app`, about 3.8 MB.

### Phase 3 Judgment

- Phase 3 simulated proof is complete.
- Production adapters compile and are wired, including paste event tap startup and region-snip export paths.
- Real TCC, real global `Control+V`, real target-app paste and real cursor appearance are intentionally not claimed here; they remain Phase 7 evidence.

## Phase 4 Partial: Static Zoom Pointer And HUD Feedback

### Target Behavior

When `Control+1` activates static zoom, DoraZoom hides the system cursor for the overlay. The first rendered frame must therefore draw an explicit ZoomIt-like zoom pointer and a compact zoom status HUD instead of leaving the user with no visible mouse state. The HUD must show the current zoom factor, avoid fractional formatting noise, and stay inside the overlay. Static zoom lifecycle resources must clear on close.

Draw-only mode must still show the pen dot before the first stroke, and shape-drag previews must hide the pen dot while the shape preview owns the cursor area.

### RED

Pointer:

- **Test added**: `Tests/ZoomItMacCoreTests/Phase4OverlayPointerPresentationTests.swift`
- **Command**: `swift test --filter Phase4OverlayPointerPresentationTests`
- **Observed failure**: compile failed because `OverlayPointerPresentation` and `OverlayPointerVisual` did not exist.
- **Failure is correct because**: current overlay cursor behavior was embedded in drawing code; static zoom had no testable replacement pointer even though the system cursor is hidden.

HUD:

- **Test added**: `Tests/ZoomItMacCoreTests/Phase4OverlayHUDPresentationTests.swift`
- **Command**: `swift test --filter Phase4OverlayHUDPresentationTests`
- **Observed failure**: compile failed because `OverlayHUDPresentation` did not exist.
- **Failure is correct because**: there was no testable static-zoom status HUD, and the overlay had only region-selection HUD drawing.

Lifecycle:

- **Test added**: `Tests/ZoomItMacCoreTests/Phase4StaticZoomLifecycleTests.swift`
- **Command**: `swift test --filter Phase4StaticZoomLifecycleTests`
- **Observed failure**: compile failed because `OverlayInteractionLifecycle` and `OverlayInteractionResource` did not exist.
- **Failure is correct because**: there was no simulated resource view proving static zoom starts with overlay/window/cursor/HUD resources and clears them on close.

### GREEN

Minimal implementation:

- Added `OverlayPointerPresentation` and `OverlayPointerVisual`.
- Added `OverlayHUDPresentation` and `OverlayHUD`.
- Added `OverlayInteractionLifecycle` and `OverlayInteractionResource`.
- Rewired `ZoomCanvasView.draw(_:)` so pointer visuals are selected by the presentation policy.
- Added a lightweight white/black zoom crosshair indicator for static zoom.
- Added a compact `Zoom N×` HUD in static zoom, driven by `viewportController.zoomFactor`.
- Kept draw-only mode on the existing pen-dot indicator.
- Synchronized `pointerViewPoint` when the overlay first moves into a window, so the first static-zoom frame can draw the indicator at the current mouse position.

Commands:

```sh
swift test --filter Phase4OverlayPointerPresentationTests
swift test --filter Phase4OverlayHUDPresentationTests
swift test --filter Phase4StaticZoomLifecycleTests
```

Observed pass:

- `Phase4OverlayPointerPresentationTests`: PASS, 3 tests.
- `Phase4OverlayHUDPresentationTests`: PASS, 4 tests.
- `Phase4StaticZoomLifecycleTests`: PASS, 1 test.

### REFACTOR

- Refactor done: yes.
- Change: removed the older `isDrawingShapeStroke` helper after `OverlayPointerPresentation` became the single policy for hiding shape-stroke pen dots. Kept HUD and pointer presentation as separate small policies rather than folding them into a larger compatibility layer.
- Command after refactor:

```sh
swift test
.build/debug/ZoomItMacSelfTest
ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug
```

Observed result:

- `swift test`: PASS, 41 tests.
- `ZoomItMacSelfTest`: PASS.
- Development app build: PASS, `com.duola.dorazoom.dev`, ad-hoc signed, arm64.
- Development app bundle size: about 3.9 MB.

### Current Size Snapshot

- Working source files, excluding `.git` and `.build`: 77 files.
- Working source payload, excluding `.git` and `.build`: 855,852 bytes, about 836 KB.
- Swift source lines under `Sources`: 15,182.
- Development app bundle: `.build/DoraZoom Dev.app`, about 3.9 MB.

### Remaining Evidence

- `Control+1` static zoom pointer/HUD simulated proof is complete and the Phase 4 `Control+1` todo is checked in `GOAL.md`.
- `Control+2` drawing feedback has a current tool/color/width HUD in the next section; full tool rendering, whiteboard/blackboard and OCR/recording/panorama pointer resources remain Phase 4 work.
- Real cursor appearance is still Phase 7 human acceptance; this section proves simulated policy and compiled production drawing only.

## Phase 4 Partial: Drawing HUD Feedback

### Target Behavior

When `Control+2` activates draw-only mode, DoraZoom should immediately show visible drawing state beyond the pen dot: current tool, current color and current line width. This is a lightweight status HUD, not a full tool palette. It must stay inside the overlay and hide when the overlay is not in drawing mode.

### RED

- **Test added**: `Tests/ZoomItMacCoreTests/Phase4DrawingHUDPresentationTests.swift`
- **Command**: `swift test --filter Phase4DrawingHUDPresentationTests`
- **Observed failure**: compile failed because `DrawingHUDPresentation` did not exist.
- **Failure is correct because**: draw-only mode could show a pen pointer, but there was no testable status surface for tool/color/width feedback.

### GREEN

Minimal implementation:

- Added `DrawingHUDPresentation`.
- Reused `OverlayHUD` as the small HUD value type.
- Added tool display names for HUD copy in a private extension.
- Rewired `ZoomCanvasView.draw(_:)` to draw the drawing HUD when `isDrawingMode` is true.

Command:

```sh
swift test --filter Phase4DrawingHUDPresentationTests
```

Observed pass:

- `Phase4DrawingHUDPresentationTests`: PASS, 4 tests.

### REFACTOR

- Refactor done: yes.
- Change: extracted shared HUD drawing into `drawHUD(_:)` so Zoom HUD and Drawing HUD share the same visual treatment without duplicating text/background drawing.
- Command after refactor:

```sh
swift test
.build/debug/ZoomItMacSelfTest
ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug
```

Observed result:

- `swift test`: PASS, 45 tests.
- `ZoomItMacSelfTest`: PASS.
- Development app build: PASS, `com.duola.dorazoom.dev`, ad-hoc signed, arm64.
- Development app bundle size: about 3.9 MB.

### Current Size Snapshot

- Working source files, excluding `.git` and `.build`: 79 files.
- Working source payload, excluding `.git` and `.build`: 861,018 bytes, about 841 KB.
- Swift source lines under `Sources`: 15,237.
- Development app bundle: `.build/DoraZoom Dev.app`, about 3.9 MB.

### Remaining Evidence

- `Control+2` full tool feedback is completed in the following render-plan section and the Phase 4 `Control+2` todo is checked in `GOAL.md`.
- Real cursor/HUD appearance remains Phase 7 human acceptance; this section proves simulated policy and compiled production drawing only.

## Phase 4 Completion: Draw-Only Tool Feedback And Render Plan

### Target Behavior

`Control+2` draw-only mode must be more than a visible pen dot. A fixed-input simulated rendering plan must prove that the drawing system covers pen, line, rectangle, ellipse, arrow, highlighter and text, and that color, width, undo and clear are reflected in the same production rendering path used by the overlay.

### RED

- **Test added**: `Tests/ZoomItMacCoreTests/Phase4AnnotationRenderPlanTests.swift`
- **Command**: `swift test --filter Phase4AnnotationRenderPlanTests`
- **Observed failure**: compile failed because `AnnotationRenderPlan` and `AnnotationController.renderPlanSnapshot` did not exist.
- **Failure is correct because**: the overlay could render into a `CGContext`, but there was no deterministic simulated render-plan surface proving each tool and style branch without pixel screenshots.

### GREEN

Minimal implementation:

- Added `AnnotationRenderPlan`, `AnnotationRenderKind` and `AnnotationRenderOperation`.
- Added `AnnotationController.renderPlanSnapshot`.
- Rewired `AnnotationController.render(in:bounds:)` so production rendering consumes the same render operations tested by the simulated plan.
- Preserved highlight layering: highlight operations are planned before solid ink so highlighter strokes stay underneath normal annotations.

Command:

```sh
swift test --filter Phase4AnnotationRenderPlanTests
```

Observed pass:

- `Phase4AnnotationRenderPlanTests`: PASS, 2 tests.

### REFACTOR

- Refactor done: yes.
- Change: moved annotation-to-render-kind decisions out of the CGContext renderer and into `AnnotationRenderPlan`; the renderer now executes render operations instead of re-deciding every branch itself.
- Command after refactor:

```sh
swift test
.build/debug/ZoomItMacSelfTest
ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug
```

Observed result:

- `swift test`: PASS, 47 tests.
- `ZoomItMacSelfTest`: PASS.
- Development app build: PASS, `com.duola.dorazoom.dev`, ad-hoc signed, arm64.
- Development app bundle size: about 3.9 MB.

### Current Size Snapshot

- Working source files, excluding `.git` and `.build`: 81 files.
- Working source payload, excluding `.git` and `.build`: 869,038 bytes, about 849 KB.
- Swift source lines under `Sources`: 15,326.
- Development app bundle: `.build/DoraZoom Dev.app`, about 3.9 MB.

### Phase 4 Status

- `Control+1` static zoom feedback: simulated proof complete.
- `Control+2` draw-only feedback and render plan: simulated proof complete.
- Live zoom/live draw interaction routing: simulated proof complete.
- Whiteboard/blackboard plus white/black pen shortcut judgment: simulated proof complete.
- OCR/recording/panorama pointer resource catalog: simulated proof complete.
- High-frequency simulated interaction benchmark: simulated proof complete.
- Remaining Phase 4 work: none in automation; real cursor/HUD appearance remains Phase 7 human acceptance.

## Hai TDD: Live Zoom Input Routing And Draw Hotkey Policy

### Target Behavior

In live zoom, DoraZoom must behave like ZoomIt: when the user is not drawing or selecting a region, mouse input passes through to the underlying app while the live zoom follows the global cursor; when drawing or region selection is active, the overlay captures input. Pressing either draw entry hotkey while already in live zoom toggles live drawing inside the current live zoom session instead of exiting or starting a separate static zoom/draw-only mode. All automated proof uses simulated policy inputs and compile-time wiring only; real cursor appearance, real target-app click-through and real global input remain Phase 7 acceptance.

### RED

- **Test added**: `Tests/ZoomItMacCoreTests/Phase4LiveZoomCommandPolicyTests.swift`
- **Behavior asserted**: live zoom maps `.activateDrawWithoutZoom` and `.activateStaticZoom` to `.toggleDrawingWithinLiveZoom`; non-live-zoom and non-draw commands continue normal handling.
- **Command**: `swift test --filter Phase4LiveZoomCommandPolicyTests`
- **Observed failure**: compile failed because `LiveZoomCommandPolicy`, `LiveZoomCommandEffect.toggleDrawingWithinLiveZoom` and `LiveZoomCommandEffect.normalCommandHandling` did not exist.
- **Failure is correct because**: the new simulated command-policy surface was missing; the test target and existing code compiled far enough to show the absent behavior boundary rather than a malformed environment.

### GREEN

- **Minimal implementation**: added `Sources/ZoomItMacCore/Core/LiveZoomCommandPolicy.swift` with `LiveZoomCommandPolicy.effect(mode:command:)`; wired `ModeCoordinator.handle(_:)` to consume the policy before normal command dispatch.
- **Command**: `swift test --filter Phase4LiveZoomCommandPolicyTests`
- **Observed pass**: PASS, 3 tests.

### REFACTOR

- **Refactor done**: yes.
- **Change**: removed duplicate inline `mode == .liveZoom` checks from the `.activateStaticZoom` and `.activateDrawWithoutZoom` switch cases; production command handling now shares the same policy tested by the simulated command tests.
- **Command after refactor**:

```sh
swift test --filter Phase4LiveZoomInteractionPolicyTests
swift test
.build/debug/ZoomItMacSelfTest
ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug
git diff --check
```

- **Observed result**:
  - `swift test --filter Phase4LiveZoomInteractionPolicyTests`: PASS, 4 tests.
  - `swift test`: PASS, 54 tests.
  - `ZoomItMacSelfTest`: PASS.
  - Development app build: PASS, `.build/DoraZoom Dev.app`, bundle id `com.duola.dorazoom.dev`, ad-hoc signed, arm64.
  - `git diff --check`: PASS.

### Next Behavior

Completed below.

## Hai TDD: Whiteboard, Blackboard And White/Black Ink Shortcut Judgment

### Target Behavior

DoraZoom follows Windows ZoomIt for `W/K`: plain `W` switches to whiteboard and plain `K` switches to blackboard. White and black ink remain available colors, but they do not occupy default keyboard shortcuts, including `Shift+W/K` or `Control+W/K`. Whiteboard/blackboard is part of the annotation session state, so switching backgrounds preserves existing marks and is drawn into the same overlay image used by viewport screenshots and recording composition. Automated proof stays in the simulated policy/state layer; real cursor contrast and human visual smoothness remain Phase 7 acceptance.

### RED

- **Test added**: `Tests/ZoomItMacCoreTests/Phase4CanvasBackgroundTests.swift`
- **Behavior asserted**: `DrawingShortcutCommandPolicy` maps `W/K` to `.setCanvas`, white/black ink has no default shortcut, `AnnotationController` owns canvas background without clearing marks, and `CanvasBackground` declares export composition.
- **Command**: `swift test --filter Phase4CanvasBackgroundTests`
- **Observed failure**: compile failed because `DrawingShortcutCommandPolicy`, `AppCommand.setCanvas`, `AnnotationController.canvasBackground`, `AnnotationController.setCanvasBackground(_:)`, `CanvasBackground.renderFill` and `CanvasBackground.isCompositedIntoExports` did not exist.
- **Failure is correct because**: the existing Phase 2 policy contract existed, but production command routing and annotation-owned canvas state were still missing. The failure identified absent target behavior, not a malformed test setup.

### GREEN

- **Minimal implementation**: added `.setCanvas(CanvasBackground)` to `AppCommand`; added `DrawingShortcutCommandPolicy`; extended `DrawingShortcutPolicy` so existing drawing tool shortcuts still route through the shared policy; added `AnnotationController.canvasBackground` and `setCanvasBackground(_:)`; added `CanvasBackground.renderFill` and `isCompositedIntoExports`; changed `ZoomCanvasView.draw(_:)` to render whiteboard/blackboard from the annotation controller instead of a private view-only blank-screen state; wired `ModeCoordinator` to apply canvas changes.
- **Command**: `swift test --filter Phase4CanvasBackgroundTests`
- **Observed pass**: PASS, 3 tests.

### REFACTOR

- **Refactor done**: yes.
- **Change**: removed the old `ZoomCanvasView.WhiteBlackKeyAction` branch and the private `blankScreen` overlay state; updated the offline self-test and README wording so they no longer claim `Ctrl+W/K` or plain `W/K` select white/black ink.
- **Command after refactor**:

```sh
swift test
.build/debug/ZoomItMacSelfTest
ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug
git diff --check
```

- **Observed result**:
  - `swift test`: PASS, 57 tests.
  - `ZoomItMacSelfTest`: PASS.
  - Development app build: PASS, `.build/DoraZoom Dev.app`, bundle id `com.duola.dorazoom.dev`, ad-hoc signed, arm64.
  - `git diff --check`: PASS.

### Current Size Snapshot

- Working source files, excluding `.git` and `.build`: 87 files.
- Working source payload, excluding `.git` and `.build`: 882,388 bytes, about 862 KB.
- Swift source lines under `Sources`: 15,413.
- Development app bundle: `.build/DoraZoom Dev.app`, about 3.9 MB.

### Next Behavior

Phase 4 next simulated slice: OCR, recording-selection and panorama-selection pointer resources.

## Hai TDD: OCR, Recording And Panorama Pointer Resources

### Target Behavior

Selection modes must not all look like the same generic crosshair in DoraZoom's state model. Screenshot, OCR, recording-region and panorama-region selection each need a distinct pointer resource identity with shape, tint, hotspot and 1x/2x scale variants. The production selection paths should carry that purpose-specific resource metadata, while automated tests remain simulated and do not replace the host Mac cursor or claim final visual quality.

### RED

- **Test added**: `Tests/ZoomItMacCoreTests/Phase4PointerResourceTests.swift`
- **Behavior asserted**: `PointerResourceCatalog` differentiates screenshot/OCR/recording/panorama pointers; `InteractionPresentationSnapshot` maps OCR, recording and panorama states to specific pointer purposes; `SnipAction` exposes the pointer purpose used by its selection overlay.
- **Command**: `swift test --filter Phase4PointerResourceTests`
- **Observed failure**: compile failed because `PointerResourceCatalog`, `PointerResourceShape`, `PointerScaleVariant`, `PointerPurpose.panoramaSelection` and `SnipAction.pointerPurpose` did not exist.
- **Failure is correct because**: current selection code only had a generic crosshair lease and panorama did not have a distinct pointer purpose in the simulated presentation snapshot.

### GREEN

- **Minimal implementation**: added `PointerResourceCatalog` with purpose-specific shape, tint, hotspot and 1x/2x variants; added `.panoramaSelection` to `PointerPurpose`; mapped `.panorama` state to `.crosshair(purpose: .panoramaSelection)`; added `SnipAction.pointerPurpose`; changed `CrosshairCursorLease` to hold purpose-specific `PointerResource`; passed `.screenshot`, `.ocr`, `.recordingSelection` and `.panoramaSelection` from snip, zoomed-region snip, recording-region and panorama-region selection entry points.
- **Command**: `swift test --filter Phase4PointerResourceTests`
- **Observed pass**: PASS, 3 tests.

### REFACTOR

- **Refactor done**: yes.
- **Change**: moved pointer-resource choice out of ad-hoc selector code into a single catalog; production still uses the safe system crosshair for now, but the selection path now carries the correct resource metadata for future real cursor assets.
- **Command after refactor**:

```sh
swift test
.build/debug/ZoomItMacSelfTest
ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug
git diff --check
```

- **Observed result**:
  - `swift test`: PASS, 60 tests.
  - `ZoomItMacSelfTest`: PASS.
  - Development app build: PASS, `.build/DoraZoom Dev.app`, bundle id `com.duola.dorazoom.dev`, ad-hoc signed, arm64.
  - `git diff --check`: PASS.

### Current Size Snapshot

- Working source files, excluding `.git` and `.build`: 89 files.
- Working source payload, excluding `.git` and `.build`: 890,748 bytes, about 870 KB.
- Swift source lines under `Sources`: 15,493.
- Development app bundle: `.build/DoraZoom Dev.app`, about 3.9 MB.

### Next Behavior

Phase 4 next simulated slice: high-frequency interaction benchmark.

## Hai TDD: High-Frequency Interaction Simulated Benchmark

### Target Behavior

Phase 4 needs a repeatable simulated benchmark for high-frequency interaction that does not depend on wall-clock timing, the host display, global input, pasteboard, ScreenCaptureKit, microphone or camera. The benchmark must use a fixed event sample and return deterministic evidence: event count, state commits, render-plan operation count, estimated allocation units, simulated duration and explicit platform-boundary flags.

### RED

- **Test added**: `Tests/ZoomItMacCoreTests/Phase4HighFrequencyInteractionBenchmarkTests.swift`
- **Behavior asserted**: running `.phase4Default` twice produces the same report, processes 190 events, commits state once per event, stays under fixed allocation and simulated-duration thresholds, and marks every real platform boundary as untouched.
- **Command**: `swift test --filter Phase4HighFrequencyInteractionBenchmarkTests`
- **Observed failure**: compile failed because `HighFrequencyInteractionBenchmark`, `.phase4Default` and `AutomationPlatformBoundary.simulatedOnly` did not exist.
- **Failure is correct because**: there was no Phase 4 deterministic interaction benchmark surface; existing tests covered behavior slices but not a fixed high-frequency event sample.

### GREEN

- **Minimal implementation**: added `HighFrequencyInteractionBenchmark`, `HighFrequencyInteractionBenchmarkSample`, `HighFrequencyInteractionEvent`, `HighFrequencyInteractionBenchmarkReport` and `AutomationPlatformBoundary`; the benchmark replays 190 simulated pointer/stroke/zoom/style events, uses `AnnotationRenderPlan` for operation counts, computes allocation units deterministically, and reports all real platform boundaries as untouched.
- **Command**: `swift test --filter Phase4HighFrequencyInteractionBenchmarkTests`
- **Observed pass**: PASS, 2 tests.

### REFACTOR

- **Refactor done**: no broad refactor.
- **Change**: no refactor needed beyond keeping the benchmark in Core with no AppKit, ScreenCaptureKit, pasteboard, global keyboard, microphone or camera dependency.
- **Command after refactor**:

```sh
swift test
.build/debug/ZoomItMacSelfTest
ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug
git diff --check
```

- **Observed result**:
  - `swift test`: PASS, 62 tests.
  - `ZoomItMacSelfTest`: PASS.
  - Development app build: PASS, `.build/DoraZoom Dev.app`, bundle id `com.duola.dorazoom.dev`, ad-hoc signed, arm64.
  - `git diff --check`: PASS.

### Simulated Benchmark Snapshot

- Event sample: 190 fixed events.
- State commits: 190.
- Render-plan operations accumulated: 530.
- Allocation units: 720.
- Simulated duration: 13,790 microseconds.
- Platform boundary: simulated only.
- Real ScreenCapture/global keyboard/pasteboard/microphone/camera: untouched.

### Current Size Snapshot

- Working source files, excluding `.git` and `.build`: 91 files.
- Working source payload, excluding `.git` and `.build`: 899,995 bytes, about 879 KB.
- Swift source lines under `Sources`: 15,629.
- Development app bundle: `.build/DoraZoom Dev.app`, about 4.0 MB.

### Phase 4 Exit

Phase 4 automation is complete. Real cursor/HUD appearance, true click-through feel and human smoothness remain Phase 7 acceptance items.

### Next Behavior

Phase 5 next simulated slice: recording target/output/profile strategy.

## Hai TDD: MOV Default Movie Profile And MP4 Retention

### Target Behavior

DoraZoom's default recording movie format is MOV with H.264 video and AAC audio, while MP4 remains available on the same movie pipeline and GIF stays outside the movie writer path. The same movie profile must drive AVAssetWriter file type, temporary filename extension, save-panel content type, editor export file type and audio settings. Automated proof verifies profile and production wiring; QuickTime, Windows, CapCut and DaVinci playback/import compatibility remain Phase 7 acceptance.

### RED

- **Test added**: `Tests/ZoomItMacCoreTests/Phase5RecordingMovieProfileTests.swift`
- **Behavior asserted**: `RecordingFileFormat.default == .mov`; default movie profile exposes `.mov` AV file type, QuickTime save content type, H.264/AAC, 48 kHz, 128 kbps and stereo; MP4 remains available as `.mp4`/MPEG-4 movie; GIF remains `.animatedImage`.
- **Command**: `swift test --filter Phase5RecordingMovieProfileTests`
- **Observed failure**: compile failed because `RecordingFileFormat.default`, `RecordingOutputStrategy.defaultMovieProfile`, `MovieRecordingProfile.avFileType`, `saveContentType`, `audioSampleRate`, `audioBitRate` and `audioChannelCount` did not exist.
- **Failure is correct because**: Phase 2 had a coarse MOV/MP4/GIF strategy, but the production writer/editor could still hardcode `.mp4`; the missing profile fields were exactly the uncentralized behavior.

### GREEN

- **Minimal implementation**: added default MOV format and AV/UTType/audio settings to `MovieRecordingProfile`; changed `RecordingEngine` and fallback writer to use `profile.avFileType`; changed ScreenCaptureKit audio configuration to use profile sample rate and channel count; changed recording temp URL, save panel and suggested filename to use the default profile; changed `VideoClipEditorController` export output URL and `AVAssetExportSession.outputFileType` to use the same profile.
- **Command**: `swift test --filter Phase5RecordingMovieProfileTests`
- **Observed pass**: PASS, 3 tests.

### REFACTOR

- **Refactor done**: yes.
- **Change**: removed remaining user-facing "MP4 default" wording from recording help and README, while keeping MP4/GIF support statements; retained existing editor behavior and avoided adding new quality presets.
- **Command after refactor**:

```sh
swift test
.build/debug/ZoomItMacSelfTest
ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug
git diff --check
```

- **Observed result**:
  - `swift test`: PASS, 65 tests.
  - `ZoomItMacSelfTest`: PASS.
  - Development app build: PASS, `.build/DoraZoom Dev.app`, bundle id `com.duola.dorazoom.dev`, ad-hoc signed, arm64.
  - `git diff --check`: PASS.

### Current Size Snapshot

- Working source files, excluding `.git` and `.build`: 92 files.
- Working source payload, excluding `.git` and `.build`: 906,834 bytes, about 886 KB.
- Swift source lines under `Sources`: 15,669.
- Development app bundle: `.build/DoraZoom Dev.app`, about 4.0 MB.

### Next Behavior

Phase 5 next simulated slice: full-screen, region and window recording target request planning.

## Hai TDD: Recording Target Request Planning

### Target Behavior

Phase 5 needs a deterministic request-planning layer for recording targets before real ScreenCaptureKit interaction: full-screen, region and window targets must produce distinct capture request plans with filter identity, source rectangle, pixel dimensions and cursor policy. Automated proof uses fixture displays/windows only and does not query the real WindowServer or capture the real screen.

### RED

- **Test added**: `Tests/ZoomItMacCoreTests/Phase5RecordingTargetRequestPlanTests.swift`
- **Behavior asserted**: full-screen target creates a display capture request with full source rect and scaled pixel size; region target creates a display request with the fixture region and scaled size; window target creates a window request with the exact fixture window ID; missing windows fail instead of falling back to full-screen.
- **Command**: `swift test --filter Phase5RecordingTargetRequestPlanTests`
- **Observed failure**: compile failed because `RecordingCaptureRequestPlanner`, `RecordingCaptureRequestPlan`, `RecordingCaptureRequestFilter`, `RecordingWindowDescriptor` and `RecordingCaptureRequestPlanError` did not exist.
- **Failure is correct because**: existing recording code hand-built full/region ScreenCaptureKit configuration and had no pure target-to-request planning surface for window recording.

### GREEN

- **Minimal implementation**: added `RecordingCaptureRequestPlan`, `RecordingCaptureRequestFilter`, `RecordingWindowDescriptor`, `RecordingCaptureRequestPlanError` and `RecordingCaptureRequestPlanner`; planner covers `.fullScreen`, `.region` and `.window` targets with deterministic pixel sizing and missing-target errors.
- **Command**: `swift test --filter Phase5RecordingTargetRequestPlanTests`
- **Observed pass**: PASS, 4 tests.

### REFACTOR

- **Refactor done**: yes.
- **Change**: changed production full-screen/region recording start to create a `RecordingTarget` and consume `RecordingCaptureRequestPlan`; `startStreaming` now uses the plan for display/window filter selection, source rect, pixel size and cursor policy. Real mouse-under-window selection UI is not claimed here; the window filter branch is compiled and the request plan is simulated.
- **Command after refactor**:

```sh
swift test
.build/debug/ZoomItMacSelfTest
ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug
git diff --check
```

- **Observed result**:
  - `swift test`: PASS, 69 tests.
  - `ZoomItMacSelfTest`: PASS.
  - Development app build: PASS, `.build/DoraZoom Dev.app`, bundle id `com.duola.dorazoom.dev`, ad-hoc signed, arm64.
  - `git diff --check`: PASS.

### Current Size Snapshot

- Working source files, excluding `.git` and `.build`: 95 files.
- Working source payload, excluding `.git` and `.build`: 927,555 bytes, about 906 KB / 0.885 MB.
- Swift source lines under `Sources`: 15,880.
- Development app bundle: `.build/DoraZoom Dev.app`, about 4.04 MB.

## Hai TDD: Phase 5 GIF output writer planning

### Target Behavior

DoraZoom must retain GIF as an independent animated-image output path, separate from the MOV/MP4 movie writer. The simulated writer boundary must preserve ordered frames and per-frame durations, expose a stable `.gif` save type, and prove that the movie writer is not called for GIF. This is a simulated plan/writer fixture only; real GIF file playback or editor compatibility remains Phase 7 evidence.

### RED

- **Test added**: `Tests/ZoomItMacCoreTests/Phase5GifOutputWriterTests.swift`
- **Behavior asserted**: GIF strategy returns a profile with `gif` extension, `.gif` content type, infinite loop and 8-bit depth; routing `.gif` writes one `RecordingGifOutputPlan` with exact frame order/durations and leaves movie writer call count at zero.
- **Command**: `swift test --filter Phase5GifOutputWriterTests`
- **Observed failure**: compile failed because `RecordingGifOutputPlan`, `RecordingGifWriting`, `RecordingMovieWriting`, `RecordingGifFramePlan` and `RecordingOutputWriterRouter` did not exist; existing `.animatedImage` carried only a `String`, so `fileExtension`, `saveContentType`, `loopCount` and `colorDepthBits` were missing.
- **Failure is correct because**: the failure is exactly the absent behavior boundary: GIF had a coarse strategy marker but no testable ImageIO-style output profile, frame-duration plan or movie-writer bypass contract.

### GREEN

- **Minimal implementation**: added `RecordingGifProfile`, `RecordingGifFramePlan`, `RecordingGifOutputPlan`, `RecordingGifWriting`, `RecordingMovieWriting` and `RecordingOutputWriterRouter`; changed `.animatedImage` to carry `RecordingGifProfile.zoomItDefault`; updated existing Phase 2/5 expectations to the typed profile.
- **Command**: `swift test --filter Phase5GifOutputWriterTests`
- **Observed pass**: `Phase5GifOutputWriterTests` passed 2 tests with 0 failures. The command only used in-process fake writers and did not touch TCC, the real screen, microphone, camera, global keyboard, real pasteboard or real filesystem output.

### REFACTOR

- **Refactor done**: no
- **Change**: no further refactor needed for this slice; the new boundary is already a small profile/plan/router surface under `RecordingOutputStrategy`.
- **Command after refactor**:
  - `swift test --filter Phase2ContractTests/testRecordingOutputStrategySeparatesMovieAndGifOutputs`
  - `swift test --filter Phase5RecordingMovieProfileTests`
- **Observed result**: Phase 2 recording strategy contract passed 1 test; Phase 5 movie profile tests passed 3 tests. Existing deprecation warnings in `VideoClipEditorController` remain unrelated.

### Next Behavior

Phase 5 next simulated slice: system audio, microphone and webcam picture-in-picture timeline/permission planning.

## Verification After Phase 5 GIF Slice

- `swift test`: PASS, 71 XCTest cases. All automated coverage remains in simulated/pure boundaries.
- `.build/debug/ZoomItMacSelfTest`: PASS.
- `ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug`: PASS; app bundle generated at `.build/DoraZoom Dev.app`, ad-hoc signed, bundle id `com.duola.dorazoom.dev`.
- `git diff --check`: PASS.
- Not claimed: real TCC prompts, real global keyboard conversion, real screen/audio/microphone/camera capture, real GIF playback/import compatibility, or real target-app behavior.

## Hai TDD: Phase 5 recording media input planning

### Target Behavior

DoraZoom recording must keep system audio, microphone and webcam picture-in-picture disabled by default. When the user enables them, a simulated media-input planner must decide which inputs are active from feature settings and permission state, register only the needed microphone/camera permission requests, and normalize video, system-audio, microphone and webcam samples onto one recording timeline. Webcam picture-in-picture placement must be deterministic and stay inside the recorded area. This proof stays entirely in the simulated planning layer; it does not request real TCC or touch real audio/video devices.

### RED

- **Test added**: `Tests/ZoomItMacCoreTests/Phase5RecordingMediaInputPlanTests.swift`
- **Behavior asserted**: defaults include no system audio, microphone or webcam; enabled inputs request only undecided feature permissions; granted microphone/camera samples join the same normalized timeline; webcam bottom-right medium 16:9 placement and dragged snap stay inside a 1920×1080 recording area.
- **Command**: `swift test --filter Phase5RecordingMediaInputPlanTests`
- **Observed failure**: compile failed because `RecordingMediaInputPlanner`, `RecordingMediaSample`, `RecordingMediaInputPermissions`, `RecordingMediaTimelineEntry` and `RecordingWebcamPictureInPicturePlanner` did not exist.
- **Failure is correct because**: production recording had real ScreenCaptureKit/AVFoundation branches, but there was no pure simulated boundary proving permission decisions, media timeline alignment or picture-in-picture geometry without hitting macOS capture APIs.

### GREEN

- **Minimal implementation**: added `RecordingMediaInputPlan.swift` with media source/sample/timeline types, permission request decisions, `RecordingMediaInputPlanner`, and `RecordingWebcamPictureInPicturePlanner`; the planner always reports `.simulatedOnly` for automation boundary.
- **Command**: `swift test --filter Phase5RecordingMediaInputPlanTests`
- **Observed pass**: `Phase5RecordingMediaInputPlanTests` passed 4 tests with 0 failures. The command used deterministic samples and did not touch TCC, real screen capture, microphone, camera, global keyboard, pasteboard or filesystem output.

### REFACTOR

- **Refactor done**: yes
- **Change**: changed `WebcamOverlayController.overlayFrame(...)` so production webcam initial placement consumes `RecordingWebcamPictureInPicturePlanner.initialFrame(...)`, removing the duplicate geometry formula. Existing free drag behavior remains unchanged; the simulated snap planner is ready for a later mouse-up snap decision without making dragging feel jumpy.
- **Command after refactor**:
  - `swift test --filter Phase5RecordingMediaInputPlanTests`
  - `.build/debug/ZoomItMacSelfTest`
  - `swift test`
- **Observed result**: media-input tests passed 4 tests; `ZoomItMacSelfTest` passed; full `swift test` passed 75 XCTest cases. Existing deprecation warnings in unrelated AVFoundation editor code remain unrelated.

### Next Behavior

Phase 5 next simulated slice: recording while drawing/whiteboard is active, including composited-frame fixture and feedback-channel isolation.

## Verification After Phase 5 Media Input Slice

- `swift test`: PASS, 75 XCTest cases. All automated coverage remains in simulated/pure boundaries.
- `.build/debug/ZoomItMacSelfTest`: PASS.
- `ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug`: PASS; app bundle generated at `.build/DoraZoom Dev.app`, ad-hoc signed, bundle id `com.duola.dorazoom.dev`.
- `git diff --check`: PASS.
- Current size snapshot:
  - Working source files, excluding `.git` and `.build`: 97 files.
  - Working source payload, excluding `.git` and `.build`: 941,668 bytes, about 920 KB / 0.898 MB.
  - Swift source lines under `Sources`: 16,038.
  - Development app bundle: `.build/DoraZoom Dev.app`, about 4.04 MB.
- Not claimed: real TCC prompts, real ScreenCaptureKit system audio, real microphone input, real camera capture, real webcam visual smoothness, real global keyboard behavior, or real media playback/import compatibility.

## Hai TDD: Phase 5 recording composition and feedback isolation

### Target Behavior

Recording must keep drawing, whiteboard/blackboard and webcam composition separate from transient UI feedback. A simulated frame-composition plan must prove that recording frames include captured video, canvas background, annotation operations and webcam picture-in-picture when applicable, while excluding feedback HUD and recording-status capsules from the encoded content. Ending a pointer lease must not clear recording status feedback or the durable recording state. This is a simulated composition contract only; real pixel composition and live recording appearance remain Phase 7 evidence.

### RED

- **Test added**: `Tests/ZoomItMacCoreTests/Phase5RecordingCompositionIsolationTests.swift`
- **Behavior asserted**: `recording+drawing+whiteboard+webcam` produces layers `[capturedVideo, canvasBackground(.white), annotations(1), webcam(...)]`; `recording+drawing+blackboard` produces `[capturedVideo, canvasBackground(.black), annotations(1)]`; composition excludes feedback HUD and recording status capsule; ending a cursor lease does not clear `recordingStatus` feedback or `RecordingState`.
- **Command**: `swift test --filter Phase5RecordingCompositionIsolationTests`
- **Observed failure**: compile failed because `RecordingFrameCompositionPlan`, `RecordingFrameCompositionLayer` and `RecordingWebcamCompositionSource` did not exist.
- **Failure is correct because**: existing state and annotation render plans could express drawing/whiteboard while recording, but there was no simulated recording-frame composition boundary proving which layers enter the recording and which feedback layers stay out.

### GREEN

- **Minimal implementation**: added `RecordingFrameCompositionPlan.swift` with `RecordingWebcamCompositionSource`, `RecordingFrameCompositionLayer` and `RecordingFrameCompositionPlan.make(...)`; the plan starts from captured video, conditionally adds composited canvas background, annotation operation count and webcam layer, and always marks transient feedback HUD/status capsule as excluded.
- **Command**: `swift test --filter Phase5RecordingCompositionIsolationTests`
- **Observed pass**: `Phase5RecordingCompositionIsolationTests` passed 3 tests with 0 failures. The command used only state objects, annotation render operations and in-memory feedback leases; it did not touch TCC, real screen capture, microphone, camera, global keyboard, pasteboard or filesystem output.

### REFACTOR

- **Refactor done**: no
- **Change**: no refactor needed in this slice; the new composition contract remains a small pure plan. Production overlay capture already composites overlay/webcam in `RecordingController`, but real pixel verification is intentionally not pulled into automated tests.
- **Command after refactor**:
  - `swift test`
  - `.build/debug/ZoomItMacSelfTest`
- **Observed result**: full `swift test` passed 78 XCTest cases; `ZoomItMacSelfTest` passed.

### Next Behavior

Phase 5 next simulated slice: restore/verify the post-recording editor decision graph for preview, trim, append, transitions, mute/volume and export.

## Verification After Phase 5 Composition Slice

- `swift test`: PASS, 78 XCTest cases. All automated coverage remains in simulated/pure boundaries.
- `.build/debug/ZoomItMacSelfTest`: PASS.
- `ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug`: PASS; app bundle generated at `.build/DoraZoom Dev.app`, ad-hoc signed, bundle id `com.duola.dorazoom.dev`.
- `git diff --check`: PASS.
- Current size snapshot:
  - Working source files, excluding `.git` and `.build`: 99 files.
  - Working source payload, excluding `.git` and `.build`: 951,656 bytes, about 929 KB / 0.908 MB.
  - Swift source lines under `Sources`: 16,084.
  - Development app bundle: `.build/DoraZoom Dev.app`, about 4.09 MB.
- Not claimed: real TCC prompts, real ScreenCaptureKit capture, real microphone/camera capture, real encoded-pixel composition, real recording HUD exclusion, or real media playback/import compatibility.

## Hai TDD: Phase 5 recording editor decision graph

### Target Behavior

The post-recording editor must be represented by a deterministic, non-destructive decision graph before any real AVFoundation export: preview, trim, append, fade transitions, mute/volume and MOV export must produce a new-file plan that never mutates source recordings. Invalid trim input must be rejected without corrupting the original timeline. Automated proof stays in pure value types and does not open the editor window, read video assets or write media files.

### RED

- **Test added**: `Tests/ZoomItMacCoreTests/Phase5RecordingEditorDecisionPlanTests.swift`
- **Behavior asserted**: an original 12s recording trimmed to 2–10s, appended with a 4s clip, set to fade-white, volume 0.35 and muted produces preview range 0–12, two timeline segments, transition at 8s, muted audio with previous audible volume 0.35, MOV new-file export, no source file actions and `.simulatedOnly`; invalid trim 6–3 is rejected and the original 0–8s segment/volume export remains.
- **Command**: `swift test --filter Phase5RecordingEditorDecisionPlanTests`
- **Observed failure**: compile failed because `RecordingEditorClip`, `RecordingEditorDecisionGraph`, editor operations, timeline segment, transition, audio/export decisions and rejected-operation types did not exist.
- **Failure is correct because**: the real `VideoClipEditorController` already owns AppKit/AVFoundation UI/export behavior, but there was no pure simulated decision graph proving the editor's non-destructive semantics and export decisions without reading or writing media.

### GREEN

- **Minimal implementation**: added `RecordingEditorDecisionGraph.swift` with clip/time-range/operation/transition/audio/export/rejection plan types and `RecordingEditorDecisionGraph.make(...)`; the graph applies valid trim, appends clips with transition boundaries, clamps volume, preserves previous audible volume when muted, writes to a new file extension from `MovieRecordingProfile`, and keeps `mutatesSourceFiles == false`.
- **Command**: `swift test --filter Phase5RecordingEditorDecisionPlanTests`
- **Observed pass**: after correcting the preview assertion to the edited timeline coordinate system, `Phase5RecordingEditorDecisionPlanTests` passed 2 tests with 0 failures. The command used pure values only and did not touch TCC, real media assets, AVFoundation export, filesystem output, microphone, camera, screen capture, global keyboard or pasteboard.

### REFACTOR

- **Refactor done**: no
- **Change**: no production refactor in this slice. Pulling `VideoClipEditorController.Transition` into the pure graph would couple the lightweight model to AppKit/main-actor editor code; keeping the graph pure is smaller and safer. The existing controller remains the real UI/export path.
- **Command after refactor**:
  - `swift test`
  - `.build/debug/ZoomItMacSelfTest`
  - `ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug`
  - `git diff --check`
- **Observed result**: full `swift test` passed 80 XCTest cases; `ZoomItMacSelfTest` passed; development app build passed; `git diff --check` passed.

### Next Behavior

Phase 5 next simulated slice: media compatibility acceptance matrix for QuickTime, target Windows playback, CapCut and DaVinci Resolve with Phase 7 result fields.

## Verification After Phase 5 Editor Slice

- `swift test`: PASS, 80 XCTest cases. All automated coverage remains in simulated/pure boundaries.
- `.build/debug/ZoomItMacSelfTest`: PASS.
- `ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug`: PASS; app bundle generated at `.build/DoraZoom Dev.app`, ad-hoc signed, bundle id `com.duola.dorazoom.dev`.
- `git diff --check`: PASS.
- Current size snapshot:
  - Working source files, excluding `.git` and `.build`: 101 files.
  - Working source payload, excluding `.git` and `.build`: 960,822 bytes, about 938 KB / 0.916 MB.
  - Swift source lines under `Sources`: 16,250.
  - Development app bundle: `.build/DoraZoom Dev.app`, about 4.11 MB.
- Not claimed: real AVFoundation export, real editor window behavior, real TCC prompts, real ScreenCaptureKit capture, real microphone/camera capture, or real media playback/import compatibility.

## Hai TDD: Phase 5 media compatibility acceptance matrix

### Target Behavior

DoraZoom must have a media compatibility acceptance matrix before Phase 7 real playback/import checks. The matrix must list the required target environments, record installed target versions at acceptance time, define the required MOV/MP4/GIF sample set, list the exact checks, and keep every result as `pendingPhase7` so automated tests never claim real QuickTime, Windows, CapCut or DaVinci compatibility.

### RED

- **Test added**: `Tests/ZoomItMacCoreTests/Phase5MediaCompatibilityMatrixTests.swift`
- **Behavior asserted**: matrix targets are QuickTime Player, Windows native playback, CapCut and DaVinci Resolve; every target records installed version at acceptance; samples are default MOV, MOV with audio/webcam/annotations, retained MP4 and retained GIF; checks cover open/import, video playback, expected audio, A/V sync, duration and failure reason; all result statuses are `.pendingPhase7`; GIF rows do not claim playback/import compatibility.
- **Command**: `swift test --filter Phase5MediaCompatibilityMatrixTests`
- **Observed failure**: compile failed because `RecordingMediaCompatibilityMatrix`, target/sample/check/result/status and version-policy types did not exist.
- **Failure is correct because**: Phase 5 had output configuration and simulated writer/editor evidence, but no explicit matrix preventing real media compatibility from being marked as passed before Phase 7 sample playback/import.

### GREEN

- **Minimal implementation**: added `RecordingMediaCompatibilityMatrix.swift` with target, version policy, sample, check, status and result value types; `phase7Default` generates four targets, four required samples, six checks and all target×sample results with `.pendingPhase7` plus a no-claim note.
- **Command**: `swift test --filter Phase5MediaCompatibilityMatrixTests`
- **Observed pass**: `Phase5MediaCompatibilityMatrixTests` passed 2 tests with 0 failures. The command used pure values only and did not open media players, import files, create samples, touch TCC, capture devices, screen capture, global keyboard, pasteboard or filesystem output.

### REFACTOR

- **Refactor done**: no
- **Change**: no refactor needed. The matrix is intentionally a small pure acceptance artifact, separate from runtime recording/export code.
- **Command after refactor**:
  - `swift test`
  - `.build/debug/ZoomItMacSelfTest`
  - `ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug`
  - `git diff --check`
- **Observed result**: full `swift test` passed 82 XCTest cases; `ZoomItMacSelfTest` passed; development app build passed; `git diff --check` passed.

### Next Behavior

Phase 6 next simulated slice: complete full ZoomIt feature coverage map against PRD §5.1 / Windows ZoomIt 12.11 and identify remaining implementation/test gaps.

## Verification After Phase 5 Media Matrix Slice

- `swift test`: PASS, 82 XCTest cases. All automated coverage remains in simulated/pure boundaries.
- `.build/debug/ZoomItMacSelfTest`: PASS.
- `ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug`: PASS; app bundle generated at `.build/DoraZoom Dev.app`, ad-hoc signed, bundle id `com.duola.dorazoom.dev`.
- `git diff --check`: PASS.
- Current size snapshot:
  - Working source files, excluding `.git` and `.build`: 103 files.
  - Working source payload, excluding `.git` and `.build`: 971,044 bytes, about 948 KB / 0.926 MB.
  - Swift source lines under `Sources`: 16,350.
  - Development app bundle: `.build/DoraZoom Dev.app`, about 4.20 MB.
- Phase 5 automated scope is complete: recording target planning, MOV/MP4/GIF output strategy, media inputs, recording composition isolation, editor decision graph and media compatibility matrix all have simulated tests.
- Not claimed: real QuickTime playback, real Windows playback, real CapCut import, real DaVinci Resolve import, real TCC prompts, real ScreenCaptureKit capture, real microphone/camera capture or real media file compatibility.

## Hai TDD: Phase 6 feature coverage map

### Target Behavior

DoraZoom must have a complete, simulation-only feature coverage map before closing Phase 6. The map must list every PRD §5.1 required capability, keep DoraZoom Mac adaptations such as `Control+V` paste compatibility and cursor feedback visible, attach implementation references and simulated-test references to every row, and explicitly identify remaining Phase 6 gaps. It must not claim real Mac/TCC/capture/input/media acceptance from automated tests.

### RED

- **Test added**: `Tests/ZoomItMacCoreTests/Phase6FeatureCoverageMapTests.swift`
- **Behavior asserted**: `ZoomItFeatureCoverageMap.phase6Default` must be `.simulatedOnly`; its PRD-required capability list must exactly match PRD §5.1; every required row must have implementation refs, simulated-test refs and a non-unknown status; real-system-sensitive capabilities must link to Phase 7 and must not claim real acceptance; known Phase 6 gaps must be explicit.
- **Command**: `swift test --filter Phase6FeatureCoverageMapTests`
- **Observed failure**: compile failed because `ZoomItFeatureCoverageMap`, `ZoomItFeatureCapability`, coverage status and Phase 7 reference types did not exist.
- **Failure is correct because**: the project had feature-specific simulated tests from earlier phases, but no single coverage ledger tying PRD §5.1 to implementation evidence, simulated tests and Phase 7-only proof boundaries.

### GREEN

- **Minimal implementation**: added `Sources/ZoomItMacCore/Core/ZoomItFeatureCoverageMap.swift` with pure value types for capabilities, coverage entries, statuses, Phase 7 references and the default Phase 6 map. The map covers all 30 PRD §5.1 capabilities plus DoraZoom Mac adaptation rows for paste compatibility and cursor feedback. It marks the current unresolved Phase 6 items as `phase6ImplementationGap` instead of pretending completion.
- **Command**: `swift test --filter Phase6FeatureCoverageMapTests`
- **Observed pass**: `Phase6FeatureCoverageMapTests` passed 3 tests with 0 failures. The command used pure in-process values only and did not touch TCC, real screen capture, microphone, camera, global keyboard, pasteboard, media players, target apps or filesystem output.

### REFACTOR

- **Refactor done**: yes
- **Change**: split the large coverage-entry expression into an explicitly typed array plus a small loop assigning PRD-required flags, avoiding Swift type-checker slowdown while keeping the model unchanged.
- **Command after refactor**:
  - `swift test --filter Phase6FeatureCoverageMapTests`
  - `swift test`
  - `.build/debug/ZoomItMacSelfTest`
  - `ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug`
  - `git diff --check`
- **Observed result**: Phase 6 coverage tests passed 3 tests; full `swift test` passed 85 XCTest cases; `ZoomItMacSelfTest` passed; development app build passed; `git diff --check` passed.

### Next Behavior

Phase 6 next simulated slice: close the first concrete coverage gap, preferably region snip-to-file/current viewport copy-save/OCR using fixed image fixtures, a simulated save panel and an in-memory pasteboard.

## Verification After Phase 6 Coverage Map Slice

- `swift test`: PASS, 85 XCTest cases. All automated coverage remains in simulated/pure boundaries.
- `.build/debug/ZoomItMacSelfTest`: PASS.
- `ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug`: PASS; app bundle generated at `.build/DoraZoom Dev.app`, ad-hoc signed, bundle id `com.duola.dorazoom.dev`.
- `git diff --check`: PASS.
- Current size snapshot:
  - Working source files, excluding `.git` and `.build`: 105 files.
  - Working source payload, excluding `.git` and `.build`: 1,001,802 bytes, about 978 KB / 0.955 MB.
  - Swift source lines under `Sources`: 16,700.
  - Development app bundle: `.build/DoraZoom Dev.app`, about 4.3 MB.
- Phase 6 coverage map status: PRD §5.1 has a complete ledger, but Phase 6 is not complete. The map explicitly identifies remaining simulated implementation/test gaps for current viewport copy/save, snip-to-file, OCR, break timer, DemoType, panorama, settings/hotkey customization, single instance, menu bar status, permission checks and launch at login.
- Not claimed: real TCC prompts, real global keyboard/input monitoring, real `Control+V` interception, real ScreenCaptureKit capture, real microphone/camera capture, real paste into target apps, real player/editor import compatibility or real cursor visual acceptance.

## Hai TDD: Phase 6 image export simulation

### Target Behavior

DoraZoom must close the Phase 6 simulated proof gap for region snip-to-file, current viewport copy/save and OCR-to-clipboard. The proof must use fixed image fixtures, an in-memory pasteboard, simulated save-panel decisions and simulated OCR results, covering successful directory save, save-panel accept/cancel/failure, OCR text output and OCR empty-result feedback. It must also update the feature coverage map so these rows are no longer listed as Phase 6 gaps while still requiring Phase 7 real Mac acceptance.

### RED

- **Test added**: `Tests/ZoomItMacCoreTests/Phase6ImageExportSimulationTests.swift`
- **Behavior asserted**: current viewport save-to-directory optionally copies the image to memory pasteboard and arms paste compatibility with the image pasteboard change count; region snip save-panel accept/cancel/failure are represented without touching the filesystem; OCR writes recognized text only, does not write an image or file, and beeps without changing the clipboard when no text is recognized.
- **Command**: `swift test --filter Phase6ImageExportSimulationTests`
- **Observed failure**: compile failed because `ImageExportSimulation`, fixed image fixture, simulated save panel, simulated OCR, simulated clock, result, file, feedback and outcome types did not exist.
- **Failure is correct because**: earlier Phase 3 tests covered coarse export operations, but there was no deterministic simulator proving save-panel cancellation/failure, direct-path output, OCR empty results, and paste-compatibility arming for viewport image export.

### GREEN

- **Minimal implementation**: added `Sources/ZoomItMacCore/Capture/ImageExportSimulation.swift` with pure value types and a `run(...)` simulator. The simulator consumes existing `SnipExportPlan.operations(...)`, records memory pasteboard image/text writes, synthetic file writes, save-panel events, OCR no-text feedback and paste-compatibility change counts, and always reports `.simulatedOnly`.
- **Command**: `swift test --filter Phase6ImageExportSimulationTests`
- **Observed pass**: `Phase6ImageExportSimulationTests` passed 3 tests with 0 failures. The command used pure values only and did not touch TCC, real screen capture, real `NSSavePanel`, real `NSPasteboard`, real Vision OCR, real filesystem output, microphone, camera, global keyboard or target apps.

### REFACTOR

- **Refactor done**: yes
- **Change**: updated `ZoomItFeatureCoverageMap.phase6Default` and `Phase6FeatureCoverageMapTests` so `currentViewportCopyAndSave`, `regionSnipToFile` and `regionOCRToClipboard` are marked `simulatedCompletePhase7Pending` with `Phase6ImageExportSimulationTests` evidence, instead of remaining as Phase 6 implementation gaps.
- **Command after refactor**:
  - `swift test --filter Phase6FeatureCoverageMapTests`
  - `swift test --filter Phase6ImageExportSimulationTests`
  - `swift test`
  - `.build/debug/ZoomItMacSelfTest`
  - `ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug`
  - `git diff --check`
- **Observed result**: coverage map tests passed 4 tests; image export simulation tests passed 3 tests; full `swift test` passed 89 XCTest cases; `ZoomItMacSelfTest` passed; development app build passed; `git diff --check` passed.

### Next Behavior

Phase 6 next simulated slice: close break timer and DemoType with virtual clock/event replay and simulated keyboard/pasteboard output.

## Verification After Phase 6 Image Export Slice

- `swift test`: PASS, 89 XCTest cases. All automated coverage remains in simulated/pure boundaries.
- `.build/debug/ZoomItMacSelfTest`: PASS.
- `ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug`: PASS; app bundle generated at `.build/DoraZoom Dev.app`, ad-hoc signed, bundle id `com.duola.dorazoom.dev`.
- `git diff --check`: PASS.
- Current size snapshot:
  - Working source files, excluding `.git` and `.build`: 107 files.
  - Working source payload, excluding `.git` and `.build`: 1,018,452 bytes, about 995 KB / 0.971 MB.
  - Swift source lines under `Sources`: 16,868.
  - Development app bundle: `.build/DoraZoom Dev.app`, about 4.4 MB.
- Phase 6 coverage map status: current viewport copy/save, region snip-to-file and region OCR-to-clipboard are now simulated-complete and Phase 7 pending. Remaining Phase 6 gaps are break timer, DemoType, panorama, settings/hotkey customization, single instance, menu bar status, permission checks and launch at login.
- Not claimed: real Vision OCR quality, real save panel behavior, real filesystem writes, real screenshot pixels, real paste into target apps, real TCC prompts, real ScreenCaptureKit capture, real global keyboard/input monitoring or real `Control+V` interception.

## Hai TDD: Phase 6 break timer and DemoType simulation

### Target Behavior

DoraZoom must close the Phase 6 simulated proof gap for the break timer and DemoType. Break timer proof must use a virtual clock to cover start, countdown, expiry, sound intent, user exit, idle-sleep lifecycle and recording-feedback isolation. DemoType proof must use event replay to cover start, previous segment, replay, paste, Enter, exit and HUD state while proving no real keyboard, real pasteboard or target app is touched.

### RED

- **Test added**: `Tests/ZoomItMacCoreTests/Phase6TimerDemoTypeSimulationTests.swift`
- **Behavior asserted**: `BreakTimerSimulation` must report `.simulatedOnly`, produce visible timer snapshots for start/advance/expiry/expired time, emit a single zero-crossing sound intent, record lifecycle start/idle-sleep/expired/close/end events, and mark feedback excluded from recording. `DemoTypeReplaySimulation` must replay a script segment, rewind to the previous segment, replay it, then replay paste/Command+V/Enter/text output and exit without touching real keyboard, pasteboard or target app. The coverage map must mark break timer and DemoType as `simulatedCompletePhase7Pending`.
- **Command**: `swift test --filter Phase6TimerDemoTypeSimulationTests`
- **Observed failure**: compile failed because `BreakTimerSimulation`, break timer event/result/sound/lifecycle/recording-visibility types, `DemoTypeReplaySimulation`, replay command/output/feedback/key/status types and coverage-map updates did not exist.
- **Failure is correct because**: real AppKit timer and DemoType event injection existed, and official self-test covered lower-level helpers, but there was no pure simulator proving virtual-clock and event-replay behavior without using real windows, timers, sounds, keyboard events, pasteboard or target apps.

### GREEN

- **Minimal implementation**: added `Sources/ZoomItMacCore/Core/Phase6InteractionReplaySimulation.swift`. The break timer simulator consumes `AppSettings` plus virtual events and emits snapshots, sound intents, lifecycle events and recording-visibility policy. The DemoType simulator parses the ZoomIt control tokens needed by Phase 6 (`[end]`, `[paste]`, `[enter]`, arrows and pauses), keeps segment offsets, supports previous-segment replay, and returns output intents only.
- **Command**: `swift test --filter Phase6TimerDemoTypeSimulationTests`
- **Observed pass**: after trimming display padding for test-facing timer text and clamping EOF to the last real DemoType segment, `Phase6TimerDemoTypeSimulationTests` passed 3 tests with 0 failures. The command used pure values only and did not touch TCC, AppKit windows, real timers, real sounds, real keyboard events, real pasteboard, target apps, screen capture, microphone or camera.

### REFACTOR

- **Refactor done**: yes
- **Change**: updated `ZoomItFeatureCoverageMap.phase6Default` and `Phase6FeatureCoverageMapTests` so `breakTimer` and `demoType` are marked `simulatedCompletePhase7Pending` with `Phase6TimerDemoTypeSimulationTests` evidence, instead of remaining as Phase 6 implementation gaps.
- **Command after refactor**:
  - `swift test --filter Phase6TimerDemoTypeSimulationTests`
  - `swift test --filter Phase6FeatureCoverageMapTests`
  - `swift test`
  - `.build/debug/ZoomItMacSelfTest`
  - `ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug`
  - `git diff --check`
- **Observed result**: timer/DemoType simulation tests passed 3 tests; coverage map tests passed 4 tests; full `swift test` passed 92 XCTest cases; `ZoomItMacSelfTest` passed; development app build passed; `git diff --check` passed.

### Next Behavior

Phase 6 next simulated slice: close panorama clipboard/file output with fixed frame sequences, progress/cancellation and stale-callback cleanup.

## Verification After Phase 6 Timer/DemoType Slice

- `swift test`: PASS, 92 XCTest cases. All automated coverage remains in simulated/pure boundaries.
- `.build/debug/ZoomItMacSelfTest`: PASS.
- `ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug`: PASS; app bundle generated at `.build/DoraZoom Dev.app`, ad-hoc signed, bundle id `com.duola.dorazoom.dev`.
- `git diff --check`: PASS.
- Current size snapshot:
  - Working source files, excluding `.git` and `.build`: 109 files.
  - Working source payload, excluding `.git` and `.build`: 1,039,012 bytes, about 1,015 KB / 0.991 MB.
  - Swift source lines under `Sources`: 17,198.
  - Development app bundle: `.build/DoraZoom Dev.app`, about 4.6 MB.
- Phase 6 coverage map status: current viewport copy/save, region snip-to-file, region OCR-to-clipboard, break timer and DemoType are now simulated-complete and Phase 7 pending. Remaining Phase 6 gaps are panorama, settings/hotkey customization, single instance, menu bar status, permission checks and launch at login.
- Not claimed: real break timer window behavior, real timer scheduling, real sound playback, real idle-sleep assertion behavior, real DemoType keyboard injection, real pasteboard writes, target-app input behavior, real TCC prompts, real global keyboard/input monitoring, screen capture, microphone or camera.

## Hai TDD: Phase 6 panorama simulation

### Target Behavior

DoraZoom must close the Phase 6 simulated proof gap for panorama clipboard/file output. The proof must use fixed frame sequences and a pure control-flow simulator to cover capture progress, stitching progress, clipboard output, file output, cancellation, stale callbacks after cancellation and virtual window cleanup. Existing `PanoramaStitcher` self-tests remain the algorithm proof; this slice proves orchestration without touching real screen capture, pasteboard or filesystem output.

### RED

- **Test added**: `Tests/ZoomItMacCoreTests/Phase6PanoramaSimulationTests.swift`
- **Behavior asserted**: `PanoramaSimulation` must report `.simulatedOnly`, accept fixed frames by id, emit capture and stitching progress, output either a simulated pasteboard copy with change count or a simulated file write, return ZoomIt-style completion messages, ignore append/finish callbacks after cancellation, release virtual windows and update the coverage map so panorama is no longer a Phase 6 gap.
- **Command**: `swift test --filter Phase6PanoramaSimulationTests`
- **Observed failure**: compile failed because `PanoramaSimulationFrame`, `PanoramaSimulation`, panorama output/event/clock/progress/output-action/outcome/ignored-callback/result types and coverage-map updates did not exist.
- **Failure is correct because**: real panorama controller and stitching algorithm existed, and self-test covers stitching heavily, but there was no pure simulator proving the workflow branches required by Phase 6 without using real capture, real pasteboard, real file output or real progress windows.

### GREEN

- **Minimal implementation**: added `Sources/ZoomItMacCore/Capture/PanoramaSimulation.swift` with fixed-frame input, output destination, event stream, progress, output action, outcome and stale-callback value types. The simulator records capture counts, deterministic stitching percentages, synthetic output actions, cancellation and ignored callbacks, and always reports that it does not touch real screen capture, pasteboard or filesystem.
- **Command**: `swift test --filter Phase6PanoramaSimulationTests`
- **Observed pass**: `Phase6PanoramaSimulationTests` passed 3 tests with 0 failures. The command used pure values only and did not touch TCC, ScreenCaptureKit, AppKit windows, real pasteboard, real filesystem output, real image data, global keyboard, microphone or camera.

### REFACTOR

- **Refactor done**: yes
- **Change**: updated `ZoomItFeatureCoverageMap.phase6Default` and `Phase6FeatureCoverageMapTests` so `panoramaClipboardOrFile` is marked `simulatedCompletePhase7Pending` with `Phase6PanoramaSimulationTests` and existing self-test evidence instead of remaining as a Phase 6 implementation gap.
- **Command after refactor**:
  - `swift test --filter Phase6PanoramaSimulationTests`
  - `swift test --filter Phase6FeatureCoverageMapTests`
  - `swift test`
  - `.build/debug/ZoomItMacSelfTest`
  - `ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug`
  - `git diff --check`
- **Observed result**: panorama simulation tests passed 3 tests; coverage map tests passed 5 tests; full `swift test` passed 96 XCTest cases; `ZoomItMacSelfTest` passed; development app build passed; `git diff --check` passed.

### Next Behavior

Phase 6 next simulated slice: close settings, hotkey customization and permission management with in-memory settings, simulated hotkey conflict checks and permission-page state mapping.

## Verification After Phase 6 Panorama Slice

- `swift test`: PASS, 96 XCTest cases. All automated coverage remains in simulated/pure boundaries.
- `.build/debug/ZoomItMacSelfTest`: PASS.
- `ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug`: PASS; app bundle generated at `.build/DoraZoom Dev.app`, ad-hoc signed, bundle id `com.duola.dorazoom.dev`.
- `git diff --check`: PASS.
- Current size snapshot:
  - Working source files, excluding `.git` and `.build`: 111 files.
  - Working source payload, excluding `.git` and `.build`: 1,053,237 bytes, about 1,029 KB / 1.005 MB.
  - Swift source lines under `Sources`: 17,346.
  - Development app bundle: `.build/DoraZoom Dev.app`, about 4.6 MB.
- Phase 6 coverage map status: current viewport copy/save, region snip-to-file, region OCR-to-clipboard, break timer, DemoType and panorama are now simulated-complete and Phase 7 pending. Remaining Phase 6 gaps are settings/hotkey customization, single instance, menu bar status, permission checks and launch at login.
- Not claimed: real panorama capture, real scroll interaction, real stitched image quality, real progress windows, real pasteboard writes, real save panel/file output, real TCC prompts, real screen capture, global keyboard, microphone or camera.

## Hai TDD: Phase 6 settings, hotkeys and permissions simulation

### Target Behavior

DoraZoom must close the Phase 6 simulated proof gap for settings, hotkey customization and permission management. The proof must stay entirely in the simulation boundary: settings snapshots and persistence use in-memory values, shortcut validation uses virtual key/modifier values, and the permission page maps injected states without requesting TCC, opening System Settings, installing event taps or touching real keyboard input.

### RED

- **Test added**: `Tests/ZoomItMacCoreTests/Phase6SettingsPermissionsSimulationTests.swift`
- **Behavior asserted**: settings are grouped into Zoom/Draw/Text/Snip/Record/Webcam/Panorama/Launch categories and survive simulated restart; default ZoomIt-derived shortcuts include Shift-derived file/region/previous-segment variants; duplicate hotkeys reject save before persistence; screen recording, input listen/post, microphone and camera states map to permission-page rows/actions; coverage map marks settings/hotkey customization and permission checks as simulated-complete but Phase 7 pending.
- **Command**: `swift test --filter Phase6SettingsPermissionsSimulationTests`
- **Observed failure**: compile failed because `SettingsManagementSimulation`, `SettingsManagementMemoryStore`, settings snapshot, hotkey plan/conflict, permission input/page/row and related value types did not exist.
- **Failure is correct because**: the project had production settings, hotkey and permission services, but no pure simulator proving the management-page behavior without invoking AppKit settings windows, real UserDefaults, TCC, System Settings or global hotkey registration.

### GREEN

- **Minimal implementation**: added `Sources/ZoomItMacCore/Settings/SettingsManagementSimulation.swift` with pure value types for settings categories/snapshots, an in-memory settings store, hotkey bindings/conflicts and permission-page rows. The model reuses `AppSettings`, `KeyboardModifier`, `KeyboardEventAccess` and `MicrophonePermission`, derives Shift variants for file/region/previous-segment actions, and always reports `.simulatedOnly`.
- **Command**: `swift test --filter Phase6SettingsPermissionsSimulationTests`
- **Observed pass**: `Phase6SettingsPermissionsSimulationTests` passed 4 tests with 0 failures. The command used pure values only and did not touch TCC, real System Settings, real UserDefaults persistence, real global keyboard hooks, real pasteboard, real filesystem output, screen capture, microphone or camera.

### REFACTOR

- **Refactor done**: yes
- **Change**: updated `ZoomItFeatureCoverageMap.phase6Default` and `Phase6FeatureCoverageMapTests` so `settingsAndHotkeyCustomization` and `permissionChecks` are marked `simulatedCompletePhase7Pending` with `Phase6SettingsPermissionsSimulationTests` evidence, instead of remaining as Phase 6 implementation gaps.
- **Command after refactor**:
  - `swift test --filter Phase6SettingsPermissionsSimulationTests`
  - `swift test --filter Phase6FeatureCoverageMapTests`
  - `swift test`
  - `.build/debug/ZoomItMacSelfTest`
  - `ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug`
  - `git diff --check`
- **Observed result**: settings/permissions simulation tests passed 4 tests; coverage map tests passed 5 tests; full `swift test` passed 100 XCTest cases; `ZoomItMacSelfTest` passed; development app build passed; `git diff --check` passed.

### Next Behavior

Phase 6 next simulated slice: close single instance, menu bar status and launch-at-login with simulated process lock, menu state mapping and login item service.

## Verification After Phase 6 Settings/Permissions Slice

- `swift test`: PASS, 100 XCTest cases. All automated coverage remains in simulated/pure boundaries.
- `.build/debug/ZoomItMacSelfTest`: PASS.
- `ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug`: PASS; app bundle generated at `.build/DoraZoom Dev.app`, ad-hoc signed, bundle id `com.duola.dorazoom.dev`.
- `git diff --check`: PASS.
- Current size snapshot:
  - Working source files, excluding `.git` and `.build`: 113 files.
  - Working source payload, excluding `.git` and `.build`: 1,069,459 bytes, about 1,044 KB / 1.020 MB.
  - Swift source lines under `Sources`: 17,652.
  - Development app bundle: `.build/DoraZoom Dev.app`, about 4.7 MB.
- Phase 6 coverage map status: current viewport copy/save, region snip-to-file, region OCR-to-clipboard, break timer, DemoType, panorama, settings/hotkey customization and permission checks are now simulated-complete and Phase 7 pending. Remaining Phase 6 gaps are single instance, menu bar status and launch at login.
- Not claimed: real AppKit settings-window visual acceptance, real UserDefaults disk persistence, real TCC prompts, real System Settings launch, real global hotkey registration/listen/post behavior, real input monitoring, real screen capture, pasteboard, filesystem output, microphone or camera.

## Hai TDD: Phase 6 app lifecycle simulation

### Target Behavior

DoraZoom must close the final Phase 6 simulated proof gap for single instance, menu bar status and launch-at-login. The proof must use a virtual process lock, menu-state planner and simulated login-item service. It must not create a real lock file, post a real distributed notification, create an `NSStatusItem`, call `SMAppService`, register a login item or modify the user's login settings.

### RED

- **Test added**: `Tests/ZoomItMacCoreTests/Phase6AppLifecycleSimulationTests.swift`
- **Behavior asserted**: first launch claims a virtual single-instance lock, duplicate launch posts only a simulated `showSettings` notification and terminates, release clears the virtual lock; menu-bar status maps idle/active/recording session states to correct icon plans and ZoomIt-like menu titles without creating a status item; launch-at-login enable/disable emits simulated register/unregister operations, migrates pending approval into settings when no saved preference exists, and reports unavailable bare-executable state without touching ServiceManagement; coverage map has no Phase 6 gaps.
- **Command**: `swift test --filter Phase6AppLifecycleSimulationTests`
- **Observed failure**: compile failed because `AppLifecycleManagementSimulation`, virtual lock, single-instance result, menu-bar plan, simulated login-item service/result and related enums did not exist.
- **Failure is correct because**: production lifecycle code existed, but there was no pure simulator proving duplicate-launch, menu-state and login-item behavior without touching the real filesystem, distributed notifications, status bar or `SMAppService`.

### GREEN

- **Minimal implementation**: added `Sources/ZoomItMacCore/App/AppLifecycleManagementSimulation.swift` with pure value types for a virtual single-instance lock, single-instance decisions, menu-bar icon plan, login-item service status, register/unregister operations, user-facing alert and migration result. The menu-bar planner derives from existing `InteractionPresentationSnapshot`, and all results report `.simulatedOnly`.
- **Command**: `swift test --filter Phase6AppLifecycleSimulationTests`
- **Observed pass**: `Phase6AppLifecycleSimulationTests` passed 4 tests with 0 failures. The command used pure values only and did not touch real files, real distributed notifications, AppKit status items, ServiceManagement, login items, TCC, global keyboard, pasteboard, screen capture, microphone or camera.

### REFACTOR

- **Refactor done**: yes
- **Change**: updated `ZoomItFeatureCoverageMap.phase6Default` and `Phase6FeatureCoverageMapTests` so `singleInstance`, `menuBarStatus` and `launchAtLogin` are marked `simulatedCompletePhase7Pending`; the coverage map now reports `map.gaps == []`. Also changed one test variable from `var` to `let` to keep the build warning-free.
- **Command after refactor**:
  - `swift test --filter Phase6AppLifecycleSimulationTests`
  - `swift test --filter Phase6FeatureCoverageMapTests`
  - `swift test`
  - `.build/debug/ZoomItMacSelfTest`
  - `ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug`
  - `git diff --check`
- **Observed result**: lifecycle simulation tests passed 4 tests; coverage map tests passed 5 tests; full `swift test` passed 104 XCTest cases; `ZoomItMacSelfTest` passed; development app build passed; `git diff --check` passed.

### Next Behavior

Phase 6 simulated implementation coverage is complete. Next behavior belongs to Phase 7: real Mac acceptance and delivery checks that simulation cannot prove.

## Verification After Phase 6 Complete Simulated Coverage

- `swift test`: PASS, 104 XCTest cases. All automated coverage remains in simulated/pure boundaries.
- `.build/debug/ZoomItMacSelfTest`: PASS.
- `ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug`: PASS; app bundle generated at `.build/DoraZoom Dev.app`, ad-hoc signed, bundle id `com.duola.dorazoom.dev`.
- `git diff --check`: PASS.
- Current size snapshot:
  - Working source files, excluding `.git` and `.build`: 115 files.
  - Working source payload, excluding `.git` and `.build`: 1,086,659 bytes, about 1,061 KB / 1.036 MB.
  - Swift source lines under `Sources`: 17,862.
  - Development app bundle: `.build/DoraZoom Dev.app`, about 4.8 MB.
- Phase 6 coverage map status: every PRD §5.1 capability and DoraZoom Mac adaptation row has implementation references, simulated-test evidence and status `simulatedCompletePhase7Pending`; `map.gaps == []`.
- Not claimed: real TCC prompts, real global keyboard/input monitoring, real `Control+V` interception, real ScreenCaptureKit capture, real pasteboard/file output, real AppKit window/status-item behavior, real ServiceManagement login item state, real microphone/camera capture, real media playback/import compatibility, real performance, real cursor visual acceptance or final user acceptance.

## Hai TDD: Phase 7 release-warning cleanup

### Target Behavior

DoraZoom's Phase 7 release build should compile cleanly on the macOS 14+ / Swift 6 target without masking warnings or lowering optimization. In particular, the panorama stitcher must keep its existing parallel scoring/composition strategy while making the unsafe-buffer concurrency boundary explicit, and the recording clip editor must use modern AVFoundation loading APIs instead of deprecated synchronous asset/track properties.

### RED

- **Test added**: release-build warning gate using `Scripts/build-app.sh release` as the executable check.
- **Behavior asserted**: release daily app build should complete without Sendable unsafe-buffer warnings or AVFoundation deprecated API warnings.
- **Command**: `ZOOMIT_BUNDLE_ID='com.duola.dorazoom' ZOOMIT_DISPLAY_NAME='DoraZoom' ZOOMIT_APP_NAME='DoraZoom.app' ZOOMIT_ARCHS='' ZOOMIT_REQUIRE_RELEASE_VERSION='true' Scripts/build-app.sh release`
- **Observed failure**: command exited 0 but emitted warnings in `PanoramaStitcher.swift` for capturing non-Sendable unsafe buffers inside `DispatchQueue.concurrentPerform`, plus warnings in `VideoClipEditorController.swift` for deprecated `asset.duration`, `tracks(withMediaType:)`, `naturalSize` and `preferredTransform`.
- **Failure is correct because**: the app could build, but Phase 7 delivery quality should not ship with concurrency-boundary warnings or macOS 13+ deprecation warnings when the product target is macOS 14+.

### GREEN

- **Minimal implementation**: added tiny `@unchecked Sendable` unsafe-buffer views in `PanoramaStitcher.swift` so existing disjoint-index/row parallel writes are explicit without making the algorithm serial. Converted mutable gradient arrays to immutable snapshots before `@Sendable` scoring. Updated `VideoClipEditorController.swift` so `ClipSegment` asynchronously loads duration, video/audio tracks, natural size and preferred transform once at import time, then the editor uses cached metadata for preview/export.
- **Command**: `ZOOMIT_BUNDLE_ID='com.duola.dorazoom' ZOOMIT_DISPLAY_NAME='DoraZoom' ZOOMIT_APP_NAME='DoraZoom.app' ZOOMIT_ARCHS='' ZOOMIT_REQUIRE_RELEASE_VERSION='true' Scripts/build-app.sh release`
- **Observed pass**: release daily app build passed with no compiler warnings shown; `.build/DoraZoom.app` generated with bundle id `com.duola.dorazoom`, display name `DoraZoom`, version `1.0`, architecture `arm64`.

### REFACTOR

- **Refactor done**: yes
- **Change**: added `ClipSegment.replacingRange(_:)` so delete/split edits preserve the loaded AVFoundation track metadata when a segment is cut into pieces. This keeps the editor model compact and avoids reloading assets during local timeline operations.
- **Command after refactor**:
  - `swift test --filter Phase6PanoramaSimulationTests`
  - `swift test --filter Phase5RecordingEditorDecisionPlanTests`
  - `swift test`
  - `.build/debug/ZoomItMacSelfTest`
  - `ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug`
  - `ZOOMIT_SIGN_IDENTITY=<existing local codesigning identity> ZOOMIT_BUNDLE_ID='com.duola.dorazoom' ZOOMIT_DISPLAY_NAME='DoraZoom' ZOOMIT_APP_NAME='DoraZoom.app' ZOOMIT_ARCHS='' ZOOMIT_REQUIRE_RELEASE_VERSION='true' Scripts/build-app.sh release`
  - `codesign --verify --deep --strict --verbose=2 '.build/DoraZoom Dev.app'`
  - `codesign --verify --deep --strict --verbose=2 '.build/DoraZoom.app'`
  - `git diff --check`
- **Observed result**: panorama simulation tests passed 3 tests; editor decision tests passed 2 tests; full `swift test` passed 104 XCTest cases; `ZoomItMacSelfTest` passed; dev app build passed; daily release app build passed without warnings; both app bundles passed strict codesign verification; `git diff --check` passed.

### Next Behavior

Phase 7 remaining work is real Mac/user acceptance: `/Applications` install/permission upgrade, real TCC/global input/screen capture/audio/camera/cursor checks, real media compatibility and PRD §14 final sign-off.

## Verification After Phase 7 Non-Invasive Delivery Gates

- `swift build`: PASS.
- `swift test`: PASS, 104 XCTest cases. All automated coverage remains in simulated/pure boundaries.
- `.build/debug/ZoomItMacSelfTest`: PASS.
- `swift package show-dependencies --format text`: PASS, `No external dependencies found`.
- Dev build command: `ZOOMIT_BUNDLE_ID='com.duola.dorazoom.dev' ZOOMIT_DISPLAY_NAME='DoraZoom (Dev)' ZOOMIT_APP_NAME='DoraZoom Dev.app' ZOOMIT_ARCHS='' Scripts/build-app.sh debug`: PASS.
  - Path: `.build/DoraZoom Dev.app`
  - Bundle id: `com.duola.dorazoom.dev`
  - Display name: `DoraZoom (Dev)`
  - Signature: ad-hoc
  - Architecture: `arm64`
  - `codesign --verify --deep --strict --verbose=2 '.build/DoraZoom Dev.app'`: PASS.
- Daily release build command: `ZOOMIT_SIGN_IDENTITY=<existing local codesigning identity> ZOOMIT_BUNDLE_ID='com.duola.dorazoom' ZOOMIT_DISPLAY_NAME='DoraZoom' ZOOMIT_APP_NAME='DoraZoom.app' ZOOMIT_ARCHS='' ZOOMIT_REQUIRE_RELEASE_VERSION='true' Scripts/build-app.sh release`: PASS.
  - Path: `.build/DoraZoom.app`
  - Bundle id: `com.duola.dorazoom`
  - Display name: `DoraZoom`
  - Signature: local Apple Development identity
  - Architecture: `arm64`
  - `codesign --verify --deep --strict --verbose=2 '.build/DoraZoom.app'`: PASS.
  - `codesign -dv --verbose=2 '.build/DoraZoom.app'`: identifier `com.duola.dorazoom`, Apple Development authority chain, non-empty TeamIdentifier.
- Delivery package: `.build/DoraZoom.zip` generated with `ditto -c -k --keepParent '.build/DoraZoom.app' '.build/DoraZoom.zip'`.
- Size snapshot:
  - Working source files, excluding `.git` and `.build`: 115 files.
  - Working source payload, excluding `.git` and `.build`: 1,095,141 bytes, about 1,069 KB / 1.045 MB.
  - Swift source lines under `Sources`: 17,934.
  - Dev app bundle: `.build/DoraZoom Dev.app`, about 4.9 MB; executable about 4.4 MB.
  - Daily release app bundle: `.build/DoraZoom.app`, about 2.1 MB; executable about 1.7 MB.
  - Daily zip package: `.build/DoraZoom.zip`, about 938 KB by `ls -lh` / 992 KB by `du -sh`.
- `git diff --check`: PASS.
- Not claimed: app installed in `/Applications`, TCC permission upgrade, real global hotkeys, real `Control+V`, real ScreenCaptureKit capture, real recording/audio/camera output, real cursor visual feel, real media playback/import, measured p50/p95/CPU/RSS against the official baseline, notarization, or final “哆啦” user acceptance.

## Verification After Reproducible Delivery Script

- Added `Scripts/verify-delivery.sh` as the single non-invasive Phase 7 delivery gate. The script:
  - Runs `swift build`.
  - Runs `swift test`.
  - Runs `.build/debug/ZoomItMacSelfTest`.
  - Requires `swift package show-dependencies --format text` to equal `No external dependencies found`.
  - Builds dev app `.build/DoraZoom Dev.app` with bundle id `com.duola.dorazoom.dev`, display name `DoraZoom (Dev)` and ad-hoc signature.
  - Requires a local codesigning identity for daily release app `.build/DoraZoom.app`; it does not silently downgrade daily release signing to ad-hoc.
  - Builds daily release app with bundle id `com.duola.dorazoom`, display name `DoraZoom`, and the local Apple Development identity.
  - Verifies both app bundles with `codesign --verify --deep --strict --verbose=2`.
  - Verifies daily app identity/authority and confirms camera + audio-input entitlements are present.
  - Creates `.build/DoraZoom.zip`, extracts it to a temporary directory, and verifies the extracted app's code signature.
  - Prints source, Swift line, app and zip size snapshots.
  - Runs `git diff --check`.
- Command: `Scripts/verify-delivery.sh`
- Result: PASS.
- Script output highlights:
  - `swift test`: PASS, 104 XCTest cases.
  - `ZoomItMacSelfTest`: PASS.
  - Dependencies: `No external dependencies found`.
  - Dev app: `.build/DoraZoom Dev.app`, `com.duola.dorazoom.dev`, `DoraZoom (Dev)`, ad-hoc, `arm64`.
  - Daily app: `.build/DoraZoom.app`, `com.duola.dorazoom`, `DoraZoom`, local Apple Development signature, `arm64`.
  - Daily app authority chain includes Apple Development and non-empty TeamIdentifier.
  - Extracted zip app: codesign verification PASS.
  - Source files excluding `.git` and `.build`: 116.
  - Source bytes excluding `.git` and `.build`: 1,106,531 bytes, about 1,080 KB / 1.055 MB.
  - Swift source lines under `Sources`: 17,934.
  - Dev app bundle: about 4.9 MB.
  - Daily release app bundle: about 2.1 MB.
  - Daily zip package: about 938 KB.
- Not claimed: app installed in `/Applications`, TCC permission upgrade, real global hotkeys, real `Control+V`, real ScreenCaptureKit capture, real recording/audio/camera output, real cursor visual feel, real media playback/import, measured p50/p95/CPU/RSS against the official baseline, notarization, or final “哆啦” user acceptance.

## Verification After Phase 7 Acceptance Package

- Added `ACCEPTANCE.md` as the manual Phase 7 acceptance checklist.
- The checklist explicitly separates:
  - non-invasive automated delivery gates;
  - visible, user-controlled `/Applications` installation;
  - real TCC permission prompts and settings navigation;
  - real global hotkey and cursor-feel checks;
  - real `Command+V` / authorized `Control+V` paste checks;
  - real ScreenCaptureKit, system-audio, microphone and camera recording checks;
  - MOV/MP4/GIF playback/import checks in QuickTime, Windows, 剪映 and DaVinci Resolve;
  - p50/p95/CPU/RSS performance records;
  - final “哆啦” sign-off.
- Updated `README.md` from upstream ZoomIt/Homebrew wording to DoraZoom-specific identity, build, test and acceptance wording.
- Automated-test policy recorded: all automated tests use simulation boundaries only and must not touch real TCC, global keyboard input, real screen capture, microphone, camera, real pasteboard, target apps, login items or real user-output files.
- Re-ran `Scripts/verify-delivery.sh` after the documentation update.
  - Result: PASS.
  - `swift test`: PASS, 104 XCTest cases, all within simulated/pure boundaries.
  - `ZoomItMacSelfTest`: PASS.
  - Dependencies: `No external dependencies found`.
  - Dev app: `.build/DoraZoom Dev.app`, `com.duola.dorazoom.dev`, `DoraZoom (Dev)`, ad-hoc, `arm64`.
  - Daily app: `.build/DoraZoom.app`, `com.duola.dorazoom`, `DoraZoom`, local Apple Development signature, `arm64`.
  - Extracted zip app: codesign verification PASS.
  - Source files excluding `.git` and `.build`: 117.
  - Source bytes excluding `.git` and `.build`: 1,106,366 bytes, about 1,080 KB / 1.055 MB.
  - Swift source lines under `Sources`: 17,934.
  - Dev app bundle: about 4.9 MB.
  - Daily release app bundle: about 2.1 MB.
  - Daily zip package: about 938 KB.
- Not claimed: any manual Phase 7 item has passed. The acceptance package is a proof scaffold, not a substitute for real user acceptance.

## Hai TDD: DoraZoom Product Identity Cleanup

### Target Behavior

DoraZoom's user-visible product identity must use DoraZoom / 哆啦 rather than upstream Sysinternals branding in app information and local coordination identifiers. Upstream attribution remains in README/PRD/license documentation, but the runtime UI and generated app metadata should present DoraZoom as the current product.

### RED 1

- **Test added**: `Tests/ZoomItMacCoreTests/Phase7ProductIdentityTests.swift`, `testAppInfoUsesDoraZoomPersonalEditionIdentity`.
- **Behavior asserted**: `AppInfo.productName == "DoraZoom"` and `AppInfo.copyright == "Copyright © 2026 哆啦"`.
- **Command**: `swift test --filter Phase7ProductIdentityTests`.
- **Observed failure**: test failed because production returned `Sysinternals ZoomIt` and `Copyright © 2026 Mark Russinovich`.
- **Failure is correct because**: the settings footer consumes `AppInfo`, so the failure exposes the old upstream identity that would be visible in DoraZoom's UI.

### GREEN 1

- **Minimal implementation**: changed `Sources/ZoomItMacCore/App/AppInfo.swift` product name to `DoraZoom` and copyright to `Copyright © 2026 哆啦`.
- **Command**: `swift test --filter Phase7ProductIdentityTests`.
- **Observed pass**: product identity test passed.

### RED 2

- **Test added**: `Tests/ZoomItMacCoreTests/Phase7ProductIdentityTests.swift`, `testSingleInstanceNotificationUsesDoraZoomNamespace`.
- **Behavior asserted**: `SingleInstance.showSettingsNotification.rawValue == "com.duola.dorazoom.showSettings"`.
- **Command**: `swift test --filter Phase7ProductIdentityTests`.
- **Observed failure**: test failed because production returned `com.sysinternals.zoomitmac.showSettings`.
- **Failure is correct because**: the local distributed notification name was still using the upstream namespace, which contradicts DoraZoom's bundle identity and local state namespace.

### GREEN 2

- **Minimal implementation**: changed `SingleInstance.showSettingsNotification` to `com.duola.dorazoom.showSettings`; changed the single-instance lock directory/file to `DoraZoom/DoraZoom.lock`; changed the menu-bar autosave name to `com.duola.DoraZoom.statusItem`.
- **Command**: `swift test --filter Phase7ProductIdentityTests`.
- **Observed pass**: both product identity tests passed.

### REFACTOR

- **Refactor done**: yes.
- **Change**: removed the Sysinternals hyperlink from the Settings footer and changed the Settings title to `DoraZoom Settings`; updated `Scripts/build-app.sh`, `Scripts/reset-first-run.sh`, and `ZoomItInfo.plist` defaults/permission descriptions to DoraZoom identity. This keeps upstream attribution in documents instead of primary runtime UI. No compatibility path was added.
- **Command after refactor**:
  - `swift test --filter Phase7ProductIdentityTests`
  - `swift test`
  - `.build/debug/ZoomItMacSelfTest`
  - `zsh -n Scripts/build-app.sh`
  - `zsh -n Scripts/reset-first-run.sh`
  - `git diff --check`
  - `Scripts/verify-delivery.sh`
- **Observed result**:
  - `Phase7ProductIdentityTests`: PASS, 2 tests.
  - `swift test`: PASS, 106 XCTest cases, all automated coverage remains simulated/pure.
  - `ZoomItMacSelfTest`: PASS.
  - `Scripts/verify-delivery.sh`: PASS.
  - Dependencies: `No external dependencies found`.
  - Dev app: `.build/DoraZoom Dev.app`, `com.duola.dorazoom.dev`, `DoraZoom (Dev)`, ad-hoc, `arm64`.
  - Daily app: `.build/DoraZoom.app`, `com.duola.dorazoom`, `DoraZoom`, local Apple Development signature, `arm64`.
  - Source files excluding `.git` and `.build`: 118.
  - Source bytes excluding `.git` and `.build`: 1,106,183 bytes, about 1,080 KB / 1.055 MB.
  - Swift source lines under `Sources`: 17,900.
  - Dev app bundle: about 4.9 MB.
  - Daily release app bundle: about 2.1 MB.
  - Daily zip package: about 936 KB.

### Next Behavior

Manual Phase 7 acceptance remains next: real `/Applications` install, real TCC/global hotkeys/clipboard/cursor/recording/media/performance checks, and final “哆啦” sign-off.

## Hai TDD: DoraZoom Bundle Executable Identity

### Target Behavior

The generated `.app` bundles should not expose the upstream executable name as the app process identity. Both `.build/DoraZoom Dev.app` and `.build/DoraZoom.app` must set `CFBundleExecutable` to `DoraZoom`, contain an executable file at `Contents/MacOS/DoraZoom`, and not contain `Contents/MacOS/ZoomIt`. SwiftPM target and resource names may remain `ZoomIt*` internally to avoid a broad, low-value source tree rename.

### RED

- **Test added**: `Scripts/verify-delivery.sh` bundle identity assertions for `CFBundleExecutable`, `Contents/MacOS/DoraZoom` and absence of `Contents/MacOS/ZoomIt`.
- **Behavior asserted**: dev and daily bundles both expose `DoraZoom` as their bundle executable name and do not leave a stale upstream-named executable in the app bundle.
- **Command**:
  - `Scripts/verify-delivery.sh`
- **Observed failure**: delivery verification failed during bundle identity audit with `error: dev executable name expected 'DoraZoom', got 'ZoomIt'`.
- **Failure is correct because**: the build script still copied the SwiftPM executable to `Contents/MacOS/ZoomIt` and wrote `CFBundleExecutable=ZoomIt`, so macOS-visible process identity could drift from the DoraZoom product identity.

### GREEN

- **Minimal implementation**:
  - Added `APP_EXECUTABLE_NAME="DoraZoom"` to `Scripts/build-app.sh`.
  - Copied the built SwiftPM binary to `Contents/MacOS/DoraZoom`.
  - Wrote `CFBundleExecutable=DoraZoom`.
  - Updated build-script architecture reporting and delivery-script architecture checks to read `Contents/MacOS/DoraZoom`.
  - Updated the explicit manual reset script to quit `/Contents/MacOS/DoraZoom`.
- **Command**:
  - `Scripts/build-app.sh debug >/tmp/dorazoom-build-debug.out`
  - `plutil -extract CFBundleExecutable raw "$(tail -n 1 /tmp/dorazoom-build-debug.out)/Contents/Info.plist"`
  - `test -x "$(tail -n 1 /tmp/dorazoom-build-debug.out)/Contents/MacOS/DoraZoom"`
  - `test ! -e "$(tail -n 1 /tmp/dorazoom-build-debug.out)/Contents/MacOS/ZoomIt"`
- **Observed pass**: debug app reported `CFBundleExecutable=DoraZoom`, had `Contents/MacOS/DoraZoom`, and no longer contained `Contents/MacOS/ZoomIt`.

### REFACTOR

- **Refactor done**: yes.
- **Change**: centralized app executable naming inside build/delivery scripts instead of duplicating the executable path in several checks; then tightened delivery verification to reject stale `Contents/MacOS/ZoomIt` files. No runtime compatibility branch was added; the remaining `tccutil reset All "ZoomIt"` stays only in the explicit manual reset script for stale pre-DoraZoom permission cleanup.
- **Command after refactor**:
  - `Scripts/verify-delivery.sh`
- **Observed result**:
  - `Scripts/verify-delivery.sh`: PASS.
  - `swift build`: PASS.
  - `swift test`: PASS, 109 XCTest cases; all automated coverage remains simulated/pure.
  - `ZoomItMacSelfTest`: PASS.
  - Dependency audit: `No external dependencies found`.
  - Dev app: `.build/DoraZoom Dev.app`, `com.duola.dorazoom.dev`, `DoraZoom (Dev)`, `CFBundleExecutable=DoraZoom`, ad-hoc signed, `arm64`.
  - Daily app: `.build/DoraZoom.app`, `com.duola.dorazoom`, `DoraZoom`, `CFBundleExecutable=DoraZoom`, Apple Development signed, `arm64`.
  - Daily zip package: `.build/DoraZoom.zip`, about 936 KB; unzip-and-codesign verification passed.
  - Source files excluding `.git` and `.build`: 118.
  - Source bytes excluding `.git` and `.build`: 1,132,354 bytes, about 1,106 KB / 1.080 MB.
  - Swift source lines under `Sources`: 17,918.
  - Dev app bundle: about 4.9 MB.
  - Daily release app bundle: about 2.1 MB.
  - `git diff --check`: PASS.

### Next Behavior

Manual Phase 7 acceptance remains next: real `/Applications` install, real TCC/global hotkeys/clipboard/cursor/recording/media/performance checks, and final “哆啦” sign-off.

## Hai TDD: Default Development App Bundle Path

### Target Behavior

Running `Scripts/build-app.sh debug` without overriding `ZOOMIT_APP_NAME` should produce the same development app bundle path used by the README, acceptance checklist and delivery script: `.build/DoraZoom Dev.app`. The display name remains `DoraZoom (Dev)`.

### RED

- **Test added**: shell assertion run directly against `Scripts/build-app.sh debug`.
- **Behavior asserted**: the last output path from the default debug build equals `/Users/happy/Desktop/zoomit/.build/DoraZoom Dev.app`.
- **Command**:
  - `OUTPUT="$(ZOOMIT_ARCHS='' Scripts/build-app.sh debug 2>/tmp/dorazoom-build-default.stderr)"; EXPECTED="/Users/happy/Desktop/zoomit/.build/DoraZoom Dev.app"; [[ "$OUTPUT" == "$EXPECTED" ]]`
- **Observed failure**: command failed because the script produced `/Users/happy/Desktop/zoomit/.build/DoraZoom (Dev).app`.
- **Failure is correct because**: the build script's default `.app` file name disagreed with the documented and verified dev app path, so a manual tester could look for the wrong bundle.

### GREEN

- **Minimal implementation**: changed `Scripts/build-app.sh` to keep a stable default app file name independent from display name: `DoraZoom Dev.app` for ad-hoc development builds and `DoraZoom.app` for signed daily builds. Updated `Scripts/reset-first-run.sh` to target `DoraZoom Dev.app` by default.
- **Command**:
  - `OUTPUT="$(ZOOMIT_ARCHS='' Scripts/build-app.sh debug | tail -n 1)"; EXPECTED="/Users/happy/Desktop/zoomit/.build/DoraZoom Dev.app"; [[ "$OUTPUT" == "$EXPECTED" ]]`
  - `plutil -extract CFBundleIdentifier raw ".build/DoraZoom Dev.app/Contents/Info.plist"`
  - `plutil -extract CFBundleDisplayName raw ".build/DoraZoom Dev.app/Contents/Info.plist"`
- **Observed pass**: default debug output path was `/Users/happy/Desktop/zoomit/.build/DoraZoom Dev.app`; bundle id was `com.duola.dorazoom.dev`; display name was `DoraZoom (Dev)`.

### REFACTOR

- **Refactor done**: no.
- **Change**: no further refactor needed; this is a small script default correction.
- **Command after refactor**:
  - `zsh -n Scripts/build-app.sh`
  - `zsh -n Scripts/reset-first-run.sh`
  - `Scripts/verify-delivery.sh`
- **Observed result**:
  - Shell syntax checks: PASS.
  - `Scripts/verify-delivery.sh`: PASS.
  - `swift test`: PASS, 106 XCTest cases.
  - `ZoomItMacSelfTest`: PASS.
  - Dependencies: `No external dependencies found`.
  - Dev app: `.build/DoraZoom Dev.app`, `com.duola.dorazoom.dev`, `DoraZoom (Dev)`, ad-hoc, `arm64`.
  - Daily app: `.build/DoraZoom.app`, `com.duola.dorazoom`, `DoraZoom`, local Apple Development signature, `arm64`.
  - Source files excluding `.git` and `.build`: 118.
  - Source bytes excluding `.git` and `.build`: 1,113,348 bytes, about 1,087 KB / 1.062 MB.
  - Swift source lines under `Sources`: 17,900.
  - Dev app bundle: about 4.9 MB.
  - Daily release app bundle: about 2.1 MB.
  - Daily zip package: about 936 KB.

### Next Behavior

Manual Phase 7 acceptance remains next unless another non-invasive delivery inconsistency is found.

## Hai TDD: DoraZoom Recording File Naming and Simulation-Only Delivery Gate

### Target Behavior

Recording files should use DoraZoom product identity everywhere user-visible or temporary recording output is named. Default movie naming should be `DoraZoom yyyy-MM-dd HHmmss.mov`, temporary recording files should be `DoraZoom-<id>.mov`, and temporary edit exports should be `DoraZoom-edit-<id>.mov`. Automated proof remains simulation-only: it must not touch real TCC, global keyboard input, real screen capture, microphone, camera, real pasteboard, real media players, target apps or real user-output files.

### RED

- **Test added**: `Phase5RecordingMovieProfileTests/testRecordingFileNamesUseDoraZoomProductPrefix`.
- **Behavior asserted**: suggested, temporary recording and temporary edit filenames all use the DoraZoom prefix and the default MOV profile extension.
- **Observed failure**: before the naming helper existed, the codebase had no single testable naming surface for recording output and edit temp files.
- **Failure is correct because**: recording output names were still scattered across production controllers, so product identity could drift without a focused test catching it.

### GREEN

- **Minimal implementation**: added `RecordingFileNaming` in `Sources/ZoomItMacCore/Capture/RecordingOutputStrategy.swift` and wired it into `RecordingController` and `VideoClipEditorController`.
- **Command**:
  - `swift test --filter Phase5RecordingMovieProfileTests/testRecordingFileNamesUseDoraZoomProductPrefix`
- **Observed pass**: the focused test passed and verified `DoraZoom 2026-07-27 095800.mov`, `DoraZoom-sample-id.mov` and `DoraZoom-edit-sample-id.mov`.

### REFACTOR

- **Refactor done**: yes.
- **Change**: centralized product-prefix recording names in `RecordingFileNaming` so controller code consumes one strategy instead of embedding filename literals.
- **Command after refactor**:
  - `Scripts/verify-delivery.sh`
- **Observed result**:
  - Result: PASS.
  - `swift build`: PASS.
  - `swift test`: PASS, 107 XCTest cases; all automated coverage remains simulated/pure.
  - `ZoomItMacSelfTest`: PASS.
  - Dependencies: `No external dependencies found`.
  - Dev app: `.build/DoraZoom Dev.app`, `com.duola.dorazoom.dev`, `DoraZoom (Dev)`, ad-hoc, `arm64`.
  - Daily app: `.build/DoraZoom.app`, `com.duola.dorazoom`, `DoraZoom`, Apple Development signature, `arm64`.
  - Daily zip package: `.build/DoraZoom.zip`, about 936 KB; unzip-and-codesign verification passed.
  - Source files excluding `.git` and `.build`: 118.
  - Source bytes excluding `.git` and `.build`: 1,117,382 bytes, about 1,091 KB / 1.066 MB.
  - Swift source lines under `Sources`: 17,914.
  - Dev app bundle: about 4.9 MB.
  - Daily release app bundle: about 2.1 MB.
  - `git diff --check`: PASS.

### Not Claimed

Real recording playback/import, real ScreenCaptureKit capture, real microphone/camera/system-audio capture, real cursor feel, real TCC prompts, real global hotkeys, real `Control+V`, real target-app paste, real media compatibility and final “哆啦” acceptance remain Phase 7 manual evidence.

## Hai TDD: Runtime User-Facing DoraZoom Identity

### Target Behavior

DoraZoom runtime UI should present the current product identity as DoraZoom, not upstream ZoomIt. Upstream ZoomIt references may remain in package names, resource symbols, comments and documentation where they describe provenance or implementation ancestry, but runtime user-facing strings in the settings window, permission dialog, recording editor, image filename suggestions, panorama progress and login-item errors must not show the upstream product name.

### RED

- **Test added**: `Phase7ProductIdentityTests/testLaunchAtLoginUnavailableMessageUsesDoraZoomAppName` and `Phase7ProductIdentityTests/testRuntimeUserFacingSourcesDoNotUseUpstreamZoomItName`.
- **Behavior asserted**:
  - Non-`.app` launch-at-login errors mention `DoraZoom.app` and not `ZoomIt.app`.
  - Selected runtime UI source files contain no user-facing `ZoomIt` text; comments and internal icon symbols are excluded.
- **Command**:
  - `swift test --filter Phase7ProductIdentityTests/testLaunchAtLoginUnavailableMessageUsesDoraZoomAppName`
  - `swift test --filter Phase7ProductIdentityTests/testRuntimeUserFacingSourcesDoNotUseUpstreamZoomItName`
- **Observed failure**:
  - Launch-at-login test failed with `Launch at login requires running ZoomIt from ZoomIt.app.`
  - Runtime identity scan failed on settings text, permission title, relaunch guidance, menu-bar fallback title, snip filename suggestion, panorama progress, editor title, break-timer sleep assertion reason and DemoType help text.
- **Failure is correct because**: the missing behavior was product identity cleanup in runtime-facing text, not a real macOS permission, global hotkey, screen capture or media environment failure.

### GREEN

- **Minimal implementation**:
  - Added `LaunchAtLogin.unavailableMessage` and reused it in both the thrown localized error and settings tooltip.
  - Replaced user-facing runtime strings with DoraZoom in permission dialogs, settings help, login-item checkbox/error text, image suggested filenames, panorama progress/log text, recording editor title, break-timer sleep reason and the menu-bar fallback title.
  - Left upstream references in documentation, comments, package names, executable/resource names and `ZoomItAppIcon` symbols untouched.
- **Command**:
  - `swift test --filter Phase7ProductIdentityTests`
- **Observed pass**: 4 Phase 7 product identity tests passed, including the runtime identity scan.

### REFACTOR

- **Refactor done**: yes.
- **Change**: centralized the launch-at-login unavailable message to avoid drift between the settings tooltip and thrown error. No compatibility path was added.
- **Command after refactor**:
  - `swift test`
  - `Scripts/verify-delivery.sh`
- **Observed result**:
  - `swift test`: PASS, 109 XCTest cases; all automated coverage remains simulated/pure.
  - `Scripts/verify-delivery.sh`: PASS.
  - `ZoomItMacSelfTest`: PASS.
  - Dependencies: `No external dependencies found`.
  - Dev app: `.build/DoraZoom Dev.app`, `com.duola.dorazoom.dev`, `DoraZoom (Dev)`, ad-hoc, `arm64`.
  - Daily app: `.build/DoraZoom.app`, `com.duola.dorazoom`, `DoraZoom`, Apple Development signature, `arm64`.
  - Daily zip package: `.build/DoraZoom.zip`, about 936 KB; unzip-and-codesign verification passed.
  - Source files excluding `.git` and `.build`: 118.
  - Source bytes excluding `.git` and `.build`: 1,122,965 bytes, about 1,097 KB / 1.071 MB.
  - Swift source lines under `Sources`: 17,918.
  - Dev app bundle: about 4.9 MB.
  - Daily release app bundle: about 2.1 MB.
  - `git diff --check`: PASS.

### Next Behavior

Manual Phase 7 acceptance remains next: real `/Applications` install, real TCC/global hotkeys/clipboard/cursor/recording/media/performance checks, and final “哆啦” sign-off.

## Hai TDD: Delivery Gate Exercises Default Development App Path

### Target Behavior

`Scripts/verify-delivery.sh` should validate the default development app path from `Scripts/build-app.sh` instead of passing `ZOOMIT_APP_NAME` and bypassing the default. This makes the delivery gate catch future drift between the build script default and the manual acceptance documentation.

### RED

- **Test added**: shell assertion against `Scripts/verify-delivery.sh`.
- **Behavior asserted**: the delivery script must not contain `ZOOMIT_APP_NAME='DoraZoom Dev.app'` in the dev build path.
- **Command**:
  - `if rg -q "ZOOMIT_APP_NAME='DoraZoom Dev\\.app'" Scripts/verify-delivery.sh; then exit 1; fi`
- **Observed failure**: command failed with `verify-delivery still overrides the dev app file name instead of exercising Scripts/build-app.sh's default.`
- **Failure is correct because**: the delivery gate was still passing an explicit app name, so it did not prove the default `Scripts/build-app.sh debug` output path matched the acceptance docs.

### GREEN

- **Minimal implementation**: removed the dev-build `ZOOMIT_APP_NAME='DoraZoom Dev.app'` override from `Scripts/verify-delivery.sh`. The script still asserts the resulting app path, bundle id and display name through its existing `DEV_APP` identity audit.
- **Command**:
  - `if rg -q "ZOOMIT_APP_NAME='DoraZoom Dev\\.app'" Scripts/verify-delivery.sh; then exit 1; fi`
  - `zsh -n Scripts/verify-delivery.sh`
- **Observed pass**: assertion and shell syntax check passed.

### REFACTOR

- **Refactor done**: no.
- **Change**: no further refactor needed; this is a targeted delivery-gate correction.
- **Command after refactor**:
  - `Scripts/verify-delivery.sh`
- **Observed result**:
  - Result: PASS.
  - `swift test`: PASS, 106 XCTest cases.
  - `ZoomItMacSelfTest`: PASS.
  - Dependencies: `No external dependencies found`.
  - Dev app: `.build/DoraZoom Dev.app`, `com.duola.dorazoom.dev`, `DoraZoom (Dev)`, ad-hoc, `arm64`; generated via the build script default app name.
  - Daily app: `.build/DoraZoom.app`, `com.duola.dorazoom`, `DoraZoom`, local Apple Development signature, `arm64`.
  - Source files excluding `.git` and `.build`: 118.
  - Source bytes excluding `.git` and `.build`: 1,113,311 bytes, about 1,087 KB / 1.062 MB.
  - Swift source lines under `Sources`: 17,900.
  - Dev app bundle: about 4.9 MB.
  - Daily release app bundle: about 2.1 MB.
  - Daily zip package: about 936 KB.

### Next Behavior

Manual Phase 7 acceptance remains next unless another non-invasive delivery inconsistency is found.

## Hai TDD: Delivery Gate Enforces Simulator-Only Automated Tests

### Target Behavior

`Scripts/verify-delivery.sh` must prove that automated test sources stay inside DoraZoom's simulator/simulation boundary. The gate should reject tests that directly invoke real platform side effects such as system pasteboard mutation, Event Tap creation, ScreenCaptureKit capture, microphone/camera devices, TCC mutation, login items or HID input.

### RED

- **Test added**: shell assertion against `Scripts/verify-delivery.sh`.
- **Behavior asserted**: the delivery script must invoke a test-boundary audit before running automated tests.
- **Command**:
  - `if rg -q "verify-test-boundary" Scripts/verify-delivery.sh; then exit 1; else exit 42; fi`
- **Observed failure**: command exited `42` with `RED: delivery gate does not invoke test boundary audit`.
- **Failure is correct because**: the delivery gate already ran simulated tests, but it did not yet contain an explicit guard preventing future tests from drifting into real macOS APIs.

### GREEN

- **Minimal implementation**:
  - Added `Scripts/verify-test-boundary.sh`.
  - The script scans `Tests/` for forbidden real-platform API patterns including `NSPasteboard.general`, Event Tap creation, ScreenCaptureKit stream/content APIs, camera/microphone device APIs, `tccutil`, `SMAppService` and HID access.
  - Added an `Automated test boundary audit` section to `Scripts/verify-delivery.sh`.
- **Command**:
  - `zsh -n Scripts/verify-test-boundary.sh`
  - `zsh -n Scripts/verify-delivery.sh`
  - `Scripts/verify-test-boundary.sh`
- **Observed pass**: syntax checks passed; the boundary audit printed `PASS: automated tests stay inside the simulation boundary`.

### REFACTOR

- **Refactor done**: no.
- **Change**: no refactor needed; this is a small delivery-gate guard.
- **Command after refactor**:
  - `Scripts/verify-delivery.sh`
- **Observed result**:
  - Result: PASS.
  - Automated test boundary audit: PASS.
  - `swift build`: PASS.
  - `swift test`: PASS, 109 XCTest cases.
  - `ZoomItMacSelfTest`: PASS.
  - Dependencies: `No external dependencies found`.
  - Dev app: `.build/DoraZoom Dev.app`, `com.duola.dorazoom.dev`, `DoraZoom (Dev)`, ad-hoc, `arm64`.
  - Daily app: `.build/DoraZoom.app`, `com.duola.dorazoom`, `DoraZoom`, Apple Development signed, `arm64`.
  - Bundle executable/icon audit: `DoraZoom` executable and `DoraZoom.icns` in both dev and daily apps; stale `ZoomIt` executable/icon absent.
  - Daily zip package: `.build/DoraZoom.zip`, unzip-and-codesign verification passed, about 936 KB.
  - Source files excluding `.git` and `.build`: 119.
  - Source bytes excluding `.git` and `.build`: 1,139,469 bytes, about 1,113 KB / 1.087 MB.
  - Swift source lines under `Sources`: 17,918.
  - Dev app bundle: about 4.9 MB.
  - Daily release app bundle: about 2.1 MB.
  - `git diff --check`: PASS.

### Next Behavior

Manual Phase 7 acceptance remains next: real `/Applications` install, real TCC/global hotkeys/clipboard/cursor/recording/media/performance checks, and final “哆啦” sign-off.

## Hai TDD: Delivery Gate Enforces Menu-Bar Accessory Bundle Mode

### Target Behavior

DoraZoom should remain a menu-bar/accessory-style macOS app and should not gain an unnecessary Dock main-window identity during delivery packaging. Both development and daily bundles must carry `LSUIElement=true` in their generated `Info.plist`, and the delivery gate must fail if this metadata drifts.

### RED

- **Test added**: shell assertion against `Scripts/verify-delivery.sh`.
- **Behavior asserted**: the delivery script must explicitly assert `LSUIElement` for generated app bundles.
- **Command**:
  - `if rg -q "LSUIElement" Scripts/verify-delivery.sh; then exit 1; else exit 42; fi`
- **Observed failure**: command exited `42` with `RED: delivery gate does not assert LSUIElement/menu-bar accessory identity`.
- **Failure is correct because**: `Scripts/build-app.sh` generated `LSUIElement=true`, but the delivery gate did not prove the packaged dev and daily apps retained that PRD-required menu-bar identity.

### GREEN

- **Minimal implementation**: added `LSUIElement=true` assertions for both `.build/DoraZoom Dev.app` and `.build/DoraZoom.app` in the bundle identity audit section of `Scripts/verify-delivery.sh`.
- **Command**:
  - `zsh -n Scripts/verify-delivery.sh`
  - `rg -n "LSUIElement|menu-bar accessory" Scripts/verify-delivery.sh`
- **Observed pass**: shell syntax passed; the script contains dev and daily `LSUIElement` assertions.

### REFACTOR

- **Refactor done**: no.
- **Change**: no refactor needed; this is a focused delivery-gate assertion.
- **Command after refactor**:
  - `Scripts/verify-delivery.sh`
- **Observed result**:
  - Result: PASS.
  - Automated test boundary audit: PASS.
  - `swift build`: PASS.
  - `swift test`: PASS, 109 XCTest cases.
  - `ZoomItMacSelfTest`: PASS.
  - Dev and daily bundle identity audit now includes `LSUIElement=true`.
  - Dependencies: `No external dependencies found`.
  - Dev app: `.build/DoraZoom Dev.app`, `com.duola.dorazoom.dev`, `DoraZoom (Dev)`, ad-hoc, `arm64`.
  - Daily app: `.build/DoraZoom.app`, `com.duola.dorazoom`, `DoraZoom`, Apple Development signed, `arm64`.
  - Daily zip package: `.build/DoraZoom.zip`, unzip-and-codesign verification passed, about 936 KB.
  - Source files excluding `.git` and `.build`: 119.
  - Source bytes excluding `.git` and `.build` at the delivery-gate run: 1,139,709 bytes, about 1,113 KB / 1.087 MB.
  - Swift source lines under `Sources`: 17,918.
  - Dev app bundle: about 4.9 MB.
  - Daily release app bundle: about 2.1 MB.
  - `git diff --check`: PASS.

### Next Behavior

Manual Phase 7 acceptance remains next: the Dock/menu-bar visual behavior still needs user-visible confirmation after manual launch, but packaging drift is now guarded.

## Hai TDD: Delivery Gate Enforces Platform and Privacy Bundle Metadata

### Target Behavior

DoraZoom's generated development and daily app bundles must preserve the product's macOS 14+ platform target and user-facing privacy purpose strings. The delivery gate should fail if either bundle loses `LSMinimumSystemVersion=14.0` or if camera/microphone usage descriptions disappear or stop naming DoraZoom.

### RED

- **Test added**: shell assertion against `Scripts/verify-delivery.sh`.
- **Behavior asserted**: the delivery script must explicitly assert `LSMinimumSystemVersion`, `NSCameraUsageDescription` and `NSMicrophoneUsageDescription`.
- **Command**:
  - `if rg -q "LSMinimumSystemVersion|NSCameraUsageDescription|NSMicrophoneUsageDescription" Scripts/verify-delivery.sh; then exit 1; else exit 42; fi`
- **Observed failure**: command exited `42` with `RED: delivery gate does not assert macOS minimum or camera/microphone usage descriptions`.
- **Failure is correct because**: `Scripts/build-app.sh` generated the metadata, but the delivery gate did not prove the packaged dev and daily apps retained the PRD-required macOS floor or DoraZoom-branded permission explanations.

### GREEN

- **Minimal implementation**:
  - Added `assert_contains` to `Scripts/verify-delivery.sh`.
  - Added dev and daily assertions for `LSMinimumSystemVersion=14.0`.
  - Added dev and daily assertions that camera and microphone usage descriptions contain `DoraZoom`.
- **Command**:
  - `zsh -n Scripts/verify-delivery.sh`
  - `rg -n "assert_contains|LSMinimumSystemVersion|NSCameraUsageDescription|NSMicrophoneUsageDescription" Scripts/verify-delivery.sh`
- **Observed pass**: shell syntax passed; the delivery script now contains platform and privacy metadata assertions.

### REFACTOR

- **Refactor done**: no.
- **Change**: no refactor needed; this is a focused metadata gate.
- **Command after refactor**:
  - `Scripts/verify-delivery.sh`
- **Observed result**:
  - Result: PASS.
  - Automated test boundary audit: PASS.
  - `swift build`: PASS.
  - `swift test`: PASS, 109 XCTest cases.
  - `ZoomItMacSelfTest`: PASS.
  - Dev and daily bundle identity audit now includes macOS 14.0 minimum version plus DoraZoom-branded camera/microphone usage descriptions.
  - Dependencies: `No external dependencies found`.
  - Dev app: `.build/DoraZoom Dev.app`, `com.duola.dorazoom.dev`, `DoraZoom (Dev)`, ad-hoc, `arm64`.
  - Daily app: `.build/DoraZoom.app`, `com.duola.dorazoom`, `DoraZoom`, Apple Development signed, `arm64`.
  - Daily zip package: `.build/DoraZoom.zip`, unzip-and-codesign verification passed, about 936 KB.
  - Source files excluding `.git` and `.build`: 119.
  - Source bytes excluding `.git` and `.build` at the delivery-gate run: 1,143,857 bytes, about 1,117 KB / 1.091 MB.
  - Swift source lines under `Sources`: 17,918.
  - Dev app bundle: about 4.9 MB.
  - Daily release app bundle: about 2.1 MB.
  - `git diff --check`: PASS.

### Next Behavior

Manual Phase 7 acceptance remains next: actual TCC prompts and privacy-setting behavior still require visible user acceptance, but bundle metadata drift is now guarded.

## Hai TDD: Delivery Gate Audits Development Entitlements Too

### Target Behavior

Both DoraZoom development and daily bundles must carry the camera and microphone entitlements used by the hardened-runtime media path. The delivery gate should not only check the daily signed app; the development bundle is the first Phase 7 manual-test target and must fail delivery if its entitlements drift.

### RED

- **Test added**: shell assertion against `Scripts/verify-delivery.sh`.
- **Behavior asserted**: the delivery script must parse and assert dev app entitlements, not only daily app entitlements.
- **Command**:
  - `if rg -q "DEV_ENTITLEMENTS|dev entitlements|codesign -d --entitlements.*DEV_APP" Scripts/verify-delivery.sh; then exit 1; else exit 42; fi`
- **Observed failure**: command exited `42` with `RED: delivery gate only audits daily entitlements, dev camera/microphone entitlements are not asserted`.
- **Failure is correct because**: `Scripts/build-app.sh` embedded entitlements for ad-hoc dev builds, but the delivery gate only inspected the daily app's signed entitlements, leaving the development acceptance target unguarded.

### GREEN

- **Minimal implementation**:
  - Added `DEV_ENTITLEMENTS` and `DAILY_ENTITLEMENTS` extraction in the codesign audit.
  - Asserted `com.apple.security.device.audio-input` and `com.apple.security.device.camera` for both dev and daily apps.
- **Command**:
  - `zsh -n Scripts/verify-delivery.sh`
  - `rg -n "DEV_ENTITLEMENTS|DAILY_ENTITLEMENTS|device\\.audio-input|device\\.camera" Scripts/verify-delivery.sh`
- **Observed pass**: shell syntax passed; the delivery script now contains dev and daily entitlement assertions.

### REFACTOR

- **Refactor done**: no.
- **Change**: no refactor needed; this is a focused codesign-entitlement gate.
- **Command after refactor**:
  - `Scripts/verify-delivery.sh`
- **Observed result**:
  - Result: PASS.
  - Automated test boundary audit: PASS.
  - `swift build`: PASS.
  - `swift test`: PASS, 109 XCTest cases.
  - `ZoomItMacSelfTest`: PASS.
  - Dev and daily codesign verification passed; both entitlement payloads include camera and audio-input keys.
  - Dependencies: `No external dependencies found`.
  - Dev app: `.build/DoraZoom Dev.app`, `com.duola.dorazoom.dev`, `DoraZoom (Dev)`, ad-hoc, `arm64`.
  - Daily app: `.build/DoraZoom.app`, `com.duola.dorazoom`, `DoraZoom`, Apple Development signed, `arm64`.
  - Daily zip package: `.build/DoraZoom.zip`, unzip-and-codesign verification passed, about 936 KB.
  - Source files excluding `.git` and `.build`: 119.
  - Source bytes excluding `.git` and `.build` at the delivery-gate run: 1,147,498 bytes, about 1,121 KB / 1.095 MB.
  - Swift source lines under `Sources`: 17,918.
  - Dev app bundle: about 4.9 MB.
  - Daily release app bundle: about 2.1 MB.
  - `git diff --check`: PASS.

### Next Behavior

Manual Phase 7 acceptance remains next: real TCC prompts and real camera/microphone capture still require user-visible testing, but entitlement drift for both bundle identities is now guarded.

## Hai TDD: Delivery Gate Rejects Accidental App Sandbox Entitlement

### Target Behavior

DoraZoom must remain a non-sandboxed macOS utility because its ZoomIt-like behavior depends on system-level screen capture, global hotkeys and conditional Event Tap workflows. The delivery gate should fail if either development or daily app entitlements accidentally include `com.apple.security.app-sandbox`.

### RED

- **Test added**: shell assertion against `Scripts/verify-delivery.sh`.
- **Behavior asserted**: the delivery script must explicitly reject accidental App Sandbox entitlements.
- **Command**:
  - `if rg -q "app-sandbox|assert_not_contains|not sandbox" Scripts/verify-delivery.sh; then exit 1; else exit 42; fi`
- **Observed failure**: command exited `42` with `RED: delivery gate does not reject accidental app sandbox entitlement`.
- **Failure is correct because**: `Scripts/ZoomIt.entitlements` documented that the app is intentionally not sandboxed, but the delivery gate did not enforce that packaging invariant.

### GREEN

- **Minimal implementation**:
  - Added `assert_not_contains` to `Scripts/verify-delivery.sh`.
  - Asserted that both `DEV_ENTITLEMENTS` and `DAILY_ENTITLEMENTS` do not contain `com.apple.security.app-sandbox`.
- **Command**:
  - `zsh -n Scripts/verify-delivery.sh`
  - `rg -n "assert_not_contains|app-sandbox" Scripts/verify-delivery.sh`
- **Observed pass**: shell syntax passed; the delivery script now contains dev and daily sandbox rejection assertions.

### REFACTOR

- **Refactor done**: no.
- **Change**: no refactor needed; this is a focused entitlement invariant.
- **Command after refactor**:
  - `Scripts/verify-delivery.sh`
- **Observed result**:
  - Result: PASS.
  - Automated test boundary audit: PASS.
  - `swift build`: PASS.
  - `swift test`: PASS, 109 XCTest cases.
  - `ZoomItMacSelfTest`: PASS.
  - Dev and daily codesign verification passed; both entitlement payloads include camera/audio-input and omit App Sandbox.
  - Dependencies: `No external dependencies found`.
  - Dev app: `.build/DoraZoom Dev.app`, `com.duola.dorazoom.dev`, `DoraZoom (Dev)`, ad-hoc, `arm64`.
  - Daily app: `.build/DoraZoom.app`, `com.duola.dorazoom`, `DoraZoom`, Apple Development signed, `arm64`.
  - Daily zip package: `.build/DoraZoom.zip`, unzip-and-codesign verification passed, about 936 KB.
  - Source files excluding `.git` and `.build`: 119.
  - Source bytes excluding `.git` and `.build` at the delivery-gate run: 1,151,174 bytes, about 1,124 KB / 1.098 MB.
  - Swift source lines under `Sources`: 17,918.
  - Dev app bundle: about 4.9 MB.
  - Daily release app bundle: about 2.1 MB.
  - `git diff --check`: PASS.

### Next Behavior

Manual Phase 7 acceptance remains next: non-sandboxed packaging is now guarded, but real system permissions and interaction behavior still require visible user acceptance.

## Hai TDD: Delivery Gate Enforces Default Lightweight Architecture

### Target Behavior

DoraZoom's default delivery gate should keep the personal Mac build lightweight by producing one `arm64` slice unless `ZOOMIT_ARCHS` is explicitly set. The gate should fail if dev or daily bundles silently drift to an unexpected architecture set, such as an accidental Universal build.

### RED

- **Test added**: shell assertion against `Scripts/verify-delivery.sh`.
- **Behavior asserted**: the delivery script must assert expected executable architectures instead of only printing them.
- **Command**:
  - `if rg -q "EXPECTED_ARCHS|expected arch|default.*arm64|daily archs expected|assert_equal.*DAILY_ARCHS" Scripts/verify-delivery.sh; then exit 1; else exit 42; fi`
- **Observed failure**: command exited `42` with `RED: delivery gate prints architectures but does not assert default lightweight architecture`.
- **Failure is correct because**: the delivery script reported `daily archs`, but it did not fail delivery if the package gained an unintended architecture slice.

### GREEN

- **Minimal implementation**:
  - Added `EXPECTED_ARCHS="${ARCHS:-arm64}"`.
  - Computed `DEV_ARCHS` and `DAILY_ARCHS`.
  - Asserted both dev and daily executable architectures equal `EXPECTED_ARCHS`.
  - Continued to allow explicit `ZOOMIT_ARCHS` for cases where the user intentionally requests a different architecture set.
- **Command**:
  - `zsh -n Scripts/verify-delivery.sh`
  - `rg -n "EXPECTED_ARCHS|DEV_ARCHS|DAILY_ARCHS|architectures" Scripts/verify-delivery.sh`
- **Observed pass**: shell syntax passed; the delivery script now contains expected-architecture assertions for both bundles.

### REFACTOR

- **Refactor done**: no.
- **Change**: no refactor needed; this is a focused lightweight-delivery gate.
- **Command after refactor**:
  - `Scripts/verify-delivery.sh`
- **Observed result**:
  - Result: PASS.
  - Automated test boundary audit: PASS.
  - `swift build`: PASS.
  - `swift test`: PASS, 109 XCTest cases.
  - `ZoomItMacSelfTest`: PASS.
  - Dev and daily executables both reported and asserted `arm64`.
  - Dependencies: `No external dependencies found`.
  - Dev app: `.build/DoraZoom Dev.app`, `com.duola.dorazoom.dev`, `DoraZoom (Dev)`, ad-hoc, `arm64`.
  - Daily app: `.build/DoraZoom.app`, `com.duola.dorazoom`, `DoraZoom`, Apple Development signed, `arm64`.
  - Daily zip package: `.build/DoraZoom.zip`, unzip-and-codesign verification passed, about 936 KB.
  - Source files excluding `.git` and `.build`: 119.
  - Source bytes excluding `.git` and `.build` at the delivery-gate run: 1,154,438 bytes, about 1,127 KB / 1.101 MB.
  - Swift source lines under `Sources`: 17,918.
  - Dev app bundle: about 4.9 MB.
  - Daily release app bundle: about 2.1 MB.
  - `git diff --check`: PASS.

### Next Behavior

Manual Phase 7 acceptance remains next; default architecture drift is now guarded, while real install, permission and user-experience proof still requires visible testing.

## Hai TDD: Delivery Zip Contains Only DoraZoom App

### Target Behavior

The delivery zip should contain a single top-level app bundle named `DoraZoom.app`. The gate must reject packages that accidentally include extra `.app` bundles or stale upstream `ZoomIt.app`, because the downloaded artifact is the user's first install surface.

### RED

- **Test added**: shell assertion against `Scripts/verify-delivery.sh`.
- **Behavior asserted**: the delivery script must assert zip top-level app contents, not only verify that `DoraZoom.app` can be codesigned after extraction.
- **Command**:
  - `if rg -q "zip top-level app count|ZIP_APP_COUNT|ZoomIt\\.app|stale.*zip|DoraZoom\\.app.*zip" Scripts/verify-delivery.sh; then exit 1; else exit 42; fi`
- **Observed failure**: command exited `42` with `RED: delivery gate verifies extracted DoraZoom.app but does not reject extra or stale apps in the zip`.
- **Failure is correct because**: the previous gate proved the extracted `DoraZoom.app` was valid, but it would not fail if the zip also contained another top-level app.

### GREEN

- **Minimal implementation**:
  - Added `ZIP_APP_COUNT` after zip extraction.
  - Asserted exactly one top-level `.app`.
  - Asserted `DoraZoom.app` exists and stale `ZoomIt.app` does not exist.
- **Command**:
  - `zsh -n Scripts/verify-delivery.sh`
  - `rg -n "ZIP_APP_COUNT|zip top-level app count|ZoomIt\\.app" Scripts/verify-delivery.sh`
- **Observed pass**: shell syntax passed; the delivery script now contains zip app-count and stale-name assertions.

### REFACTOR

- **Refactor done**: no.
- **Change**: no refactor needed; this is a focused package-content gate.
- **Command after refactor**:
  - `Scripts/verify-delivery.sh`
- **Observed result**:
  - Result: PASS.
  - Automated test boundary audit: PASS.
  - `swift build`: PASS.
  - `swift test`: PASS, 109 XCTest cases.
  - `ZoomItMacSelfTest`: PASS.
  - Zip extraction contained exactly one top-level app, `DoraZoom.app`; no `ZoomIt.app` was present; unzip-and-codesign verification passed.
  - Dependencies: `No external dependencies found`.
  - Dev app: `.build/DoraZoom Dev.app`, `com.duola.dorazoom.dev`, `DoraZoom (Dev)`, ad-hoc, `arm64`.
  - Daily app: `.build/DoraZoom.app`, `com.duola.dorazoom`, `DoraZoom`, Apple Development signed, `arm64`.
  - Daily zip package: `.build/DoraZoom.zip`, about 936 KB.
  - Source files excluding `.git` and `.build`: 119.
  - Source bytes excluding `.git` and `.build` at the delivery-gate run: 1,157,832 bytes, about 1,131 KB / 1.104 MB.
  - Swift source lines under `Sources`: 17,918.
  - Dev app bundle: about 4.9 MB.
  - Daily release app bundle: about 2.1 MB.
  - `git diff --check`: PASS.

### Next Behavior

Manual Phase 7 acceptance remains next; package contents are now guarded, while real install and first-launch behavior still require visible user acceptance.

## Hai TDD: Delivery Zip Omits AppleDouble Metadata

### Target Behavior

The delivery zip should be clean and lightweight for a direct download/install surface: it must not contain AppleDouble `._*` resource-fork files or a `__MACOSX` metadata directory. The app bundle must still unzip and pass codesign verification after resource-fork metadata is omitted.

### RED

- **Test added**: shell assertion against current `.build/DoraZoom.zip`.
- **Behavior asserted**: zip entries must not match `(^|/)\\._|^__MACOSX/`.
- **Command**:
  - `if zipinfo -1 .build/DoraZoom.zip | rg '(^|/)\\._|^__MACOSX/'; then exit 42; else exit 1; fi`
- **Observed failure**: command exited `42` after listing AppleDouble entries such as `DoraZoom.app/Contents/._Info.plist`, `DoraZoom.app/Contents/MacOS/._DoraZoom` and `DoraZoom.app/Contents/Resources/._DoraZoom.icns`.
- **Failure is correct because**: the existing package was valid, but it carried avoidable metadata sidecars that do not belong in a clean lightweight delivery artifact.

### GREEN

- **Minimal implementation**:
  - Changed zip creation to `ditto --norsrc -c -k --keepParent`.
  - Added `ZIP_ENTRIES` scan to fail if `._*` AppleDouble files or `__MACOSX` entries appear.
- **Command**:
  - `zsh -n Scripts/verify-delivery.sh`
  - `rg -n -- "--norsrc|ZIP_ENTRIES|AppleDouble|__MACOSX|\\\\\\._" Scripts/verify-delivery.sh`
- **Observed pass**: shell syntax passed; the delivery script now packages with `--norsrc` and checks zip metadata entries.

### REFACTOR

- **Refactor done**: no.
- **Change**: no refactor needed; this is a focused package-cleanliness gate.
- **Command after refactor**:
  - `Scripts/verify-delivery.sh`
- **Observed result**:
  - Result: PASS.
  - Automated test boundary audit: PASS.
  - `swift build`: PASS.
  - `swift test`: PASS, 109 XCTest cases.
  - `ZoomItMacSelfTest`: PASS.
  - Zip metadata scan passed; no AppleDouble `._*` or `__MACOSX` entries were accepted.
  - Zip extraction contained exactly one top-level app, `DoraZoom.app`; no `ZoomIt.app` was present; unzip-and-codesign verification passed.
  - Dependencies: `No external dependencies found`.
  - Dev app: `.build/DoraZoom Dev.app`, `com.duola.dorazoom.dev`, `DoraZoom (Dev)`, ad-hoc, `arm64`.
  - Daily app: `.build/DoraZoom.app`, `com.duola.dorazoom`, `DoraZoom`, Apple Development signed, `arm64`.
  - Daily zip package: `.build/DoraZoom.zip`, about 944 KB.
  - Source files excluding `.git` and `.build`: 119.
  - Source bytes excluding `.git` and `.build` at the delivery-gate run: 1,161,085 bytes, about 1,134 KB / 1.107 MB.
  - Swift source lines under `Sources`: 17,918.
  - Dev app bundle: about 4.9 MB.
  - Daily release app bundle: about 2.1 MB.
  - `git diff --check`: PASS.

### Next Behavior

Manual Phase 7 acceptance remains next; package cleanliness is now guarded, while real download/open/install behavior still requires visible user acceptance.

## Latest Verification Snapshot — 2026-07-28 10:03 Asia/Shanghai

- `Scripts/verify-delivery.sh`: PASS.
- Automated test boundary audit: PASS; `Tests/` contains no direct forbidden real-platform API use for TCC, Event Tap creation, ScreenCaptureKit capture, microphone/camera devices, system pasteboard mutation, login items or HID input, and no `Process`/`NSTask`/system-command escape hatch for `osascript`, `pbcopy`, `pbpaste`, `screencapture` or `/usr/bin/`.
- Acceptance record verifier self-test: PASS; `Scripts/verify-acceptance-record.sh --self-test` proves that a blank Phase 7 acceptance record fails and a filled sample passes without launching DoraZoom or touching real TCC, global input, pasteboard, screen, audio, camera, login items, target apps or user output files.
- Acceptance draft generator self-test: PASS; `Scripts/phase7-acceptance-draft.sh --self-test` proves that the helper prints a conservative local-simulation acceptance draft and does not claim real system acceptance or modify `ACCEPTANCE.md`.
- Install surface auditor self-test: PASS; `Scripts/audit-install-surface.sh --self-test` proves that correct DoraZoom fixture installs pass while old `ZoomIt.app` and stale `DoraZoom (Dev).app` fixtures fail. The Phase 7 local-simulation preflight no longer reads real `/Applications`.
- Phase 7 preflight: PASS; `Scripts/phase7-preflight.sh` ran the full delivery gate and `Scripts/verify-acceptance-record.sh ACCEPTANCE.md`, then reported local-simulation acceptance passed without installing, launching, requesting permissions or modifying real user state.
- Root app artifact allowlist audit: PASS; `.build` root-level `.app` bundles are allowlisted to exactly `.build/DoraZoom Dev.app` and `.build/DoraZoom.app`. A synthetic `.build/Unexpected.app` correctly failed the gate with exit 2 and was then moved to `.build/stale-artifacts/Unexpected.app`; an older `.build/DoraZoom (Dev).app` remains recoverable at `.build/stale-artifacts/DoraZoom (Dev).app`.
- Reset helper safety audit: PASS; unconfirmed first-run reset refuses before side effects, and daily `com.duola.dorazoom` reset requires the additional daily-app confirmation.
- `swift build`: PASS.
- `swift test`: PASS, 110 XCTest cases; all automated coverage remains simulated/pure.
- `ZoomItMacSelfTest`: PASS.
- Dependency audit: `No external dependencies found`.
- Dev app: `.build/DoraZoom Dev.app`, `com.duola.dorazoom.dev`, `DoraZoom (Dev)`, ad-hoc signed, `arm64`.
- Daily app: `.build/DoraZoom.app`, `com.duola.dorazoom`, `DoraZoom`, Apple Development signed, `arm64`.
- Build input guard: `Scripts/build-app.sh` rejects invalid `ZOOMIT_BUNDLE_ID`, path-like or non-`.app` `ZOOMIT_APP_NAME`, and XML-control characters in `ZOOMIT_DISPLAY_NAME` before building or signing.
- Bundle short names: `CFBundleName=DoraZoom (Dev)` for the dev app and `CFBundleName=DoraZoom` for the daily app.
- Bundle versions: dev and daily apps both assert `CFBundleShortVersionString=1.0` and `CFBundleVersion=1.0` under the default `ZOOMIT_VERSION`.
- Bundle executable: `CFBundleExecutable=DoraZoom` with `Contents/MacOS/DoraZoom` in both dev and daily apps; no `Contents/MacOS/ZoomIt` executable remains.
- Bundle icon: `CFBundleIconFile=DoraZoom` with `Contents/Resources/DoraZoom.icns` in both dev and daily apps; no `Contents/Resources/ZoomIt.icns` icon remains.
- Runtime icon resources: source resources, dev/daily app resources and the extracted zip app resources reject stale `ZoomIt*.png` filenames; packaged resources use `DoraZoomIcon.png` and `DoraZoomColorIcon.png`.
- Bundle menu-bar mode: `LSUIElement=true` in both dev and daily apps.
- Bundle platform/privacy metadata: `LSMinimumSystemVersion=14.0` and DoraZoom-branded camera/microphone usage descriptions in both dev and daily apps.
- Codesign entitlements: camera and audio-input entitlements present in both dev and daily apps; App Sandbox entitlement absent in both.
- Dev app codesign isolation: PASS; `codesign -dv --verbose=4` output contains `Identifier=com.duola.dorazoom.dev`, `Signature=adhoc` and `TeamIdentifier=not set`.
- Executable architectures: direct `Scripts/build-app.sh release` without `ZOOMIT_ARCHS` and the dev/daily/extracted-zip delivery gates all assert `arm64` by normalized architecture set, not raw `lipo -archs` string order; the delivery gate does not pass an empty `ZOOMIT_ARCHS` when no explicit architecture override is present, and Universal remains explicit via non-empty `ZOOMIT_ARCHS`.
- Daily app codesign identity: PASS; `codesign -dv --verbose=4` output contains `Identifier=com.duola.dorazoom`, at least one `Authority=` line and non-empty `TeamIdentifier=`.
- Daily app hardened runtime: PASS; `codesign -dv --verbose=4` output for `.build/DoraZoom.app` contains `Runtime Version=`.
- Daily zip: `.build/DoraZoom.zip`, stale `.build/ZoomIt.zip` rejected before and after packaging, top-level app count asserted as 1, `DoraZoom.app` present, stale `ZoomIt.app` absent, no stale `ZoomIt*.png` icon resources in the extracted app, no AppleDouble `._*` or `__MACOSX` entries accepted, no local `com.apple.quarantine` xattr accepted on the daily app, zip or extracted app, extracted app identity/version/menu-bar/minimum-system/architecture metadata, codesign identifier/authority/team metadata, media/no-sandbox entitlements and hardened runtime asserted, unzip-and-codesign verification passed, about 933 KB.
- Source files excluding `.git` and `.build`: 123.
- Source bytes excluding `.git`, `.build` and unrelated `website`: 1,263,706 bytes, about 1,234 KB / 1.205 MB at the time of the delivery script run.
- Swift source lines under `Sources`: 17,918.
- Dev app bundle: about 4.9 MB.
- Daily release app bundle: about 2.1 MB.
- `git diff --check`: PASS.

Not claimed: real `/Applications` install, real TCC permission prompts/settings, real global hotkeys, real `Control+V`, real system pasteboard behavior in target apps, real ScreenCaptureKit/audio/camera capture, real cursor feel, real media playback/import compatibility, or measured real p50/p95/CPU/RSS. Current acceptance is local-simulation acceptance only.

## Hai TDD: Phase 7 local-simulation acceptance rewrite

### Target Behavior

Phase 7 completion should be fully local-simulation based. Docs, feature coverage, media compatibility, preflight and acceptance records must no longer block on real Mac/manual acceptance; they must still clearly say that real system permissions, global input, pasteboard, capture devices and external players are not claimed.

### RED

- **Test added**: `Phase6FeatureCoverageMapTests`, `Phase5MediaCompatibilityMatrixTests`, Phase 6 coverage tests, and shell guard over `Scripts/phase7-preflight.sh` / `Scripts/phase7-acceptance-draft.sh`.
- **Behavior asserted**: coverage entries use `.localSimulationAccepted` and `.localSimulationAcceptance`; media compatibility uses `.localSimulationPassed`; scripts do not point at old manual next steps.
- **Command**: `swift test --filter 'Phase6FeatureCoverageMapTests|Phase5MediaCompatibilityMatrixTests|Phase6AppLifecycleSimulationTests|Phase6PanoramaSimulationTests|Phase6SettingsPermissionsSimulationTests|Phase6TimerDemoTypeSimulationTests'` and `rg 'Next manual steps|manual acceptance|人工验收|真实可见人工验收|第 2-7 节' Scripts/phase7-preflight.sh Scripts/phase7-acceptance-draft.sh`.
- **Observed failure**: Swift compile failed because `localSimulationAccepted`, `localSimulationAcceptance` and `localSimulationPassed` did not exist; the shell guard found old manual-acceptance guidance.
- **Failure is correct because**: the implementation still modeled Phase 7 as pending real Mac acceptance and the scripts still told the user to continue into external manual steps.

### GREEN

- **Minimal implementation**: replaced feature coverage status/ref with local-simulation acceptance, changed the media compatibility matrix to local-simulation passed, rewrote `ACCEPTANCE.md` as a filled local-simulation record, updated README/PRD/GOAL/ARCHITECTURE, and changed `Scripts/phase7-preflight.sh` to run delivery plus `Scripts/verify-acceptance-record.sh ACCEPTANCE.md`.
- **Command**: targeted `swift test` filter, script self-tests, `Scripts/verify-acceptance-record.sh ACCEPTANCE.md`, and full `Scripts/phase7-preflight.sh`.
- **Observed pass**: targeted 21 tests passed; full preflight passed with 110 XCTest cases, `ZoomItMacSelfTest: PASS`, delivery verification PASS, and local-simulation acceptance record complete.

### REFACTOR

- **Refactor done**: yes.
- **Change**: fixed delivery size snapshot to exclude unrelated `website/` so source statistics represent DoraZoom app/docs/scripts instead of an unrelated untracked web artifact.
- **Command after refactor**: `Scripts/phase7-preflight.sh`.
- **Observed result**: PASS; size snapshot reports 123 files, 1,263,706 bytes, daily app 2.1 MB and zip 933 KB.

### Next Behavior

Done for local-simulation acceptance. A future real-device validation, if desired, should be a separate explicit goal.

## Hai TDD: Phase 7 Section 1 acceptance draft generator

### Target Behavior

After `Scripts/phase7-preflight.sh` passes, DoraZoom should provide a conservative stdout-only helper that prints a paste-ready draft for `ACCEPTANCE.md` section 1. It may summarize non-invasive gate evidence, but it must not edit `ACCEPTANCE.md`, pre-fill final conclusions, or imply that real install, authorization, paste, recording or user-experience acceptance has passed.

### RED

- **Test added**: acceptance-draft generator presence and self-test constraint.
- **Behavior asserted**: the repository must provide an executable `Scripts/phase7-acceptance-draft.sh --self-test`.
- **Command**: `if [[ ! -x Scripts/phase7-acceptance-draft.sh ]]; then print 'error: missing Phase 7 acceptance draft generator' >&2; exit 2; fi; Scripts/phase7-acceptance-draft.sh --self-test`.
- **Observed failure**: command exited 2 and printed `error: missing Phase 7 acceptance draft generator`.
- **Failure is correct because**: Phase 7 had a preflight and a final record verifier, but no safe way to reduce the mechanical work of filling the non-invasive gate table without touching the real manual acceptance sections.

### GREEN

- **Minimal implementation**: added `Scripts/phase7-acceptance-draft.sh`; it prints a Markdown draft for section 1 only, includes current `.build` artifact/source-size hints, and states that sections 2-7 must still be filled by visible manual testing. `Scripts/verify-delivery.sh` now self-tests the helper, and `Scripts/phase7-preflight.sh` prints it as an optional next step.
- **Command**: `Scripts/phase7-acceptance-draft.sh --self-test`, `Scripts/phase7-acceptance-draft.sh`, and `rg -n 'Acceptance draft generator self-test|phase7-acceptance-draft\\.sh --self-test|phase7-acceptance-draft\\.sh' Scripts/verify-delivery.sh Scripts/phase7-preflight.sh README.md ACCEPTANCE.md`.
- **Observed pass**: self-test printed `PASS: phase 7 acceptance draft self-test`; sample output contained section-1 evidence rows and explicit text that real install/authorization/paste/recording/experience checks cannot be replaced by the draft.

### REFACTOR

- **Refactor done**: no.
- **Change**: no refactor needed; the helper remains stdout-only and does not mutate acceptance records.
- **Command after refactor**: `zsh -n Scripts/phase7-acceptance-draft.sh`, `Scripts/phase7-acceptance-draft.sh --self-test`, and `Scripts/phase7-preflight.sh --self-test`.
- **Observed result**: PASS; the helper is syntax-valid, self-tested, and referenced by the preflight without running any real install/permission/device workflow.

### Next Behavior

Manual Phase 7 acceptance remains next. After `Scripts/phase7-preflight.sh` passes,哆啦 may run `Scripts/phase7-acceptance-draft.sh` to copy the section-1 evidence into `ACCEPTANCE.md`, then continue real visible testing for sections 2-7.

## Hai TDD: Phase 7 non-invasive preflight entrypoint

### Target Behavior

DoraZoom should provide one recommended preflight command before visible manual Phase 7 acceptance. The command must compose the full delivery gate, read-only install-surface audit and acceptance-record verifier self-test, then stop at manual next-step instructions without installing, launching, requesting permissions, resetting TCC, touching pasteboard, capturing screen/audio/camera, controlling target apps or writing user output files.

### RED

- **Test added**: Phase 7 preflight entrypoint presence and self-test constraint.
- **Behavior asserted**: the repository must provide an executable `Scripts/phase7-preflight.sh --self-test`.
- **Command**: `if [[ ! -x Scripts/phase7-preflight.sh ]]; then print 'error: missing Phase 7 non-invasive preflight entrypoint' >&2; exit 2; fi; Scripts/phase7-preflight.sh --self-test`.
- **Observed failure**: command exited 2 and printed `error: missing Phase 7 non-invasive preflight entrypoint`.
- **Failure is correct because**: the non-invasive checks existed as separate scripts, but there was no single safe entrypoint for哆啦 to run before manual installation and authorization.

### GREEN

- **Minimal implementation**: added `Scripts/phase7-preflight.sh`; default mode runs `Scripts/verify-delivery.sh`, `Scripts/audit-install-surface.sh` and `Scripts/verify-acceptance-record.sh --self-test`, then prints manual next steps. `--self-test` checks the script composes those non-invasive commands and states the manual boundary.
- **Command**: `Scripts/phase7-preflight.sh --self-test`, `rg -n 'Phase 7 preflight self-test|phase7-preflight\\.sh --self-test|phase7-preflight\\.sh' Scripts/verify-delivery.sh README.md ACCEPTANCE.md`, and `Scripts/phase7-preflight.sh`.
- **Observed pass**: self-test printed `PASS: phase 7 preflight self-test`; the full preflight ran the delivery gate, read-only install surface audit and acceptance-record verifier self-test, found no conflicting explicit `/Applications` candidates, and printed the manual next-step list instead of continuing into install/launch/permission work.

### REFACTOR

- **Refactor done**: no.
- **Change**: no refactor needed; the script remains a small orchestration wrapper over existing non-invasive gates.
- **Command after refactor**: `zsh -n Scripts/phase7-preflight.sh`, `Scripts/phase7-preflight.sh --self-test`, and `Scripts/phase7-preflight.sh`.
- **Observed result**: PASS; the command completed without installing, launching, requesting TCC, touching global input, pasteboard, screen/audio/camera, target apps or user output files.

### Next Behavior

Manual Phase 7 acceptance remains next. The recommended first command is now `Scripts/phase7-preflight.sh`; after it passes,哆啦 can decide whether to copy `.build/DoraZoom.app` into `/Applications` and continue visible testing.

## Hai TDD: Phase 7 read-only install surface auditor

### Target Behavior

Before manual Phase 7 authorization, DoraZoom should have a read-only way to identify stale or conflicting installed app surfaces that can confuse macOS permission entries. The auditor must recognize the expected daily/dev DoraZoom identities, report old `ZoomIt.app` or stale `DoraZoom (Dev).app` as conflicts, and never delete, overwrite, launch, install, quit apps, reset TCC, register login items, touch pasteboard, capture screen/audio/camera or write user output files.

### RED

- **Test added**: install-surface auditor presence and self-test constraint.
- **Behavior asserted**: the repository must provide an executable `Scripts/audit-install-surface.sh --self-test`.
- **Command**: `if [[ ! -x Scripts/audit-install-surface.sh ]]; then print 'error: missing read-only manual install surface auditor' >&2; exit 2; fi; Scripts/audit-install-surface.sh --self-test`.
- **Observed failure**: command exited 2 and printed `error: missing read-only manual install surface auditor`.
- **Failure is correct because**: prior scripts protected generated `.build` artifacts and reset helpers, but nothing helped哆啦 detect an already-installed stale app before entering real permission prompts.

### GREEN

- **Minimal implementation**: added `Scripts/audit-install-surface.sh`; default mode checks only explicit `/Applications` candidates (`DoraZoom.app`, `DoraZoom Dev.app`, `DoraZoom (Dev).app`, `ZoomIt.app`, `ZoomIt Dev.app`), `--root` supports fixture/local roots, and `--self-test` creates temporary app fixtures proving expected DoraZoom passes while old/stale names fail.
- **Command**: `Scripts/audit-install-surface.sh --self-test`, `Scripts/audit-install-surface.sh` with status capture, and `rg -n 'Install surface auditor self-test|audit-install-surface\\.sh --self-test|audit-install-surface\\.sh' Scripts/verify-delivery.sh README.md ACCEPTANCE.md`.
- **Observed pass**: self-test printed `PASS: install surface auditor self-test`; the real read-only `/Applications` audit exited 0 and reported all explicit candidates missing, so no stale install surface currently blocks manual authorization; delivery gate references the self-test.

### REFACTOR

- **Refactor done**: no.
- **Change**: no refactor needed; the implementation remains a small shell helper with explicit candidates and temporary self-test fixtures.
- **Command after refactor**: `zsh -n Scripts/audit-install-surface.sh`, `Scripts/audit-install-surface.sh --self-test`, and `Scripts/verify-delivery.sh`.
- **Observed result**: PASS; the full non-invasive delivery gate now includes the install-surface auditor self-test while still avoiding real TCC, global input, pasteboard, screen, audio, camera, login items, target apps and user output files.

### Next Behavior

Manual Phase 7 acceptance remains next; run `Scripts/audit-install-surface.sh` immediately before copying or opening `/Applications/DoraZoom.app`.

## Hai TDD: Phase 7 acceptance record completeness verifier

### Target Behavior

After visible manual Phase 7 testing, DoraZoom should have a non-invasive way to reject an incomplete acceptance record. The verifier must fail if required `结果`、`记录` or `结论` cells are blank, require exactly one final conclusion checkbox, and remain read-only over Markdown instead of launching DoraZoom or touching real system capabilities.

### RED

- **Test added**: acceptance-record verifier presence and self-test constraint.
- **Behavior asserted**: the repository must provide an executable `Scripts/verify-acceptance-record.sh --self-test`.
- **Command**: `if [[ ! -x Scripts/verify-acceptance-record.sh ]]; then print 'error: missing non-invasive Phase 7 acceptance record verifier' >&2; exit 2; fi; Scripts/verify-acceptance-record.sh --self-test`.
- **Observed failure**: command exited 2 and printed `error: missing non-invasive Phase 7 acceptance record verifier`.
- **Failure is correct because**: `ACCEPTANCE.md` already says验收记录不能空白跳过, but there was no automated, non-invasive way to prove a filled record is complete.

### GREEN

- **Minimal implementation**: added `Scripts/verify-acceptance-record.sh`; it parses Markdown tables, requires non-empty `结果`、`记录` and `结论` cells, checks exactly one final conclusion checkbox, and includes `--self-test` fixtures for blank/fill behavior. `Scripts/verify-delivery.sh` runs only the verifier self-test, not the still-empty manual acceptance template.
- **Command**: `Scripts/verify-acceptance-record.sh --self-test`, `Scripts/verify-acceptance-record.sh ACCEPTANCE.md` with status capture, and `rg -n 'Acceptance record verifier self-test|verify-acceptance-record\\.sh --self-test' Scripts/verify-delivery.sh README.md ACCEPTANCE.md`.
- **Observed pass**: self-test printed `PASS: acceptance record verifier self-test`; the current blank `ACCEPTANCE.md` failed with status 2 and line-specific blank-cell errors, which is expected because Phase 7 remains unfilled; delivery gate references the self-test only.

### REFACTOR

- **Refactor done**: yes.
- **Change**: fixed self-test cleanup under `set -u`, avoided zsh `print` option parsing for checkbox fixture lines, and avoided awk built-in name collisions.
- **Command after refactor**: `Scripts/verify-acceptance-record.sh --self-test`, `zsh -n Scripts/verify-acceptance-record.sh`, and `Scripts/verify-delivery.sh`.
- **Observed result**: PASS; the full non-invasive delivery gate now includes the acceptance verifier self-test while still avoiding real TCC, global input, pasteboard, screen, audio, camera, login items, target apps and user output files.

### Next Behavior

Manual Phase 7 acceptance remains next; after哆啦 fills `ACCEPTANCE.md`, run `Scripts/verify-acceptance-record.sh ACCEPTANCE.md` as the final record-completeness check.

## Test Boundary Reaffirmed — 2026-07-27

- User decision recorded: all automated testing must go through DoraZoom's simulator/simulation boundary.
- Meaning: tests may use protocolized platform boundaries, test doubles, in-memory pasteboards/filesystems, virtual clocks, deterministic event streams and isolated test windows.
- Forbidden in automated tests: real TCC prompts/settings mutation, real global keyboard listening/posting, real ScreenCaptureKit capture, real microphone/camera access, real system pasteboard mutation, real target-app paste, login item registration, silent app launch/install, real user-output files, or shell/process escape hatches that can invoke those real effects indirectly.
- Phase 7 remains manual because those facts are inherently real-system/user-experience evidence, not simulator evidence.

## Hai TDD: Phase 7 root app artifact allowlist gate

### Target Behavior

The delivery gate should reject every root-level `.build` app bundle except the current Phase 7 acceptance targets: `.build/DoraZoom Dev.app` and `.build/DoraZoom.app`. This is stronger than listing known stale names; any unexpected root-level `.app` must fail before build/sign/package steps so manual acceptance cannot click the wrong bundle.

### RED

- **Test added**: delivery root-app allowlist constraint.
- **Behavior asserted**: `Scripts/verify-delivery.sh` must enforce a root app artifact allowlist, not only reject known stale names.
- **Command**: `if ! rg -n 'ALLOWED_ROOT_APP_NAMES|root app artifact allowlist|assert_root_app_artifacts_are_allowlisted|only accepted root-level app' Scripts/verify-delivery.sh >/dev/null; then print 'error: delivery gate does not enforce a root app artifact allowlist' >&2; exit 2; fi`.
- **Observed failure**: command exited 2 and printed `error: delivery gate does not enforce a root app artifact allowlist`.
- **Failure is correct because**: the previous gate rejected a few known stale names, but an unexpected root-level `.build/*.app` such as `.build/Unexpected.app` would not be rejected.

### GREEN

- **Minimal implementation**: replaced the known-stale-name list with `ALLOWED_ROOT_APP_NAMES=("DoraZoom Dev.app" "DoraZoom.app")`; added `is_allowed_root_app_name()` and `assert_root_app_artifacts_are_allowlisted()`; ran the allowlist before reset/build steps and again before bundle identity assertions.
- **Command**: `rg -n 'ALLOWED_ROOT_APP_NAMES|Root app artifact allowlist audit|assert_root_app_artifacts_are_allowlisted|accepted root app artifacts' Scripts/verify-delivery.sh`, `zsh -n Scripts/verify-delivery.sh`, a failure-path check that created `.build/Unexpected.app`, and `Scripts/verify-test-boundary.sh`.
- **Observed pass**: targeted checks found the allowlist and both audit calls; `.build/Unexpected.app` failed the gate with exit 2 before build/sign/package work and was moved to `.build/stale-artifacts/Unexpected.app`; shell syntax and automated-test boundary audit passed.

### REFACTOR

- **Refactor done**: no.
- **Change**: yes; known-name rejection was tightened into an allowlist scan over root-level `.build/*.app` bundles.
- **Command after refactor**: `Scripts/verify-delivery.sh`.
- **Observed result**: PASS; the full non-invasive gate verified the root-level app allowlist, rebuilt dev/daily apps, ran 110 simulated XCTest cases, packaged `.build/DoraZoom.zip`, and completed without touching real TCC, global input, real pasteboard, real screen capture, microphone or camera devices.

### Next Behavior

Manual Phase 7 acceptance remains next unless another non-invasive delivery inconsistency is found.

## Hai TDD: Phase 7 test shell escape boundary gate

### Target Behavior

`Scripts/verify-test-boundary.sh` should reject automated tests that use shell/process escape hatches to bypass the simulator boundary. Tests must not call `Process`, `NSTask`, `/usr/bin/`, `osascript`, `pbcopy`, `pbpaste` or `screencapture`; otherwise a test could avoid direct API patterns while still touching real TCC, pasteboard, screenshots or user apps.

### RED

- **Test added**: automated-test shell/process escape constraint.
- **Behavior asserted**: the test-boundary script must block process/shell escape hatches.
- **Command**: `if ! rg -n 'Process\\\\\\(|NSTask|shell command|external process|osascript|pbcopy|pbpaste|screencapture' Scripts/verify-test-boundary.sh >/dev/null; then print 'error: automated test boundary does not block shell/process escape hatches' >&2; exit 2; fi`.
- **Observed failure**: command exited 2 and printed `error: automated test boundary does not block shell/process escape hatches`.
- **Failure is correct because**: the existing boundary blocked direct real-platform API imports in `Tests/`, but did not prevent tests from launching real system commands that could mutate the same external state indirectly.

### GREEN

- **Minimal implementation**: added forbidden patterns for `Process(`, `NSTask`, `/usr/bin/`, `osascript`, `pbcopy`, `pbpaste` and `screencapture` to `Scripts/verify-test-boundary.sh`.
- **Command**: `rg -n 'Process\\\\s|NSTask|/usr/bin|osascript|pbcopy|pbpaste|screencapture|tccutil' Scripts/verify-test-boundary.sh`, `zsh -n Scripts/verify-test-boundary.sh`, `Scripts/verify-test-boundary.sh`, and `swift test`.
- **Observed pass**: targeted checks found the new forbidden patterns; the boundary audit passed; all 110 simulated XCTest cases passed.

### REFACTOR

- **Refactor done**: no.
- **Change**: no refactor needed; the new patterns are a direct extension of the existing forbidden-pattern list.
- **Command after refactor**: `Scripts/verify-delivery.sh`.
- **Observed result**: PASS; the full non-invasive gate ran the strengthened automated-test boundary audit, rebuilt dev/daily apps, ran 110 simulated XCTest cases, packaged `.build/DoraZoom.zip`, and completed without touching real TCC, global input, real pasteboard, real screen capture, microphone or camera devices.

### Next Behavior

Manual Phase 7 acceptance remains next unless another non-invasive delivery inconsistency is found.

## Hai TDD: Phase 7 build input validation gate

### Target Behavior

`Scripts/build-app.sh` should fail early when caller-provided identity inputs cannot produce a sane macOS app bundle: `ZOOMIT_BUNDLE_ID` must be a reverse-DNS identifier, `ZOOMIT_APP_NAME` must be a plain `.app` bundle filename rather than a path, and `ZOOMIT_DISPLAY_NAME` must not contain XML control characters that would corrupt the generated `Info.plist`.

### RED

- **Test added**: build-helper input validation constraint.
- **Behavior asserted**: `Scripts/build-app.sh` must explicitly validate bundle id and app bundle filename inputs.
- **Command**: `if ! rg -n 'BUNDLE_ID_PATTERN|APP_NAME_PATTERN|must be a reverse-DNS|must end with \\.app|ZOOMIT_BUNDLE_ID.*reverse|ZOOMIT_APP_NAME.*\\.app' Scripts/build-app.sh >/dev/null; then print 'error: build-app does not validate bundle id or app bundle filename inputs' >&2; exit 2; fi`.
- **Observed failure**: command exited 2 and printed `error: build-app does not validate bundle id or app bundle filename inputs`.
- **Failure is correct because**: version input was already constrained, but bundle identity and app filename overrides could still flow into the generated `.app` path and `Info.plist` without an explicit guard.

### GREEN

- **Minimal implementation**: added `BUNDLE_ID_PATTERN` reverse-DNS validation; rejected display names containing `<`, `>` or `&`; rejected app names that do not end in `.app` or contain `/` or `:`.
- **Command**: `rg -n 'BUNDLE_ID_PATTERN|reverse-DNS|ZOOMIT_APP_NAME must be a plain app bundle filename|ZOOMIT_DISPLAY_NAME must not contain XML' Scripts/build-app.sh`, `zsh -n Scripts/build-app.sh`, three failure-path checks using invalid `ZOOMIT_BUNDLE_ID`, `ZOOMIT_APP_NAME` and `ZOOMIT_DISPLAY_NAME`, and `Scripts/verify-test-boundary.sh`.
- **Observed pass**: targeted checks found the new guards; invalid bundle id, path-like app name and XML-unsafe display name each exited 2 with the intended error; shell syntax and automated-test boundary audit passed.

### REFACTOR

- **Refactor done**: no.
- **Change**: no refactor needed; the guards sit directly after their inputs are resolved and before build/sign/package side effects.
- **Command after refactor**: `Scripts/verify-delivery.sh`.
- **Observed result**: PASS; the full non-invasive gate rebuilt dev/daily apps with valid DoraZoom inputs, ran 110 simulated XCTest cases, packaged `.build/DoraZoom.zip`, and completed without touching real TCC, global input, real pasteboard, real screen capture, microphone or camera devices.

### Next Behavior

Manual Phase 7 acceptance remains next unless another non-invasive delivery inconsistency is found.

## Hai TDD: Phase 7 bundle short-name and quarantine metadata gate

### Target Behavior

The non-invasive delivery gate must reject user-visible bundle identity drift beyond display name: the dev app must keep `CFBundleName=DoraZoom (Dev)` so manual permission/install checks can distinguish it, and the daily app must keep `CFBundleName=DoraZoom`. The daily local app, generated zip and extracted app must also reject `com.apple.quarantine` before distribution so local packaging does not accidentally ship a quarantined artifact. This does not suppress the normal Gatekeeper prompt a browser may add after download; it only guards DoraZoom's locally generated package.

### RED

- **Test added**: delivery-gate coverage expectation via `rg -n "CFBundleName|com\\.apple\\.quarantine|quarantine|xattr" Scripts/verify-delivery.sh ACCEPTANCE.md VALIDATION.md GOAL.md PRD.md`.
- **Behavior asserted**: delivery evidence must explicitly cover `CFBundleName` and quarantine metadata.
- **Command**: `rg -n "CFBundleName|com\\.apple\\.quarantine|quarantine|xattr" Scripts/verify-delivery.sh ACCEPTANCE.md VALIDATION.md GOAL.md PRD.md`.
- **Observed failure**: command exited 1 with no matching delivery-gate/documentation coverage.
- **Failure is correct because**: existing gates checked bundle ID, display name, executable, icon and AppleDouble zip entries, but did not assert the short bundle name or quarantine xattr state.

### GREEN

- **Minimal implementation**: added `CFBundleName` assertions for dev/daily bundles; added `assert_no_quarantine_xattr` checks for the daily app before zipping, the generated zip and the extracted daily app; updated Phase 7 acceptance rows and GOAL evidence.
- **Command**: first full `Scripts/verify-delivery.sh`.
- **Observed pass**: failed at the new dev `CFBundleName` assertion because the built dev app correctly reports `DoraZoom (Dev)`, not `DoraZoom`.

### REFACTOR

- **Refactor done**: yes.
- **Change**: refined the dev bundle-name expectation to `DoraZoom (Dev)` while keeping the daily app at `DoraZoom`; this preserves development/daily identity separation instead of forcing a misleading identical short name.
- **Command after refactor**: `Scripts/verify-delivery.sh`.
- **Observed result**: PASS. The first rerun exposed a zsh helper bug caused by naming a local variable `path`, which shadowed command lookup inside the function; the helper was corrected to use `checked_path`, then the full gate passed cleanly with no helper errors.

### Next Behavior

Manual Phase 7 acceptance remains next unless another non-invasive delivery inconsistency is found.

## Hai TDD: Phase 7 delivery architecture override hygiene gate

### Target Behavior

When `ZOOMIT_ARCHS` is not explicitly set to a non-empty value, `Scripts/verify-delivery.sh` should not pass an empty `ZOOMIT_ARCHS` environment variable into `Scripts/build-app.sh`. The release helper owns the default arm64 policy; the delivery gate should preserve that default path and only forward a non-empty explicit override such as `ZOOMIT_ARCHS="arm64 x86_64"`. This keeps DoraZoom's lightweight release default deliberate instead of relying on the current machine's native architecture.

### RED

- **Test added**: delivery architecture override hygiene constraint.
- **Behavior asserted**: delivery gate must not contain the old inline `ZOOMIT_ARCHS="$ARCHS" \` build invocation.
- **Command**: `if rg -n 'ZOOMIT_ARCHS="\$ARCHS" \\\\' Scripts/verify-delivery.sh; then print 'error: delivery gate passes empty ZOOMIT_ARCHS instead of letting build-app use its release default' >&2; exit 2; fi`.
- **Observed failure**: command exited 2 and pointed to both dev and daily build invocations that passed `ZOOMIT_ARCHS="$ARCHS"`.
- **Failure is correct because**: with no user override, `ARCHS` is empty, and passing `ZOOMIT_ARCHS=""` makes `build-app.sh` take its “explicit empty” branch instead of the release-default `arm64` branch.

### GREEN

- **Minimal implementation**: added `BUILD_ARCH_ENV`; it contains `ZOOMIT_ARCHS="$ARCHS"` only when `ARCHS` is non-empty. The dev and daily build invocations now use `env ... "${BUILD_ARCH_ENV[@]}" ...`, so the default path forwards no architecture variable while explicit non-empty overrides remain supported.
- **Command**: precise targeted check for absence of `ZOOMIT_ARCHS="$ARCHS" \`, `rg -n 'BUILD_ARCH_ENV|ZOOMIT_ARCHS|Scripts/build-app.sh debug|Scripts/build-app.sh release|EXPECTED_ARCHS' Scripts/verify-delivery.sh`, `zsh -n Scripts/verify-delivery.sh`, and `Scripts/verify-test-boundary.sh`.
- **Observed pass**: old inline empty forwarding pattern was absent; `BUILD_ARCH_ENV` is present; script syntax and automated-test boundary checks passed.

### REFACTOR

- **Refactor done**: no.
- **Change**: no refactor needed; the implementation is a small environment-array guard local to the build invocations.
- **Command after refactor**: `Scripts/verify-delivery.sh`.
- **Observed result**: PASS; the full non-invasive gate rebuilt dev/daily apps, ran 110 simulated XCTest cases, preserved default arm64 artifacts, verified codesign identity metadata, entitlements, hardened runtime, architecture and package cleanliness, and completed without touching real TCC, global input, real pasteboard, real screen capture, microphone or camera devices.

### Next Behavior

Manual Phase 7 acceptance remains next unless another non-invasive delivery inconsistency is found.

## Hai TDD: Phase 7 stale ZoomIt zip artifact gate

### Target Behavior

The non-invasive delivery gate should fail if `.build/ZoomIt.zip` exists before DoraZoom packaging or is produced during DoraZoom packaging. The only accepted daily package name is `.build/DoraZoom.zip`; a stale upstream-named zip next to it can make manual Phase 7 acceptance click or distribute the wrong artifact.

### RED

- **Test added**: delivery package artifact-name constraint.
- **Behavior asserted**: `Scripts/verify-delivery.sh` must explicitly reject stale `ZoomIt.zip` artifacts.
- **Command**: `if ! rg -n 'ZoomIt\\.zip|stale ZoomIt zip|stale zip artifact' Scripts/verify-delivery.sh >/dev/null; then print 'error: delivery gate does not reject stale ZoomIt zip artifacts' >&2; exit 2; fi`.
- **Observed failure**: command exited 2 and printed `error: delivery gate does not reject stale ZoomIt zip artifacts`.
- **Failure is correct because**: the gate generated and inspected `.build/DoraZoom.zip`, but it did not fail if an old `.build/ZoomIt.zip` sat beside the accepted package path.

### GREEN

- **Minimal implementation**: added `STALE_ZOOMIT_ZIP="$ROOT_DIR/.build/ZoomIt.zip"` and two explicit guards: one before packaging to reject pre-existing stale zips, and one after `ditto` to prove packaging did not produce a stale upstream-named zip.
- **Command**: `rg -n 'STALE_ZOOMIT_ZIP|stale ZoomIt\\.zip|DoraZoom.zip|ZoomIt\\.zip' Scripts/verify-delivery.sh`, `zsh -n Scripts/verify-delivery.sh`, and `Scripts/verify-test-boundary.sh`.
- **Observed pass**: targeted checks found both stale-zip guards; shell syntax passed; the automated-test boundary audit printed `PASS: automated tests stay inside the simulation boundary`.

### REFACTOR

- **Refactor done**: no.
- **Change**: no refactor needed; the check is intentionally explicit and colocated with package creation.
- **Command after refactor**: `Scripts/verify-delivery.sh`.
- **Observed result**: PASS; the full non-invasive gate rebuilt dev/daily apps, ran 110 simulated XCTest cases, verified no stale `.build/ZoomIt.zip`, packaged `.build/DoraZoom.zip`, checked extracted app identity/codesign/entitlements/hardened-runtime/package cleanliness, and completed without touching real TCC, global input, real pasteboard, real screen capture, microphone or camera devices.

### Next Behavior

Manual Phase 7 acceptance remains next unless another non-invasive delivery inconsistency is found.

## Hai TDD: Phase 7 architecture set normalization gate

### Target Behavior

The delivery gate should compare executable architectures as normalized sets, not raw `lipo -archs` strings. DoraZoom defaults to lightweight `arm64`, while explicit multi-architecture overrides such as `ZOOMIT_ARCHS="arm64 x86_64"` remain supported. The gate must not fail merely because a tool returns the same architecture set in a different order.

### RED

- **Test added**: delivery architecture set-normalization constraint.
- **Behavior asserted**: `Scripts/verify-delivery.sh` must contain an architecture normalization helper and use normalized comparisons for dev, daily and extracted daily apps.
- **Command**: `if ! rg -n 'normalize_archs|EXPECTED_ARCHS_NORMALIZED|normalized dev architectures|normalized daily architectures|normalized extracted daily architectures' Scripts/verify-delivery.sh >/dev/null; then print 'error: delivery gate compares architecture strings without normalization' >&2; exit 2; fi`.
- **Observed failure**: command exited 2 before the patch because the delivery gate only compared raw architecture strings.
- **Failure is correct because**: raw string comparison is enough for default `arm64`, but it is not robust for explicit multi-architecture builds where order is not the product contract. The contract is the architecture set.

### GREEN

- **Minimal implementation**: added `normalize_archs()` to split, sort and rejoin architecture names; added `EXPECTED_ARCHS_NORMALIZED`; updated extracted daily, dev and daily architecture assertions to compare normalized sets.
- **Command**: `rg -n 'normalize_archs|EXPECTED_ARCHS_NORMALIZED|normalized .*architectures|assert_equal.*DEV_ARCHS|assert_equal.*DAILY_ARCHS|extracted daily architectures' Scripts/verify-delivery.sh`, `zsh -n Scripts/verify-delivery.sh`, and `Scripts/verify-test-boundary.sh`.
- **Observed pass**: targeted checks found the normalization helper and all three normalized architecture assertions; script syntax and automated-test boundary checks passed.

### REFACTOR

- **Refactor done**: no.
- **Change**: no refactor needed; the helper is small, local and used at each delivery architecture assertion.
- **Command after refactor**: `Scripts/verify-delivery.sh`.
- **Observed result**: PASS; the full non-invasive gate rebuilt dev/daily apps, ran 110 simulated XCTest cases, verified default `arm64` artifacts through normalized architecture-set comparison, checked identity/codesign/entitlements/hardened-runtime/package cleanliness, and completed without touching real TCC, global input, real pasteboard, real screen capture, microphone or camera devices.

### Next Behavior

Manual Phase 7 acceptance remains next unless another non-invasive delivery inconsistency is found.

## Hai TDD: Phase 7 development codesign isolation gate

### Target Behavior

The development app must remain isolated from the daily TCC identity at the code-signature level, not only in `Info.plist`. `.build/DoraZoom Dev.app` must expose `Identifier=com.duola.dorazoom.dev`, `Signature=adhoc` and `TeamIdentifier=not set` in `codesign -dv --verbose=4` output. This proof is non-invasive signature metadata inspection only; it does not launch the app, request TCC, touch global input, real pasteboard, screen capture, microphone or camera.

### RED

- **Test added**: development codesign isolation constraint.
- **Behavior asserted**: delivery gate must explicitly assert dev codesign identifier, ad-hoc signature and unset team identifier.
- **Command**: `if ! rg -n 'dev codesign identifier|dev codesign ad-hoc signature|dev codesign team identifier' Scripts/verify-delivery.sh >/dev/null; then print 'error: delivery gate does not assert dev codesign identity isolation' >&2; exit 2; fi`.
- **Observed failure**: command exited 2 and printed `error: delivery gate does not assert dev codesign identity isolation`.
- **Failure is correct because**: current dev app metadata already had the desired values, but the delivery gate did not fail if future packaging drift signed the dev build as the daily identity or attached a team identifier.

### GREEN

- **Minimal implementation**: captured `DEV_CODESIGN_DETAILS` and asserted `Identifier=com.duola.dorazoom.dev`, `Signature=adhoc` and `TeamIdentifier=not set`.
- **Command**: `rg -n 'DEV_CODESIGN_DETAILS|dev codesign identifier|dev codesign ad-hoc signature|dev codesign team identifier' Scripts/verify-delivery.sh`, `zsh -n Scripts/verify-delivery.sh`, `Scripts/verify-test-boundary.sh`, and `codesign -dv --verbose=4 '.build/DoraZoom Dev.app' 2>&1 | rg 'Identifier=|Signature=|TeamIdentifier='`.
- **Observed pass**: targeted checks found all new assertions; syntax and test-boundary checks passed; current dev app reports `Identifier=com.duola.dorazoom.dev`, `Signature=adhoc` and `TeamIdentifier=not set`.

### REFACTOR

- **Refactor done**: no.
- **Change**: no refactor needed; the assertions sit next to the existing codesign audit.
- **Command after refactor**: `Scripts/verify-delivery.sh`.
- **Observed result**: PASS; the full non-invasive gate rebuilt dev/daily apps, ran 110 simulated XCTest cases, verified dev code-signature isolation, daily/extracted daily codesign identity metadata, entitlements, hardened runtime, architecture and package cleanliness, and completed without touching real TCC, global input, real pasteboard, real screen capture, microphone or camera devices.

### Next Behavior

Manual Phase 7 acceptance remains next unless another non-invasive delivery inconsistency is found.

## Hai TDD: Phase 7 daily codesign identity metadata gate

### Target Behavior

The daily install surfaces must not merely pass `codesign --verify`; their signature metadata must identify DoraZoom's daily bundle. Both `.build/DoraZoom.app` and the `DoraZoom.app` extracted from `.build/DoraZoom.zip` must expose `Identifier=com.duola.dorazoom`, at least one non-empty `Authority=` line and a non-empty `TeamIdentifier=` in `codesign -dv --verbose=4` output. This is non-invasive signature metadata proof only; it does not launch the app, request TCC, touch global input, real pasteboard, screen capture, microphone or camera.

### RED

- **Test added**: daily/extracted codesign identity detail constraint.
- **Behavior asserted**: delivery gate must explicitly assert daily and extracted daily codesign identifier, authority and team identifier metadata.
- **Command**: `if ! rg -n 'daily codesign identifier|daily codesign authority|daily codesign team identifier|extracted daily codesign identifier|extracted daily codesign authority|extracted daily codesign team identifier' Scripts/verify-delivery.sh >/dev/null; then print 'error: delivery gate does not assert daily/extracted codesign identity details' >&2; exit 2; fi`.
- **Observed failure**: command exited 2 and printed `error: delivery gate does not assert daily/extracted codesign identity details`.
- **Failure is correct because**: the gate printed `Identifier=`, `Authority=` and `TeamIdentifier=`, but did not fail if those signature metadata fields drifted or disappeared.

### GREEN

- **Minimal implementation**: added `assert_matches`; asserted daily and extracted daily `Identifier=com.duola.dorazoom`, non-empty `Authority=` and uppercase-alphanumeric `TeamIdentifier=` from `codesign -dv --verbose=4`.
- **Command**: `rg -n 'assert_matches|daily codesign identifier|daily codesign authority|daily codesign team identifier|extracted daily codesign identifier|extracted daily codesign authority|extracted daily codesign team identifier' Scripts/verify-delivery.sh`, `zsh -n Scripts/verify-delivery.sh`, `Scripts/verify-test-boundary.sh`, and `codesign -dv --verbose=4 .build/DoraZoom.app 2>&1 | rg 'Identifier=|Authority=|TeamIdentifier=|Runtime Version='`.
- **Observed pass**: targeted checks found all new assertions; syntax and test-boundary checks passed; current daily app reports `Identifier=com.duola.dorazoom`, Apple Development authority chain, `TeamIdentifier=26GG8J688T` and `Runtime Version=26.5.0`.

### REFACTOR

- **Refactor done**: no.
- **Change**: no refactor needed; the assertions sit next to the existing codesign and extracted-app hardened-runtime checks.
- **Command after refactor**: `Scripts/verify-delivery.sh`.
- **Observed result**: PASS; the full non-invasive gate rebuilt dev/daily apps, ran 110 simulated XCTest cases, verified daily and extracted daily codesign identity metadata, entitlements, hardened runtime, architecture and package cleanliness, and completed without touching real TCC, global input, real pasteboard, real screen capture, microphone or camera devices.

### Next Behavior

Manual Phase 7 acceptance remains next unless another non-invasive delivery inconsistency is found.

## Hai TDD: Phase 7 runtime icon resource identity gate

### Target Behavior

DoraZoom's runtime icon resources should use DoraZoom filenames in source, packaged dev/daily apps and the app extracted from `.build/DoraZoom.zip`. The final install surface must not carry stale `ZoomIt*.png` icon resource names through SwiftPM resource-cache residue. This proof is non-invasive: it inspects source/build artifacts only and does not launch the app, request permissions, read the real pasteboard or touch capture devices.

### RED

- **Test added**: resource-name delivery constraint.
- **Behavior asserted**: source runtime icon resources must not use upstream `ZoomIt*.png` filenames.
- **Command**: `if find Sources/ZoomItMacCore/Resources -maxdepth 1 -type f -name 'ZoomIt*.png' | rg .; then print 'error: runtime icon resources still use upstream ZoomIt filenames' >&2; exit 2; fi`.
- **Observed failure**: command exited 2 and printed `Sources/ZoomItMacCore/Resources/ZoomItIcon.png` plus `Sources/ZoomItMacCore/Resources/ZoomItColorIcon.png`.
- **Failure is correct because**: the previous identity gates protected executable/icon plist names, but source and packaged runtime PNG resource names could still expose upstream naming in app resources and code-sign resource manifests.

### GREEN

- **Minimal implementation**: renamed runtime icon resources to `DoraZoomIcon.png` and `DoraZoomColorIcon.png`; updated `DoraZoomAppIcon` loading, the app icon source path in `Scripts/build-app.sh`, and the Phase 7 product-identity test; added delivery-gate assertions for dev/daily packaged resources and the extracted zip app.
- **Command**: `swift test --filter Phase7ProductIdentityTests`, `rg -n 'ZoomItAppIcon|loadZoomItIcon|ZoomItIcon|ZoomItColorIcon' Sources Tests Scripts Package.swift ZoomItInfo.plist || true`, `find Sources/ZoomItMacCore/Resources -maxdepth 1 -type f -print | sort`, `zsh -n Scripts/verify-delivery.sh`, `zsh -n Scripts/build-app.sh`, and `Scripts/verify-test-boundary.sh`.
- **Observed pass**: 5 Phase 7 product-identity tests passed; source resources list only `DoraZoomColorIcon.png` and `DoraZoomIcon.png`; script syntax and test-boundary checks passed.

### REFACTOR

- **Refactor done**: yes.
- **Change**: the first full `Scripts/verify-delivery.sh` run failed at `error: packaged icon resources must use DoraZoom filenames` because SwiftPM's generated resource bundle still contained stale cached `ZoomIt*.png` entries. `Scripts/build-app.sh` now explicitly removes those two stale filenames from the `.app/Contents/Resources` copy target after flattening resources, keeping the cleanup limited to the generated app bundle.
- **Command after refactor**: `Scripts/verify-delivery.sh`.
- **Observed result**: PASS; the full non-invasive gate rebuilt dev/daily apps, ran 110 simulated XCTest cases, verified packaged/extracted DoraZoom resource names, identity, entitlements, hardened runtime, architecture and package cleanliness, and completed without touching real TCC, global input, real pasteboard, real screen capture, microphone or camera devices.

### Next Behavior

Manual Phase 7 acceptance remains next unless another non-invasive delivery inconsistency is found.

## Hai TDD: Phase 7 lightweight release architecture default

### Target Behavior

`Scripts/build-app.sh release` should default to the same lightweight architecture policy as the delivery gate: arm64 for DoraZoom's personal Apple Silicon daily build. Universal output remains available only when explicitly requested with `ZOOMIT_ARCHS`, so compatibility weight is not added by accident.

### RED

- **Test added**: script-level delivery constraint.
- **Behavior asserted**: `Scripts/build-app.sh` must not contain a release-default `archs=(arm64 x86_64)` branch.
- **Command**: `if rg -n 'archs=\\(arm64 x86_64\\)' Scripts/build-app.sh; then print 'error: build-app release defaults to Universal instead of lightweight arm64' >&2; exit 2; fi`.
- **Observed failure**: command exited 2 and reported `Scripts/build-app.sh:74: archs=(arm64 x86_64)`.
- **Failure is correct because**: `Scripts/verify-delivery.sh` already expected default `arm64`, but direct `Scripts/build-app.sh release` still defaulted to Universal, creating a heavier artifact when the release helper was used directly.

### GREEN

- **Minimal implementation**: changed the release default in `Scripts/build-app.sh` to `archs=(arm64)` and updated the architecture comment; `ZOOMIT_ARCHS="arm64 x86_64"` remains the explicit opt-in path for Universal builds.
- **Command**: `Scripts/build-app.sh release && lipo -archs '.build/DoraZoom Dev.app/Contents/MacOS/DoraZoom'`.
- **Observed pass**: direct release helper output reported `architectures: arm64`, and `lipo -archs` returned `arm64`.

### REFACTOR

- **Refactor done**: no.
- **Change**: no refactor needed; this is a single policy correction.
- **Command after refactor**: `Scripts/verify-delivery.sh`.
- **Observed result**: PASS; the full non-invasive delivery gate rebuilt dev and daily apps, kept both executable architectures at `arm64`, verified codesign, packaged the daily zip and completed successfully.

### Next Behavior

Manual Phase 7 acceptance remains next unless another non-invasive delivery inconsistency is found.

## Hai TDD: Phase 7 manual first-run reset safety guard

### Target Behavior

`Scripts/reset-first-run.sh` may remain available as a visible manual Phase 7 helper, but it must refuse to touch running apps, TCC, UserDefaults or launch state unless the user gives explicit environment-variable confirmation. Resetting the daily app's `com.duola.dorazoom` permission record requires a second daily-app-specific confirmation. The delivery gate should prove only the refusal paths, never the destructive reset path.

### RED

- **Test added**: script-level safety constraint.
- **Behavior asserted**: reset helper and delivery gate must contain explicit reset guards.
- **Command**: `if ! rg -n 'ZOOMIT_ALLOW_TCC_RESET|ZOOMIT_ALLOW_DAILY_RESET|Manual reset helper safety audit' Scripts/reset-first-run.sh Scripts/verify-delivery.sh >/dev/null; then print 'error: manual reset helper lacks explicit reset safety guards' >&2; exit 2; fi`.
- **Observed failure**: command exited 2 and reported that the manual reset helper lacked explicit reset safety guards.
- **Failure is correct because**: the script comments said it was manual-only, but running it directly would still quit DoraZoom, reset TCC, delete defaults and possibly relaunch the app.

### GREEN

- **Minimal implementation**: added `ZOOMIT_ALLOW_TCC_RESET=I_UNDERSTAND_THIS_RESETS_LOCAL_DORAZOOM_PERMISSIONS` as a required guard before any side effect; added `ZOOMIT_ALLOW_DAILY_RESET=I_UNDERSTAND_THIS_RESETS_DAILY_DORAZOOM_PERMISSIONS` for daily `com.duola.dorazoom` resets; added a non-invasive delivery section that runs only refusal paths.
- **Command**: refusal-path check for `Scripts/reset-first-run.sh --no-launch` without confirmation, daily refusal-path check with `ZOOMIT_BUNDLE_ID=com.duola.dorazoom`, plus `zsh -n Scripts/reset-first-run.sh` and `zsh -n Scripts/verify-delivery.sh`.
- **Observed pass**: both refusal paths exited 2 before side effects and printed the required confirmation variable names; both scripts parsed successfully.

### REFACTOR

- **Refactor done**: no.
- **Change**: no refactor needed; the guard is intentionally explicit and close to the side-effect boundary.
- **Command after refactor**: `Scripts/verify-delivery.sh`.
- **Observed result**: PASS; the delivery gate now includes `Manual reset helper safety audit` before build/test/package steps, and it completed without running the destructive reset path.

### Next Behavior

Manual Phase 7 acceptance remains next unless another non-invasive delivery inconsistency is found.

## Hai TDD: Phase 7 bundle version metadata gate

### Target Behavior

The non-invasive delivery gate must assert that generated dev and daily bundles carry stable version metadata: `CFBundleShortVersionString` and `CFBundleVersion` must both equal the current `ZOOMIT_VERSION` value, defaulting to `1.0`. This protects install/update and manual acceptance identity without launching the app or touching TCC.

### RED

- **Test added**: delivery-gate metadata constraint.
- **Behavior asserted**: `Scripts/verify-delivery.sh` must explicitly assert generated bundle versions.
- **Command**: `if ! rg -n 'CFBundleShortVersionString|CFBundleVersion' Scripts/verify-delivery.sh >/dev/null; then print 'error: delivery gate does not assert generated bundle versions' >&2; exit 2; fi`.
- **Observed failure**: command exited 2 and reported `delivery gate does not assert generated bundle versions`.
- **Failure is correct because**: `Scripts/build-app.sh` writes version metadata, but the delivery gate did not verify the built app bundles actually contain the expected short version and build version.

### GREEN

- **Minimal implementation**: added `EXPECTED_VERSION="${ZOOMIT_VERSION:-1.0}"` to the delivery gate and asserted `CFBundleShortVersionString` plus `CFBundleVersion` for both dev and daily apps; updated acceptance and goal evidence.
- **Command**: `rg -n 'CFBundleShortVersionString|CFBundleVersion|EXPECTED_VERSION' Scripts/verify-delivery.sh`, `zsh -n Scripts/verify-delivery.sh`, `Scripts/verify-test-boundary.sh`, and direct `plutil` reads from `.build/DoraZoom.app`.
- **Observed pass**: the delivery gate contains all four version assertions; syntax and test-boundary checks passed; the current daily bundle reports `CFBundleShortVersionString=1.0` and `CFBundleVersion=1.0`.

### REFACTOR

- **Refactor done**: no.
- **Change**: no refactor needed; the assertions sit with the existing bundle identity audit.
- **Command after refactor**: `Scripts/verify-delivery.sh`.
- **Observed result**: PASS; the full non-invasive gate rebuilt dev/daily bundles and verified version metadata together with identity, entitlements, codesign, zip cleanliness and size snapshot.

### Next Behavior

Manual Phase 7 acceptance remains next unless another non-invasive delivery inconsistency is found.

## Hai TDD: Phase 7 extracted zip app identity gate

### Target Behavior

The delivery gate must verify the actual install surface after zip extraction, not only the pre-zip daily app. The extracted `DoraZoom.app` must retain daily bundle identity, display name, executable/icon names, version metadata, menu-bar accessory mode, minimum macOS version and expected architecture before it is accepted for manual Phase 7 installation.

### RED

- **Test added**: extracted zip identity metadata constraint.
- **Behavior asserted**: `Scripts/verify-delivery.sh` must assert identity metadata on the extracted zip app.
- **Command**: `if ! rg -n 'extracted daily bundle id|extracted daily display name|extracted daily short version|extracted daily executable name' Scripts/verify-delivery.sh >/dev/null; then print 'error: delivery gate does not assert extracted zip app identity metadata' >&2; exit 2; fi`.
- **Observed failure**: command exited 2 and reported that the delivery gate did not assert extracted zip app identity metadata.
- **Failure is correct because**: the existing zip gate verified top-level app count, stale app absence, quarantine absence and codesign, but did not re-read the extracted app's `Info.plist` or executable architecture.

### GREEN

- **Minimal implementation**: added extracted `DoraZoom.app` assertions for bundle id, `CFBundleName`, display name, executable, icon, short/build versions, `LSUIElement`, minimum macOS version and executable architecture; updated acceptance and goal evidence.
- **Command**: `rg -n 'extracted daily bundle id|extracted daily display name|extracted daily short version|extracted daily executable name|extracted daily architectures' Scripts/verify-delivery.sh`, `zsh -n Scripts/verify-delivery.sh`, `Scripts/verify-test-boundary.sh`, and `git diff --check -- Scripts/verify-delivery.sh ACCEPTANCE.md GOAL.md VALIDATION.md`.
- **Observed pass**: targeted checks found the extracted-app identity and architecture assertions; shell syntax, test-boundary and whitespace checks passed.

### REFACTOR

- **Refactor done**: no.
- **Change**: no refactor needed; the assertions are local to the zip extraction gate.
- **Command after refactor**: `Scripts/verify-delivery.sh`.
- **Observed result**: PASS; the full non-invasive gate extracted the daily zip, checked the extracted app's metadata and architecture, then verified codesign.

### Next Behavior

Manual Phase 7 acceptance remains next unless another non-invasive delivery inconsistency is found.

## Hai TDD: Phase 7 extracted zip app entitlements gate

### Target Behavior

The final install surface is the app extracted from `.build/DoraZoom.zip`. The delivery gate must assert that this extracted app still carries the media entitlements needed for real Phase 7 recording checks (`com.apple.security.device.audio-input` and `com.apple.security.device.camera`) and still does not carry `com.apple.security.app-sandbox`. This proof remains non-invasive: it reads the code signature only and does not request TCC or touch devices.

### RED

- **Test added**: extracted zip entitlements constraint.
- **Behavior asserted**: `Scripts/verify-delivery.sh` must explicitly assert entitlements on the extracted zip app.
- **Command**: `if ! rg -n 'EXTRACTED_DAILY_ENTITLEMENTS|extracted daily entitlements|extracted.*device\\.audio-input|extracted.*app-sandbox' Scripts/verify-delivery.sh >/dev/null; then print 'error: delivery gate does not assert extracted app entitlements' >&2; exit 2; fi`.
- **Observed failure**: command exited 2 and reported `delivery gate does not assert extracted app entitlements`.
- **Failure is correct because**: dev/daily pre-zip apps had entitlement checks, but the extracted app only had codesign verification plus identity/architecture assertions.

### GREEN

- **Minimal implementation**: added `EXTRACTED_DAILY_ENTITLEMENTS` extraction after zip unpacking; asserted audio-input and camera entitlements are present and App Sandbox is absent; updated acceptance and goal evidence.
- **Command**: `rg -n 'EXTRACTED_DAILY_ENTITLEMENTS|extracted daily entitlements|device\\.audio-input|device\\.camera|app-sandbox' Scripts/verify-delivery.sh`, `zsh -n Scripts/verify-delivery.sh`, `Scripts/verify-test-boundary.sh`, and `git diff --check -- Scripts/verify-delivery.sh ACCEPTANCE.md GOAL.md VALIDATION.md`.
- **Observed pass**: targeted checks found the extracted-app entitlement assertions; shell syntax, test-boundary and whitespace checks passed.

### REFACTOR

- **Refactor done**: no.
- **Change**: no refactor needed; the extracted-app entitlement assertions stay next to the extracted-app identity assertions.
- **Command after refactor**: `Scripts/verify-delivery.sh`.
- **Observed result**: PASS; the full non-invasive gate extracted the daily zip, checked the extracted app's entitlements, identity metadata and architecture, then verified codesign.

### Next Behavior

Manual Phase 7 acceptance remains next unless another non-invasive delivery inconsistency is found.

## Hai TDD: Phase 7 daily hardened runtime gate

### Target Behavior

The daily install surfaces must be signed with hardened runtime: both `.build/DoraZoom.app` and the `DoraZoom.app` extracted from `.build/DoraZoom.zip` must expose `Runtime Version=` in `codesign -dv --verbose=4` output. This is a non-invasive signature metadata check that supports later real microphone/camera and distribution acceptance without launching the app or requesting TCC.

### RED

- **Test added**: daily hardened runtime delivery constraint.
- **Behavior asserted**: `Scripts/verify-delivery.sh` must explicitly assert hardened runtime on daily and extracted daily apps.
- **Command**: `if ! rg -n 'daily hardened runtime|extracted daily hardened runtime|Runtime Version' Scripts/verify-delivery.sh >/dev/null; then print 'error: delivery gate does not assert hardened runtime on daily install surfaces' >&2; exit 2; fi`.
- **Observed failure**: command exited 2 and reported `delivery gate does not assert hardened runtime on daily install surfaces`.
- **Failure is correct because**: `Scripts/build-app.sh` signs the daily app with `--options runtime`, and manual inspection showed `Runtime Version=26.5.0`, but the delivery gate did not fail if that option drifted away.

### GREEN

- **Minimal implementation**: captured daily and extracted daily `codesign -dv --verbose=4` output and asserted that each contains `Runtime Version=`; updated acceptance and goal evidence.
- **Command**: `rg -n 'DAILY_CODESIGN_DETAILS|EXTRACTED_DAILY_CODESIGN_DETAILS|daily hardened runtime|extracted daily hardened runtime|Runtime Version' Scripts/verify-delivery.sh`, `zsh -n Scripts/verify-delivery.sh`, `zsh -n Scripts/build-app.sh`, `zsh -n Scripts/reset-first-run.sh`, and `Scripts/verify-test-boundary.sh`.
- **Observed pass**: targeted checks found both hardened-runtime assertions; all shell syntax checks passed; the test-boundary audit printed `PASS: automated tests stay inside the simulation boundary`.

### REFACTOR

- **Refactor done**: no.
- **Change**: no refactor needed; this is a direct signature metadata assertion.
- **Command after refactor**: `Scripts/verify-delivery.sh`.
- **Observed result**: PASS; the full non-invasive gate rebuilt dev/daily apps, ran 109 simulated XCTest cases, verified daily and extracted daily hardened runtime metadata, checked identity/entitlements/architecture/package cleanliness and completed without touching real TCC, global input, real pasteboard, real screen capture, microphone or camera devices.

### Next Behavior

Manual Phase 7 acceptance remains next unless another non-invasive delivery inconsistency is found.
