//
//  NetworkingClient+Service.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import Networking

protocol ServiceProtocol {
    func request<Response: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> Response
}

/// We conform the Networking client to this protocol. This is what the entire app will declare as a dependency for its networking needs.
/// Any other type of network client (eg Alamofire) will have to implement this protocol in order to replace the current Networking package.
extension NetworkingClient: ServiceProtocol { }
