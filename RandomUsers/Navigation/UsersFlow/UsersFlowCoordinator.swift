//
//  UsersFlowCoordinator.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 24/07/2026.
//

import SwiftUI

@MainActor
@Observable
final class UsersFlowCoordinator: Coordinator {
    var childCoordinators: [any Coordinator] = []
    var path = NavigationPath()

    @ObservationIgnored private let dependencies: AppDependencies
    @ObservationIgnored private lazy var usersViewModel = UsersViewModel(
        service: dependencies.service,
        searchService: dependencies.searchService,
        onSelectUser: { [weak self] user in
            self?.showUserDetails(for: user)
        }
    )

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func rootView() -> some View {
        UsersView(viewModel: usersViewModel)
    }

    func destination(for route: UsersRoute) -> some View {
        switch route {
        case .userDetails(let user):
            UserDetailsView(
                viewModel: UserDetailsViewModel(
                    user: user,
                    onBack: { [weak self] in
                        self?.pop()
                    }
                )
            )
        }
    }

    private func showUserDetails(for user: UserModel) {
        path.append(UsersRoute.userDetails(user))
    }

    private func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
}
