//
//  UsersRoute.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

/// Destinations reachable within the Users flow's own `NavigationStack`. Scoped to this flow -
/// a second flow (e.g. Settings) gets its own `Route` type and its own coordinator rather than
/// growing this enum.
enum UsersRoute: Hashable {
    case userDetails(UserModel)
}
