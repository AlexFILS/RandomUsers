//
//  UserIdentification.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import Foundation

/// Some countries have no national identification scheme, in which case the
/// API returns a `null` value alongside the identification's name.
struct UserIdentification: Decodable, Hashable {
    let name: String
    let value: String?
}
