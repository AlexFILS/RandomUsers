//
//  UserPageFetcher.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 22/07/2026.
//

struct UserPageFetcher: PagnationFetcherProtocol {
    let service: ServiceProtocol
    let configuration: UsersPaginationConfiguration

    func fetchPage(_ page: Int) async throws -> [UserModel] {
        let response: UsersResponse = try await service.request(
            configuration.endpoint(forPage: page)
        )
        return response.results
    }
}
