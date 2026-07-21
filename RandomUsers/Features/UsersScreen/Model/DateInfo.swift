//
//  DateInfo.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import Foundation

struct DateInfo: Decodable, Hashable {
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
        guard let date = try? Date(dateString, strategy: Self.dateFormatStyle) else {
            throw DecodingError.dataCorruptedError(
                forKey: .date,
                in: container,
                debugDescription: "Expected an ISO 8601 date string, got \(dateString)"
            )
        }
        self.date = date
        self.age = try container.decode(Int.self, forKey: .age)
    }

    private static let dateFormatStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
}
