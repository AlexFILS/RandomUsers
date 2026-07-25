//
//  SearchConfiguration.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 25/07/2026.
//

struct SearchConfiguration: Sendable {
    let debounceDuration: Duration
    let minimumQueryLength: Int

    static let `default` = SearchConfiguration(
        debounceDuration: .seconds(1),
        minimumQueryLength: 3
    )
}
