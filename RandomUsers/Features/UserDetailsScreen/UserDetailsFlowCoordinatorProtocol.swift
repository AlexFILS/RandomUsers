//
//  UserDetailsFlowCoordinatorProtocol.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 24/07/2026.
//

/// Navigation the User Details screen can request. Declared here, next to the feature that
/// needs it, so `UserDetailsView` depends only on this narrow interface rather than the
/// concrete coordinator - the coordinator conforms to it, not the other way around.
@MainActor
protocol UserDetailsFlowCoordinatorProtocol: AnyObject {
    func pop()
}
