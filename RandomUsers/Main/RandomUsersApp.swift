//
//  RandomUsersApp.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import SwiftUI

@main
struct RandomUsersApp: App {
    @State private var appCoordinator = AppCoordinator(dependencies: .production())
    
    var body: some Scene {
        WindowGroup {
            UsersFlowStack(coordinator: appCoordinator.usersFlowCoordinator)
                .preferredColorScheme(.light)
        }
    }
}
