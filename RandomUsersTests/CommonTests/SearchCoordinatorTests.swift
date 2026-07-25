//
//  SearchCoordinatorTests.swift
//  RandomUsersTests
//
//  Created by Alexandru Mihai on 25/07/2026.
//

import Testing
@testable import RandomUsers

@MainActor
struct SearchCoordinatorTests {

    private struct Term: SearchableModelProtocol, Equatable {
        let value: String

        var searchableTerms: [String] { [value] }
    }

    /// Stands in for whatever owns the collection being searched - a paginated loader, say -
    /// so a test can grow it mid-debounce the way a landing page would.
    private final class Collection {
        var items = [Term(value: "alpha")]
    }

    private static func makeCoordinator(
        searchService: SearchableCollectionProtocol = SearchService(),
        debounceDuration: Duration = .zero,
        minimumQueryLength: Int = 3
    ) -> SearchCoordinator<Term> {
        SearchCoordinator(
            searchService: searchService,
            configuration: SearchConfiguration(
                debounceDuration: debounceDuration,
                minimumQueryLength: minimumQueryLength
            )
        )
    }

    @Test
    func aQueryShorterThanTheMinimumIsNotWorthMatching() {
        let coordinator = Self.makeCoordinator()

        coordinator.text = "ab"
        #expect(!coordinator.hasMatchableQuery)

        coordinator.text = "abc"
        #expect(coordinator.hasMatchableQuery)
    }

    @Test
    func matchingReadsTheCollectionAfterTheDebounceRatherThanBeforeIt() async throws {
        let coordinator = Self.makeCoordinator(debounceDuration: .milliseconds(50))
        let collection = Collection()

        coordinator.text = "beta"
        // A page landing during the wait has to be searched too, or a match the user can
        // plainly see on screen comes back as "no results" until the next keystroke.
        let search = Task { try await coordinator.run(over: { collection.items }) }
        collection.items.append(Term(value: "beta"))
        try await search.value

        #expect(coordinator.results == [Term(value: "beta")])
    }

    @Test
    func cancellingReportsWhetherResultsWereActuallyOnScreen() async throws {
        let coordinator = Self.makeCoordinator()
        coordinator.activate()

        // Nothing has been matched yet, so there is nothing for a caller to pick back up.
        #expect(!coordinator.cancel())

        coordinator.activate()
        coordinator.text = "alpha"
        try await coordinator.run(over: { [Term(value: "alpha")] })
        #expect(coordinator.results != nil)

        #expect(coordinator.cancel())
        #expect(!coordinator.isActive)
        #expect(coordinator.text.isEmpty)
        #expect(coordinator.results == nil)
    }
}
