//
//  SearchControllerTests.swift
//  RandomUsersTests
//
//  Created by Alexandru Mihai on 22/07/2026.
//

import Testing
@testable import RandomUsers

@MainActor
struct SearchControllerTests {
    
    /// A model with nothing in common with `UserModel`. That it can conform at all is the point:
    /// the searching layer no longer requires the Users feature's `Name`.
    private struct FakeItem: SearchableModelProtocol, Equatable {
        let email: String

        var searchableTerms: [String] { [email] }
    }

    private struct StubSearchService: SearchableCollectionProtocol {
        struct StubError: Error {}

        var errorToThrow: Error?

        func search<T: SearchableModelProtocol>(query: String, in elements: [T]) async throws -> [T] {
            if let errorToThrow {
                throw errorToThrow
            }
            return elements.filter { element in
                element.searchableTerms.contains { $0.contains(query) }
            }
        }
    }

    private static func makeItem(email: String) -> FakeItem {
        FakeItem(email: email)
    }
    
    @Test
    func searchReportsMatchingResults() async throws {
        let controller = SearchController<FakeItem>(searchService: StubSearchService())
        let items = [Self.makeItem(email: "a@example.com"), Self.makeItem(email: "b@example.com")]
        
        let results = try await controller.search(query: "a@", in: items)
        
        #expect(results == [items[0]])
    }
    
    @Test
    func nonCancellationErrorsPropagate() async {
        let service = StubSearchService(errorToThrow: StubSearchService.StubError())
        let controller = SearchController<FakeItem>(searchService: service)
        
        await #expect(throws: StubSearchService.StubError.self) {
            try await controller.search(query: "a@", in: [Self.makeItem(email: "a@example.com")])
        }
    }
}
