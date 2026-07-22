//
//  NetworkError.swift
//  Networking
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import Foundation

public enum NetworkError: Error, Sendable {
    /// The endpoint could not be resolved into a valid URL.
    case invalidURL
    /// The underlying transport (`URLSession`) failed, e.g. no connectivity.
    case requestFailed(URLError)
    /// The response was not an `HTTPURLResponse`.
    case invalidResponse
    /// The response's status code was outside the 200..<300 range.
    case unacceptableStatusCode(Int)
    /// The response body could not be decoded into the requested type.
    case decodingFailed(DecodingError)
}
