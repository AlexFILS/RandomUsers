//
//  CoordinatorView.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import SwiftUI

struct UsersCoordinatorStack: View {
    @State private var coordinator = Coordinator()

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            UsersView()
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                }
        }
        .environment(coordinator)
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .userDetails(let user):
            UserDetailsView(user: user)
        }
    }
}
