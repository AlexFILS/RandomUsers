//
//  SearchService.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 22/07/2026.
//

import Foundation

/// Pure matching logic only - no debounce/timing. Debounce is the caller's responsibility
/// (see `UsersViewModel.search()`). Stateless, so a value type: nothing here needs a
/// reference identity, and it keeps the type trivially `Sendable`.
struct SearchService: SearchableCollectionProtocol {
    @concurrent
    func search<T>(query: String, in elements: [T]) async throws -> [T] where T: SearchableModelProtocol {
        try Task.checkCancellation()

        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return elements.filter { element in
            element.searchableTerms.contains { term in
                term.lowercased().contains(normalizedQuery)
            }
        }
    }
}
