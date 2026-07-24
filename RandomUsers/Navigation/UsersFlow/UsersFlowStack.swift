//
//  UsersFlowStack.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import SwiftUI

/// Hosts the Users flow's `NavigationStack`, bound to its coordinator's path. This is the only
/// place that talks to `NavigationStack`/`NavigationPath` directly - everything else drives
/// navigation through `UsersFlowCoordinator`'s methods.
struct UsersFlowStack: View {
    @State private var coordinator: UsersFlowCoordinator

    init(coordinator: UsersFlowCoordinator) {
        _coordinator = State(initialValue: coordinator)
    }

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            coordinator.rootView()
                .navigationDestination(for: UsersRoute.self) { route in
                    coordinator.destination(for: route)
                }
        }
    }
}

#Preview {
    UsersFlowStack(
        coordinator: UsersFlowCoordinator(
            dependencies: .develop()
        )
    )
}
