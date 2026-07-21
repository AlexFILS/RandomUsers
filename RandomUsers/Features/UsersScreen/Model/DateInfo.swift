//
//  DateInfo.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import Foundation

/// Shared shape for `dob` and `registered`, both of which pair an ISO 8601
/// timestamp with a precomputed age in years.
struct DateInfo: Decodable, Equatable {
    let date: Date
    let age: Int

    private enum CodingKeys: String, CodingKey {
        case date, age
    }

    init(date: Date, age: Int) {
        self.date = date
        self.age = age
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dateString = try container.decode(String.self, forKey: .date)
        guard let date = Self.dateFormatter.date(from: dateString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .date,
                in: container,
                debugDescription: "Expected an ISO 8601 date string, got \(dateString)"
            )
        }
        self.date = date
        self.age = try container.decode(Int.self, forKey: .age)
    }

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
