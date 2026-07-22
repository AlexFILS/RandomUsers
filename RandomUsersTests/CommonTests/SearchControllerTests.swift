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

    private struct FakeItem: SearchableModelProtocol, Equatable {
        let name: Name
        let email: String
    }

    private struct StubSearchService: SearchableCollectionProtocol {
        struct StubError: Error {}

        var errorToThrow: Error?

        func search<T: SearchableModelProtocol>(query: String, in elements: [T]) async throws -> [T] {
            if let errorToThrow {
                throw errorToThrow
            }
            return elements.filter { $0.email.contains(query) }
        }
    }

    private static func makeItem(email: String) -> FakeItem {
        FakeItem(name: Name(title: "Mx", first: "Test", last: "User"), email: email)
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
