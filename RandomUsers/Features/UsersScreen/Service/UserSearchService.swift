//
//  UserSearchService.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 22/07/2026.
//

import Foundation

/// Pure matching logic only - no debounce/timing. Debounce is the caller's responsibility
/// (see `UsersViewModel.search()`). Stateless, so a value type: nothing here needs a
/// reference identity, and it keeps the type trivially `Sendable`.
struct UserSearchService: SearchableCollectionProtocol {
    @concurrent
    func search<T>(query: String, in elements: [T]) async throws -> [T] where T : SearchableModelProtocol {
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
