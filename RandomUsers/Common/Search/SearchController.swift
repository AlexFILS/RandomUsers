//
//  SearchController.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 22/07/2026.
//

/// Runs a search against a collection. Reusable across any screen with a searchable
/// list; the actual matching/debounce logic is delegated to an injected
/// `SearchableCollectionProtocol` service. Cancellation is the caller's responsibility
/// (e.g. via SwiftUI's `.task(id:)`), since this type has no task of its own to own.
@MainActor
final class SearchController<Item: SearchableModelProtocol> {
    private let searchService: SearchableCollectionProtocol

    init(searchService: SearchableCollectionProtocol) {
        self.searchService = searchService
    }

    func search(query: String, in items: [Item]) async throws -> [Item] {
        try await searchService.search(query: query, in: items)
    }
}
