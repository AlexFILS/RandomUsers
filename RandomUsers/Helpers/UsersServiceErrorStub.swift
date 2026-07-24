//
//  UsersServiceErrorStub.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import Foundation
import Networking

final class UsersServiceErrorStub: ServiceProtocol {
    func request<Response>(
        _ endpoint: Networking.Endpoint = Endpoint(path: "")
    ) async throws -> Response where Response : Decodable, Response : Sendable {
        throw NetworkError.requestFailed(URLError(.notConnectedToInternet))
    }
}
