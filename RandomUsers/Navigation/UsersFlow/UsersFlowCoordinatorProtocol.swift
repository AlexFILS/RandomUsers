//
//  UsersFlowCoordinatorProtocol.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 24/07/2026.
//

/// Navigation the Users screen can request. Declared here, next to the feature that needs it,
/// so `UsersView` depends only on this narrow interface rather than the concrete coordinator -
/// the coordinator conforms to it, not the other way around.
@MainActor
protocol UsersFlowCoordinatorProtocol: AnyObject {
    func showUserDetails(for user: UserModel)
}
