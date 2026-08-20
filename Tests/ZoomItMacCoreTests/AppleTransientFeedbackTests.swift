import AppKit
import XCTest
@testable import ZoomItMacCore

final class AppleTransientFeedbackTests: XCTestCase {
    func testModeToolCompletionWarningAndErrorUseIndependentTransientPlans() {
        let environment = FeedbackPresentationEnvironment.default
        let plans = [
            FeedbackPresentationAdapter.plan(for: .modeEntered(.staticZoom), environment: environment),
            FeedbackPresentationAdapter.plan(
                for: .toolChanged(tool: .arrow, color: .red, width: 5, canvas: .transparent),
                environment: environment
            ),
            FeedbackPresentationAdapter.plan(for: .completed(.screenshotCopied), environment: environment),
            FeedbackPresentationAdapter.plan(for: .warning("麦克风没有声音"), environment: environment),
            FeedbackPresentationAdapter.plan(for: .error("录制无法开始"), environment: environment)
        ]

        XCTAssertEqual(plans.map(\.duration), [0.9, 1.0, 1.2, 1.6, 2.4])
        XCTAssertEqual(plans.map(\.kind), [.mode, .tool, .completion, .warning, .error])
        XCTAssertTrue(plans.allSatisfy { $0.capturePolicy == .excluded })
        XCTAssertTrue(plans.allSatisfy { $0.palette == .hidden })
        XCTAssertEqual(plans[0].text, "静态缩放")
        XCTAssertEqual(plans[1].text, "箭头 · 红色 · 5 pt　Esc 退出")
        XCTAssertEqual(plans[2].text, "已复制 · ⌘V 或 ⌃V 粘贴")
    }

    func testAccessibilityEnvironmentProducesIndependentMotionMaterialAndContrastFallbacks() {
        let plan = FeedbackPresentationAdapter.plan(
            for: .modeEntered(.liveZoom),
            environment: FeedbackPresentationEnvironment(
                reduceMotion: true,
                reduceTransparency: true,
                increaseContrast: true
            )
        )

        XCTAssertEqual(plan.motion, .immediate)
        XCTAssertEqual(plan.material, .opaque)
        XCTAssertTrue(plan.drawsHighContrastBorder)
    }

    func testZoomChangeUsesShortMonospacedPercentageFeedback() {
        let plan = FeedbackPresentationAdapter.plan(
            for: .zoomChanged(factor: 2.25),
            environment: .default
        )

        XCTAssertEqual(plan.text, "225%")
        XCTAssertEqual(plan.duration, 0.9)
        XCTAssertTrue(plan.usesMonospacedDigits)
    }

    @MainActor
    func testExpiredOldHUDLeaseCannotClearNewFeedbackOrPaletteChannel() {
        let feedback = InteractionFeedback()
        let scheduler = FeedbackDismissalSchedulerFake()
        let presenter = TransientFeedbackPresenterSpy()
        let palette = feedback.begin(
            channel: .palette,
            content: .palette(.drawing(tool: .pen, color: .blue, canvas: .transparent))
        )
        defer { palette.end() }
        let adapter = FeedbackPresentationAdapter(
            feedback: feedback,
            scheduler: scheduler,
            presenter: presenter,
            environmentProvider: { .default }
        )

        adapter.present(.modeEntered(.staticZoom))
        adapter.present(.warning("麦克风没有声音"))

        XCTAssertEqual(feedback.content(for: .hud), .hud("麦克风没有声音"))
        XCTAssertEqual(presenter.presentedPlans.map(\.text), ["静态缩放", "麦克风没有声音"])
        XCTAssertEqual(
            feedback.content(for: .palette),
            .palette(.drawing(tool: .pen, color: .blue, canvas: .transparent))
        )

        scheduler.fire(index: 0, includingCancelled: true)
        XCTAssertEqual(feedback.content(for: .hud), .hud("麦克风没有声音"))

        scheduler.fire(index: 1)
        XCTAssertNil(feedback.content(for: .hud))
        XCTAssertEqual(presenter.dismissCount, 1)
        XCTAssertEqual(
            feedback.content(for: .palette),
            .palette(.drawing(tool: .pen, color: .blue, canvas: .transparent))
        )
    }

    @MainActor
    func testTransientHUDWindowIsNonActivatingAndExplicitlyExcludedFromCapture() {
        let presenter = TransientFeedbackWindowController()
        let plan = FeedbackPresentationAdapter.plan(
            for: .completed(.screenshotCopied),
            environment: .default
        )

        presenter.present(plan)
        defer { presenter.dismiss() }

        XCTAssertTrue(presenter.isVisible)
        XCTAssertEqual(presenter.renderedPlan, plan)
        XCTAssertEqual(presenter.window?.sharingType, NSWindow.SharingType.none)
        XCTAssertTrue(presenter.window?.styleMask.contains(.nonactivatingPanel) == true)
        XCTAssertFalse(presenter.window?.canBecomeKey == true)
    }
}

@MainActor
private final class TransientFeedbackPresenterSpy: TransientFeedbackPresenting {
    private(set) var presentedPlans: [TransientFeedbackPlan] = []
    private(set) var dismissCount = 0

    func present(_ plan: TransientFeedbackPlan) {
        presentedPlans.append(plan)
    }

    func dismiss() {
        dismissCount += 1
    }
}

@MainActor
private final class FeedbackDismissalSchedulerFake: FeedbackDismissalScheduling {
    private final class Token: FeedbackDismissalToken {
        var isCancelled = false
        func cancel() { isCancelled = true }
    }

    private var entries: [(token: Token, action: @MainActor @Sendable () -> Void)] = []

    func schedule(
        after delay: TimeInterval,
        _ action: @escaping @MainActor @Sendable () -> Void
    ) -> FeedbackDismissalToken {
        let token = Token()
        entries.append((token, action))
        return token
    }

    func fire(index: Int, includingCancelled: Bool = false) {
        let entry = entries[index]
        guard includingCancelled || !entry.token.isCancelled else { return }
        entry.action()
    }
}
