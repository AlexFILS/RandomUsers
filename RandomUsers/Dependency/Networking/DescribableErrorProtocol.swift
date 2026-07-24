//
//  DescribableErrorProtocol.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import Foundation
import enum Networking.NetworkError

protocol DescribableErrorProtocol: Error {
    var description: String { get }
}

extension NetworkError: DescribableErrorProtocol {
    var description: String {
        switch self {
        case .invalidURL:
            return String(localized: .invalidURL)
        case .requestFailed:
            return String(localized: .requestFailed)
        case .invalidResponse:
            return String(localized: .invalidResponse)
        case .unacceptableStatusCode:
            return String(localized: .unacceptableStatusCode)
        case .decodingFailed:
            return String(localized: .decodingFailed)
        }
    }
}
