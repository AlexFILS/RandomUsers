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
    /// `@Bindable`, not `@State`: the coordinator is owned by `AppCoordinator`. This view only
    /// needs a binding to its `path`, and copying it into `@State` would claim an ownership
    /// this view doesn't have.
    @Bindable var coordinator: UsersFlowCoordinator
    
    var body: some View {
        NavigationStack(path: $coordinator.path) {
            coordinator.rootView()
                .navigationDestination(for: UsersRoute.self) { route in
                    coordinator.destination(for: route)
                }
        }
    }
}

#if DEBUG
#Preview {
    UsersFlowStack(
        coordinator: UsersFlowCoordinator(
            dependencies: .develop()
        )
    )
}
#endif
