//
//  UsersServiceStub.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import Networking
import Foundation

final class UsersServiceStub: ServiceProtocol {
    func request<Response>(
        _ endpoint: Networking.Endpoint = Endpoint(path: "")
    ) async throws -> Response where Response : Decodable, Response : Sendable {
        guard let url = Bundle.main.url(forResource: "UsersResponse", withExtension: "json") else {
            fatalError("Missing UsersResponse.json in bundle")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Response.self, from: data)
    }
}
