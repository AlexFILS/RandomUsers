//
//  StubPageFetcher.swift
//  RandomUsersTests
//
//  Created by Alexandru Mihai on 25/07/2026.
//

@testable import RandomUsers

/// Pages of plain `Int`s, so `PaginatedCollectionLoader` can be exercised without dragging a
/// model, a decoder and a network stub into tests that are only about paging behaviour.
final class StubPageFetcher: PaginationFetcherProtocol, @unchecked Sendable {
    struct StubError: Error, Equatable {}

    var itemsPerPage = 1
    var errorToThrow: Error?
    var gate: Gate?
    /// Models a request that has already failed for real by the time cancellation arrives, so
    /// `errorToThrow` escapes instead of being swallowed as a `CancellationError`.
    var ignoresCancellation = false
    private(set) var fetchCount = 0
    private(set) var requestedPages: [Int] = []

    func fetchPage(_ page: Int) async throws -> [Int] {
        fetchCount += 1
        requestedPages.append(page)
        if let gate {
            await gate.wait()
            if !ignoresCancellation {
                try Task.checkCancellation()
            }
        }
        if let errorToThrow {
            throw errorToThrow
        }
        // Page 0 yields 0..<n, page 1 yields n..<2n, so appended pages are distinguishable.
        return Array((page * itemsPerPage)..<((page + 1) * itemsPerPage))
    }
}

struct StubPaginationConfiguration: PaginationConfigurationProtocol {
    var maxPage = 2
    var prefetchOffsetFromEnd = 0
}
