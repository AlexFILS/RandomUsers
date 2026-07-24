//
//  Paginator.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 22/07/2026.
//

import Observation

@MainActor
@Observable
final class Paginator<Fetcher: PagnationFetcherProtocol> {
    private(set) var isFetchingNextPage = false

    @ObservationIgnored private let fetcher: Fetcher
    @ObservationIgnored private let maxPage: Int
    @ObservationIgnored private let prefetchOffsetFromEnd: Int
    @ObservationIgnored private var currentPage = 0
    @ObservationIgnored private var task: Task<Void, Never>?

    private var hasMorePages: Bool {
        currentPage < maxPage
    }

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

    func prefetchNextPageIfNeeded(
        at index: Int,
        totalCount: Int,
        completion: @escaping (Result<[Fetcher.Item], Error>) -> Void
    ) {
        guard hasMorePages, task == nil else { return }
        let prefetchThreshold = totalCount - 1 - prefetchOffsetFromEnd
        guard index == prefetchThreshold else { return }

        let pageToLoad = currentPage + 1
        task = Task { [weak self] in
            guard let self else { return }
            await self.fetchPage(pageToLoad, completion: completion)
            self.task = nil
        }
    }
}

private extension Paginator {
    func fetchPage(
        _ page: Int,
        completion: (Result<[Fetcher.Item], Error>) -> Void
    ) async {
        guard !Task.isCancelled else { return }
        isFetchingNextPage = true
        defer { isFetchingNextPage = false }
        do {
            let items = try await fetcher.fetchPage(page)
            guard !Task.isCancelled else { return }
            currentPage = page
            completion(.success(items))
        } catch is CancellationError {
            // Superseded by a newer request (e.g. a search started); nothing to report.
        } catch {
            completion(.failure(error))
        }
    }
}
