import Foundation

@MainActor
protocol PermissionCenterPresenting: AnyObject {
    var isVisible: Bool { get }
    func present(_ plan: PermissionCenterPlan)
    func refresh(_ plan: PermissionCenterPlan)
    func close()
}

@MainActor
final class PermissionCenterCoordinator {
    private let planProvider: () -> PermissionCenterPlan
    private let presenter: PermissionCenterPresenting
    private let actionHandler: (PermissionCenterKind, PermissionCenterAction) -> Void
    private var currentPlan: PermissionCenterPlan?

    init(
        planProvider: @escaping () -> PermissionCenterPlan,
        presenter: PermissionCenterPresenting,
        actionHandler: @escaping (PermissionCenterKind, PermissionCenterAction) -> Void
    ) {
        self.planProvider = planProvider
        self.presenter = presenter
        self.actionHandler = actionHandler
    }

    func show() {
        let plan = planProvider()
        currentPlan = plan
        presenter.present(plan)
    }

    func applicationBecameActive() {
        guard presenter.isVisible else { return }
        let plan = planProvider()
        currentPlan = plan
        presenter.refresh(plan)
    }

    func performAction(for kind: PermissionCenterKind) {
        guard let row = currentPlan?.row(for: kind), row.action != .none else { return }
        actionHandler(kind, row.action)
    }

    func close() {
        presenter.close()
    }
}
