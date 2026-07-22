//
//  UserSearchService.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 22/07/2026.
//

import Foundation

final class UserSearchService: SearchableCollectionProtocol {
    private let debounceDuration: Duration

    init(debounceDuration: Duration = .seconds(1)) {
        self.debounceDuration = debounceDuration
    }

    func search<T>(query: String, in elements: [T]) async throws -> [T] where T : SearchableModelProtocol {
        try await Task.sleep(for: debounceDuration)

        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return elements.filter { user in
            user.name.first.lowercased().contains(normalizedQuery) ||
            user.name.last.lowercased().contains(normalizedQuery) ||
            user.email.lowercased().contains(normalizedQuery)
        }
    }
}
