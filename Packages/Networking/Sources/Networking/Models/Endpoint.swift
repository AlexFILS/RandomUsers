//
//  Endpoint.swift
//  Networking
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import Foundation

public struct Endpoint: Sendable {
    public let path: String
    public let method: HTTPMethod
    public let queryItems: [URLQueryItem]

    public init(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = []
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
    }
}
