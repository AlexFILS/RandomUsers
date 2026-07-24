//
//  StubService.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 24/07/2026.
//

import Networking
@testable import RandomUsers

final class StubService: ServiceProtocol {
    struct StubError: Error, Equatable {}
    
    var response = UsersResponse(results: [], info: ResponseInfo(seed: "seed", results: 0, page: 0, version: "1.4"))
    var errorToThrow: Error?
    var gate: Gate?
    private(set) var requestCount = 0
    
    func request<Response: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> Response {
        requestCount += 1
        if let gate {
            await gate.wait()
            try Task.checkCancellation()
        }
        if let errorToThrow {
            throw errorToThrow
        }
        guard let typedResponse = response as? Response else {
            fatalError("StubService only supports decoding UsersResponse")
        }
        return typedResponse
    }
}
