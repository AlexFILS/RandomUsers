//
//  Paginator.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 22/07/2026.
//

import Observation

@MainActor
@Observable
final class Paginator<Fetcher: PaginationFetcherProtocol> {
    private(set) var isFetchingNextPage = false

    @ObservationIgnored private let fetcher: Fetcher
    @ObservationIgnored private let maxPage: Int
    @ObservationIgnored private let prefetchOffsetFromEnd: Int
    @ObservationIgnored private var currentPage = 0
    @ObservationIgnored private var task: Task<[Fetcher.Item], Error>?

    var hasMorePages: Bool {
        currentPage < maxPage
    }

    /// - Parameter prefetchOffsetFromEnd: rank of the element (counting back from the last
    ///   one) whose appearance should trigger the next fetch. `0` means "the last element",
    ///   `2` means "the 3rd-last element", etc.
    init(
        fetcher: Fetcher,
        maxPage: Int,
        prefetchOffsetFromEnd: Int
    ) {
        self.fetcher = fetcher
        self.maxPage = maxPage
        self.prefetchOffsetFromEnd = prefetchOffsetFromEnd
    }

    deinit {
        task?.cancel()
    }

    func cancelInFlightFetch() {
        task?.cancel()
    }

    /// Fetches the next page once `index` has reached (or passed) the prefetch threshold.
    /// Returns `nil` when no fetch was needed (already fetching, past `maxPage`, not at the
    /// threshold yet, or the fetch was superseded by a `cancelInFlightFetch()` call) - callers
    /// should treat `nil` the same as "nothing to append", not as a failure. Non-cancellation
    /// failures are rethrown for the caller to handle.
    func prefetchNextPageIfNeeded(at index: Int, totalCount: Int) async throws -> [Fetcher.Item]? {
        guard hasMorePages, task == nil else { return nil }
        let prefetchThreshold = totalCount - 1 - prefetchOffsetFromEnd

        guard index >= prefetchThreshold else { return nil }

        let pageToLoad = currentPage + 1
        isFetchingNextPage = true
        let fetchTask = Task<[Fetcher.Item], Error> {
            let items = try await fetcher.fetchPage(pageToLoad)
            try Task.checkCancellation()
            return items
        }
        task = fetchTask
        defer {
            isFetchingNextPage = false
            task = nil
        }

        do {
            let items = try await fetchTask.value
            try Task.checkCancellation()
            currentPage = pageToLoad
            return items
        } catch is CancellationError {
            // Superseded by a newer request (e.g. a search started); nothing to report.
            return nil
        }
    }
}
