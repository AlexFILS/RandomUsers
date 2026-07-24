//
//  Constants.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

enum Constants {
    // MARK: - Networking
    
    struct Networking {
        static let baseURL = "https://randomuser.me/"
        static let usersEndpoint = "api"
        
        private init() {}
    }
    
    // MARK: - Errors
    
    enum ErrorDescription: String {
        case defaultError = "Something went wrong."
        case noMatchingUsers = "There are no users matching your search criteria."
    }
}
