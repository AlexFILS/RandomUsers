//
//  Location.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import Foundation

struct Location: Decodable, Equatable {
    let street: Street
    let city: String
    let state: String
    let country: String
    let postcode: String
    let coordinates: Coordinates
    let timezone: TimeZoneInfo

    private enum CodingKeys: String, CodingKey {
        case street, city, state, country, postcode, coordinates, timezone
    }

    init(
        street: Street,
        city: String,
        state: String,
        country: String,
        postcode: String,
        coordinates: Coordinates,
        timezone: TimeZoneInfo
    ) {
        self.street = street
        self.city = city
        self.state = state
        self.country = country
        self.postcode = postcode
        self.coordinates = coordinates
        self.timezone = timezone
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        street = try container.decode(Street.self, forKey: .street)
        city = try container.decode(String.self, forKey: .city)
        state = try container.decode(String.self, forKey: .state)
        country = try container.decode(String.self, forKey: .country)
        coordinates = try container.decode(Coordinates.self, forKey: .coordinates)
        timezone = try container.decode(TimeZoneInfo.self, forKey: .timezone)
        postcode = try Self.decodePostcode(from: container)
    }

    // The API returns `postcode` as a number for some countries (e.g. Ireland)
    // and as a string for others (e.g. the UK), so both forms must be accepted.
    private static func decodePostcode(from container: KeyedDecodingContainer<CodingKeys>) throws -> String {
        if let stringValue = try? container.decode(String.self, forKey: .postcode) {
            return stringValue
        }
        return String(try container.decode(Int.self, forKey: .postcode))
    }
}
