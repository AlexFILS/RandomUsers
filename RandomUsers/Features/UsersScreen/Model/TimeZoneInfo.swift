//
//  TimeZoneInfo.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import Foundation

struct TimeZoneInfo: Decodable, Equatable {
    let offset: String
    let description: String
}
