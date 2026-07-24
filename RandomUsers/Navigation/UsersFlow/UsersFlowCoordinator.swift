//
//  UsersFlowCoordinator.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 24/07/2026.
//

import SwiftUI

/// Owns the Users flow's navigation stack and is the sole place that builds its screens.
/// Views depend on the `UsersFlowCoordinatorProtocol` and `UserDetailsFlowCoordinatorProtocol` protocols
@MainActor
@Observable
final class UsersFlowCoordinator: Coordinator {
    var childCoordinators: [any Coordinator] = []
    var path = NavigationPath()

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func rootView() -> some View {
        UsersView(
            viewModel: makeUsersViewModel(),
            coordinator: self
        )
    }

    func destination(for route: UsersRoute) -> some View {
        switch route {
        case .userDetails(let user):
            UserDetailsView(viewModel: UserDetailsViewModel(user: user), coordinator: self)
        }
    }

    private func makeUsersViewModel() -> UsersViewModel {
        UsersViewModel(
            service: dependencies.service,
            searchService: dependencies.searchService
        )
    }
}

extension UsersFlowCoordinator: UsersFlowCoordinatorProtocol {
    func showUserDetails(for user: UserModel) {
        path.append(UsersRoute.userDetails(user))
    }
}

extension UsersFlowCoordinator: UserDetailsFlowCoordinatorProtocol {
    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
}
