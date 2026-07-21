//
//  DescribableErrorProtocol.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import enum Networking.NetworkError

protocol DescribableErrorProtocol: Error {
    var description: String { get }
}

extension NetworkError: DescribableErrorProtocol {
    var description: String {
        switch self {
        case .invalidURL:
            return "The URL format is invalid"
        case .requestFailed:
            return "The request has failed"
        case .invalidResponse:
            return "The response is not an HTTP response"
        case .unacceptableStatusCode:
            return "The response status code is unacceptable"
        case .decodingFailed:
            return "The response body could not be decoded"
        }
    }
}
