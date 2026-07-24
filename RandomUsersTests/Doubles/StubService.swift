//
//  StubService.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 24/07/2026.
//

import Networking
@testable import RandomUsers

final class StubService: ServiceProtocol, @unchecked Sendable {
    struct StubError: Error, Equatable {}
    
    var response = UsersResponse(results: [], info: ResponseInfo(seed: "seed", results: 0, page: 0, version: "1.4"))
    var errorToThrow: Error?
    var gate: Gate?
    /// Models a request that has already failed for real by the time cancellation arrives, so
    /// `errorToThrow` escapes instead of being swallowed as a `CancellationError`.
    var ignoresCancellation = false
    private(set) var requestCount = 0

    @concurrent
    func request<Response: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> Response {
        requestCount += 1
        if let gate {
            await gate.wait()
            if !ignoresCancellation {
                try Task.checkCancellation()
            }
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
