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
    
    /// Clears the in-flight state synchronously rather than waiting for the cancelled fetch to
    /// resume and run its own teardown. Callers decide whether to start a fetch by asking
    /// `shouldPrefetch(at:totalCount:)`, so "cancel, then immediately ask again" has to be
    /// answerable straight away - otherwise the replacement request is silently dropped as a
    /// duplicate of the one just abandoned.
    func cancelInFlightFetch() {
        task?.cancel()
        task = nil
        isFetchingNextPage = false
    }

    /// Returns to the first page, so a collection that has been emptied can be paged from the
    /// start again rather than resuming from wherever the previous run left off.
    func reset() {
        cancelInFlightFetch()
        currentPage = 0
    }

    func shouldPrefetch(at index: Int, totalCount: Int) -> Bool {
        guard hasMorePages, task == nil else { return false }
        return index >= totalCount - 1 - prefetchOffsetFromEnd
    }

    /// Fetches the next page once `index` has reached (or passed) the prefetch threshold.
    /// Returns `nil` when no fetch was needed (already fetching, past `maxPage`, not at the
    /// threshold yet, or the fetch was superseded by a `cancelInFlightFetch()` call)
    func prefetchNextPageIfNeeded(at index: Int, totalCount: Int) async throws -> [Fetcher.Item]? {
        guard shouldPrefetch(at: index, totalCount: totalCount) else { return nil }

        let pageToLoad = currentPage + 1
        isFetchingNextPage = true
        let fetchTask = Task<[Fetcher.Item], Error> {
            let items = try await fetcher.fetchPage(pageToLoad)
            try Task.checkCancellation()
            return items
        }
        task = fetchTask
        defer {
            if task == fetchTask {
                isFetchingNextPage = false
                task = nil
            }
        }
        
        do {
            let items = try await withTaskCancellationHandler {
                try await fetchTask.value
            } onCancel: {
                fetchTask.cancel()
            }
            try Task.checkCancellation()
            currentPage = pageToLoad
            return items
        } catch is CancellationError {
            // Superseded by a newer request (e.g. a search started); nothing to report.
            return nil
        }
    }
}
