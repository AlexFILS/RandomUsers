//
//  UsersResponse.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import Foundation

struct UsersResponse: Decodable, Equatable {
    let results: [User]
    let info: ResponseInfo
}
