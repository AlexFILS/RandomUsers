//
//  Constants.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import Foundation

enum Constants {
    // MARK: - Networking
    
    struct Networking {
        static let baseURL = "https://randomuser.me/"
        static let usersEndpoint = "api"
        
        private init() {}
    }
    
    // MARK: - Errors
    
    enum ErrorDescription {
        static var defaultError: String {
            String(localized: "Something went wrong.")
        }
        
        static var noMatchingUsers: String {
            String(localized: "There are no users matching your search criteria.")
        }
    }
}
