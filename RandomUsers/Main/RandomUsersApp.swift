//
//  RandomUsersApp.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import SwiftUI

@main
struct RandomUsersApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                UsersView()
            }
        }
    }
}
