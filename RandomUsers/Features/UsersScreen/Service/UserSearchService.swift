//
//  UserSearchService.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 22/07/2026.
//

import Foundation

/// Pure matching logic only - no debounce/timing. Debounce is the caller's responsibility
/// (see `UsersViewModel.search()`), since it needs to elapse before `elements` is read, not before
/// this function is invoked.
final class UserSearchService: SearchableCollectionProtocol {
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
