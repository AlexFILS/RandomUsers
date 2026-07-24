//
//  Gender.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import Foundation

enum Gender: String, Decodable {
    case male
    case female

    /// The raw value is the API's own English wire format, so it can't be shown as-is on a
    /// screen that translates - it needs a string of ours to key off.
    var displayName: String {
        switch self {
        case .male:
            return String(localized: .genderMale)
        case .female:
            return String(localized: .genderFemale)
        }
    }
}
