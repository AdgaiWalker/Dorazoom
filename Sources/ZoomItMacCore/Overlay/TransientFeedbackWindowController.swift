import AppKit

@MainActor
final class RunLoopFeedbackDismissalScheduler: FeedbackDismissalScheduling {
    private final class Token: FeedbackDismissalToken {
        private var timer: Timer?

        init(timer: Timer) {
            self.timer = timer
        }

        func cancel() {
            timer?.invalidate()
            timer = nil
        }
    }

    func schedule(
        after delay: TimeInterval,
        _ action: @escaping @MainActor @Sendable () -> Void
    ) -> FeedbackDismissalToken {
        var token: Token?
        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            MainActor.assumeIsolated {
                action()
                token?.cancel()
            }
        }
        let created = Token(timer: timer)
        token = created
        return created
    }
}

@MainActor
final class TransientFeedbackWindowController: TransientFeedbackPresenting {
    private(set) var window: NSPanel?
    private(set) var renderedPlan: TransientFeedbackPlan?

    var isVisible: Bool { window?.isVisible == true }

    func present(_ plan: TransientFeedbackPlan) {
        let panel = window ?? makeWindow()
        renderedPlan = plan
        panel.contentView = makeContent(for: plan)
        panel.layoutIfNeeded()

        let fitting = panel.contentView?.fittingSize ?? NSSize(width: 220, height: 44)
        panel.setContentSize(NSSize(
            width: min(max(fitting.width, 160), 520),
            height: min(max(fitting.height, 42), 120)
        ))
        position(panel)

        switch plan.motion {
        case .immediate:
            panel.alphaValue = 1
            panel.orderFrontRegardless()
        case .shortFade:
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        }
    }

    func dismiss() {
        window?.orderOut(nil)
        window?.alphaValue = 1
        renderedPlan = nil
    }

    private func makeWindow() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.sharingType = .none
        window = panel
        return panel
    }

    private func makeContent(for plan: TransientFeedbackPlan) -> NSView {
        let container: NSView
        switch plan.material {
        case .translucent:
            let effect = NSVisualEffectView()
            effect.material = .hudWindow
            effect.blendingMode = .behindWindow
            effect.state = .active
            container = effect
        case .opaque:
            let view = NSView()
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            container = view
        }
        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        if plan.drawsHighContrastBorder {
            container.layer?.borderWidth = 1
            container.layer?.borderColor = NSColor.labelColor.cgColor
        }

        let label = NSTextField(labelWithString: plan.text)
        label.font = plan.usesMonospacedDigits
            ? .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
            : .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        label.maximumNumberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            label.widthAnchor.constraint(lessThanOrEqualToConstant: 480)
        ])
        return container
    }

    private func position(_ panel: NSPanel) {
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(pointer, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let size = panel.frame.size
        let origin = MultiDisplayTargetingPolicy.feedbackOrigin(
            nearAppKitPointer: pointer,
            contentSize: size,
            visibleFrame: visible,
            margin: 12
        )
        panel.setFrameOrigin(origin)
    }
}
