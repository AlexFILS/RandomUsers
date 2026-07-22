//
//  AppError.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 22/07/2026.
//

enum AppError: Error {
    case noMathcingUsers
}

extension AppError: DescribableErrorProtocol {
    var description: String {
        switch self {
        case .noMathcingUsers:
            "There are no users mathing your search criteria."
        }
    }
}
