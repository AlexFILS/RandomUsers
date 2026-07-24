//
//  Coordinator.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

/// A concrete coordinator additionally conforms to the screen-specific `*FlowCoordinatorProtocol`
/// protocols declared by the features it drives (see `UsersFlowCoordinatorProtocol`,
/// `UserDetailsFlowCoordinatorProtocol`) - this type only tracks parent/child ownership, so an
/// `AppCoordinator` can hold and later replace whichever flows are active without knowing
/// their concrete types.
@MainActor
protocol Coordinator: AnyObject {
    var childCoordinators: [any Coordinator] { get set }
}
