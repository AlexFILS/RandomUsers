//
//  SearchCoordinator.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 25/07/2026.
//

import Observation



@MainActor
@Observable
final class SearchCoordinator<Item: SearchableModelProtocol> {
    var text = ""
    private(set) var isActive = false
    private(set) var results: [Item]?

    var hasMatchableQuery: Bool {
        text.count >= configuration.minimumQueryLength
    }

    @ObservationIgnored private let configuration: SearchConfiguration
    @ObservationIgnored private let controller: SearchController<Item>

    init(
        searchService: SearchableCollectionProtocol,
        configuration: SearchConfiguration = .default
    ) {
        self.configuration = configuration
        self.controller = SearchController(searchService: searchService)
    }

    func activate() {
        isActive = true
    }

    @discardableResult
    func cancel() -> Bool {
        isActive = false
        text = ""
        return clearResults()
    }

    func clearText() {
        text = ""
    }

    /// - Returns: whether anything was actually cleared.
    @discardableResult
    func clearResults() -> Bool {
        guard results != nil else { return false }
        results = nil
        return true
    }

    func run(over items: () -> [Item]) async throws {
        try await Task.sleep(for: configuration.debounceDuration)
        let matches = try await controller.search(query: text, in: items())
        // `.task(id:)` cancels this on the next keystroke, but the matching itself has no
        // suspension point at which to notice - so check before publishing.
        try Task.checkCancellation()
        results = matches
    }
}
