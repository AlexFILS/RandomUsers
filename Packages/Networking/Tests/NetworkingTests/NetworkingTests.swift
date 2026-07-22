//
//  MockURLProtocol.swift
//  NetworkingTests
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import Testing
import Foundation
@testable import Networking

@Suite(.serialized)
struct NetworkingClientTests {
    
    private struct TestUser: Decodable, Sendable, Equatable {
        let id: Int
        let name: String
    }
    
    private func makeClient(baseURL: String = "https://api.example.com") -> NetworkingClient {
        NetworkingClient(baseURL: baseURL, session: MockURLProtocol.makeSession())
    }
    
    private func httpResponse(for request: URLRequest, statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }
    
    // MARK: - Success
    
    @Test func decodesSuccessfulResponse() async throws {
        let json = Data(#"{"id": 1, "name": "Ada"}"#.utf8)
        MockURLProtocol.requestHandler = { [self] request in
            (httpResponse(for: request, statusCode: 200), json)
        }
        
        let client = makeClient()
        let user: TestUser = try await client.request(Endpoint(path: "users/1"))
        
        #expect(user == TestUser(id: 1, name: "Ada"))
    }
    
    // MARK: - Error handling
    
    @Test func throwsInvalidURLForMalformedBaseURL() async throws {
        let client = makeClient(baseURL: "")
        
        do {
            let _: TestUser = try await client.request(Endpoint(path: "users"))
            Issue.record("Expected NetworkError.invalidURL")
        } catch NetworkError.invalidURL {
            // expected
        }
    }
    
    @Test func throwsRequestFailedOnTransportError() async throws {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let client = makeClient()

        do {
            let _: TestUser = try await client.request(Endpoint(path: "users"))
            Issue.record("Expected NetworkError.requestFailed")
        } catch NetworkError.requestFailed(let urlError) {
            #expect(urlError.code == .notConnectedToInternet)
        }
    }

    @Test func throwsCancellationErrorWhenUnderlyingTaskIsCancelled() async throws {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.cancelled)
        }

        let client = makeClient()

        await #expect(throws: CancellationError.self) {
            let _: TestUser = try await client.request(Endpoint(path: "users"))
        }
    }
    
    @Test func throwsInvalidResponseWhenNotHTTPURLResponse() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = URLResponse(
                url: request.url!,
                mimeType: nil,
                expectedContentLength: 0,
                textEncodingName: nil
            )
            return (response, Data())
        }
        
        let client = makeClient()
        
        do {
            let _: TestUser = try await client.request(Endpoint(path: "users"))
            Issue.record("Expected NetworkError.invalidResponse")
        } catch NetworkError.invalidResponse {
            // expected
        }
    }
    
    @Test(arguments: [400, 404, 500])
    func throwsUnacceptableStatusCodeForNon2xx(statusCode: Int) async throws {
        MockURLProtocol.requestHandler = { [self] request in
            (httpResponse(for: request, statusCode: statusCode), Data())
        }
        
        let client = makeClient()
        
        do {
            let _: TestUser = try await client.request(Endpoint(path: "users/1"))
            Issue.record("Expected NetworkError.unacceptableStatusCode")
        } catch NetworkError.unacceptableStatusCode(let code) {
            #expect(code == statusCode)
        }
    }
    
    // MARK: - Response decoding
    
    @Test func throwsDecodingFailedForTypeMismatch() async throws {
        let malformedJSON = Data(#"{"id": "not-an-int", "name": "Ada"}"#.utf8)
        MockURLProtocol.requestHandler = { [self] request in
            (httpResponse(for: request, statusCode: 200), malformedJSON)
        }
        
        let client = makeClient()
        
        do {
            let _: TestUser = try await client.request(Endpoint(path: "users/1"))
            Issue.record("Expected NetworkError.decodingFailed")
        } catch NetworkError.decodingFailed {
            // expected
        }
    }
    
    @Test func throwsDecodingFailedForMissingField() async throws {
        let incompleteJSON = Data(#"{"id": 1}"#.utf8)
        MockURLProtocol.requestHandler = { [self] request in
            (httpResponse(for: request, statusCode: 200), incompleteJSON)
        }
        
        let client = makeClient()
        
        do {
            let _: TestUser = try await client.request(Endpoint(path: "users/1"))
            Issue.record("Expected NetworkError.decodingFailed")
        } catch NetworkError.decodingFailed {
            // expected
        }
    }
    
    @Test func throwsDecodingFailedForEmptyBody() async throws {
        MockURLProtocol.requestHandler = { [self] request in
            (httpResponse(for: request, statusCode: 200), Data())
        }
        
        let client = makeClient()
        
        do {
            let _: TestUser = try await client.request(Endpoint(path: "users/1"))
            Issue.record("Expected NetworkError.decodingFailed")
        } catch NetworkError.decodingFailed {
            // expected
        }
    }
    
    @Test func appendsQueryItemsToRequestURL() async throws {
        let json = Data(#"{"id": 1, "name": "Ada"}"#.utf8)
        nonisolated(unsafe) var capturedURL: URL?
        MockURLProtocol.requestHandler = { [self] request in
            capturedURL = request.url
            return (httpResponse(for: request, statusCode: 200), json)
        }

        let client = makeClient()
        let endpoint = Endpoint(
            path: "users",
            queryItems: [
                URLQueryItem(name: "page", value: "1"),
                URLQueryItem(name: "results", value: "20")
            ]
        )
        let _: TestUser = try await client.request(endpoint)

        let url = try #require(capturedURL)
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        #expect(components?.queryItems?.contains(URLQueryItem(name: "page", value: "1")) == true)
        #expect(components?.queryItems?.contains(URLQueryItem(name: "results", value: "20")) == true)
    }

    @Test func decodesArrayResponse() async throws {
        let json = Data(#"[{"id": 1, "name": "Ada"}, {"id": 2, "name": "Grace"}]"#.utf8)
        MockURLProtocol.requestHandler = { [self] request in
            (httpResponse(for: request, statusCode: 200), json)
        }
        
        let client = makeClient()
        let users: [TestUser] = try await client.request(Endpoint(path: "users"))
        
        #expect(users == [TestUser(id: 1, name: "Ada"), TestUser(id: 2, name: "Grace")])
    }
}
