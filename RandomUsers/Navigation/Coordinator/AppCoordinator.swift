//
//  AppCoordinator.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 24/07/2026.
//

import Observation

/// Root of the coordinator hierarchy. Owns the app's dependency composition and every top-level
/// flow. There is a single flow currently (Users), so it's the only child - adding a second flow
/// (a new tab, a modally-presented onboarding flow, ...) means adding another
/// `Coordinator`-conforming child here
@MainActor
@Observable
final class AppCoordinator: Coordinator {
    var childCoordinators: [any Coordinator] = []

    let usersFlowCoordinator: UsersFlowCoordinator

    init(dependencies: AppDependencies) {
        usersFlowCoordinator = UsersFlowCoordinator(dependencies: dependencies)
        childCoordinators = [usersFlowCoordinator]
    }
}
