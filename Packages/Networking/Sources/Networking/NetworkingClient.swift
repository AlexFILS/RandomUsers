//
//  NetworkingClient.swift
//  Networking
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import Foundation

public final class NetworkingClient: Sendable {
    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder
    
    public init(
        baseURL: String,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
    }
    
    //MARK: - Request
    
    public func request<Response: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> Response {
        let urlRequest = try makeURLRequest(for: endpoint)
        let data = try await execute(urlRequest)
        return try decode(data)
    }
    
    private func makeURLRequest(for endpoint: Endpoint) throws -> URLRequest {
        guard let baseURL = URL(string: baseURL) else {
            throw NetworkError.invalidURL
        }
        let endpointURL = baseURL.appending(path: endpoint.path)
        
        guard var components = URLComponents(
            url: endpointURL,
            resolvingAgainstBaseURL: false
        ) else {
            throw NetworkError.invalidURL
        }

        if !endpoint.queryItems.isEmpty {
            components.queryItems = endpoint.queryItems
        }

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        
        return request
    }
    
    //MARK: - Execution
    
    private func execute(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as URLError {
            throw NetworkError.requestFailed(error)
        }
        try validate(response)
        return data
    }
    
    //MARK: - Response code validation
    
    private func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw NetworkError.unacceptableStatusCode(httpResponse.statusCode)
        }
    }
    
    //MARK: - Response decoding
    
    private func decode<Response: Decodable & Sendable>(_ data: Data) throws -> Response {
        do {
            return try decoder.decode(
                Response.self,
                from: data
            )
        } catch let error as DecodingError {
            throw NetworkError.decodingFailed(error)
        }
    }
}
