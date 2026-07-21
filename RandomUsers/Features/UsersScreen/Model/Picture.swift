//
//  Picture.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import Foundation

struct Picture: Decodable, Equatable {
    let large: String
    let medium: String
    let thumbnail: String
}
