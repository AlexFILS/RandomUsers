//
//  ResponseInfo.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import Foundation

struct ResponseInfo: Decodable, Equatable {
    let seed: String
    let results: Int
    let page: Int
    let version: String
}
