//
//  UsersViewModel.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import Networking
import Observation

@MainActor
@Observable
final class UsersViewModel: BaseViewModel {
    private(set) var users: [User]
    @ObservationIgnored private let service: ServiceProtocol
    
    init(
        users: [User] = [],
        service: ServiceProtocol = NetworkingClient(baseURL: Constants.Networking.baseURL)
    ) {
        self.users = users
        self.service = service
    }
    
    func fetchUsersIfNeeded() async {
        guard users.isEmpty else { return }
        await perform {
            let response: UsersResponse = try await service.request(
                Endpoint(path: Constants.Networking.usersEndpoint)
            )
            users = response.results
        }
    }
}
