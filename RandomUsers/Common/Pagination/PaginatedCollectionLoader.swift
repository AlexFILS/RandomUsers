//
//  PaginatedCollectionLoader.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 25/07/2026.
//

import Observation

@MainActor
@Observable
final class PaginatedCollectionLoader<Fetcher: PaginationFetcherProtocol> {
    typealias Item = Fetcher.Item
    
    enum FailedLoad: Equatable {
        case initialPage
        case nextPage(index: Int)
    }
    
    struct Failure {
        let load: FailedLoad
        let error: Error
    }
    
    private(set) var items: [Item]
    private(set) var isLoadingInitialPage = false
    private(set) var failure: Failure?
    /// Separates "not fetched yet" from "fetched, and there genuinely is nothing", which
    /// otherwise both read as an empty `items`.
    private(set) var hasLoadedInitialPage: Bool
    
    var isFetchingNextPage: Bool { paginator.isFetchingNextPage }
    
    /// A page that was abandoned mid-flight and will not be re-asked for by a row appearing,
    /// because its triggering row has already appeared. Something in the UI has to offer it.
    var hasParkedPage: Bool { parkedPageIndex != nil }
    
    private var parkedPageIndex: Int?
    
    @ObservationIgnored private let fetcher: Fetcher
    @ObservationIgnored private let paginator: Paginator<Fetcher>
    @ObservationIgnored private var prefetchTask: Task<Void, Never>?
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var furthestRequestedIndex = -1
    
    init(
        fetcher: Fetcher,
        configuration: some PaginationConfigurationProtocol,
        items: [Item] = []
    ) {
        self.fetcher = fetcher
        self.items = items
        self.hasLoadedInitialPage = !items.isEmpty
        self.paginator = Paginator(
            fetcher: fetcher,
            maxPage: configuration.maxPage,
            prefetchOffsetFromEnd: configuration.prefetchOffsetFromEnd
        )
    }
    
    deinit {
        prefetchTask?.cancel()
        retryTask?.cancel()
    }
    
    // MARK: - Loading
    
    func loadInitialPageIfNeeded() async {
        guard !hasLoadedInitialPage, !isLoadingInitialPage else { return }
        let generation = generation
        isLoadingInitialPage = true
        defer { isLoadingInitialPage = false }
        
        do {
            let firstPage = try await fetcher.fetchPage(0)
            // The result of a load the user has already moved on from is not news: publishing
            // it would resurrect a list they abandoned, or overwrite one they since reloaded.
            guard generation == self.generation else { return }
            items = firstPage
            hasLoadedInitialPage = true
        } catch {
            record(error, for: .initialPage, generation: generation)
        }
    }
    
    /// - Parameter force: bypasses the "this row has already been seen" and "a page is parked"
    ///   guards, for callers re-asking for a page on purpose rather than reacting to a row.
    /// - Returns: the fetch that was started, or `nil` when no page was due.
    @discardableResult
    func prefetchIfNeeded(at index: Int, force: Bool = false) -> Task<Void, Never>? {
        if !force {
            guard parkedPageIndex == nil, index > furthestRequestedIndex else { return nil }
        }
        furthestRequestedIndex = max(furthestRequestedIndex, index)
        
        let totalCount = items.count
        guard paginator.shouldPrefetch(at: index, totalCount: totalCount) else { return nil }
        
        let generation = generation
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                guard let nextPage = try await paginator.prefetchNextPageIfNeeded(
                    at: index,
                    totalCount: totalCount
                ) else { return }
                try Task.checkCancellation()
                guard generation == self.generation else { return }
                items.append(contentsOf: nextPage)
            } catch {
                guard !Task.isCancelled else { return }
                record(error, for: .nextPage(index: index), generation: generation)
            }
        }
        prefetchTask = task
        return task
    }
    
    // MARK: - Recovering from a failure
    
    func dismissFailure() {
        if case .nextPage(let index) = failure?.load {
            parkedPageIndex = index
        }
        retryTask?.cancel()
        retryTask = nil
        invalidateInFlightWork()
        failure = nil
    }
    
    func retryFailedLoad() async {
        guard let failure else { return }
        invalidateInFlightWork()
        self.failure = nil
        switch failure.load {
        case .initialPage:
            await loadInitialPageIfNeeded()
        case .nextPage(let index):
            await retryPage(at: index)
        }
    }
    
    func startRetryingFailedLoad() {
        startRequestedWork { await $0.retryFailedLoad() }
    }
    
    /// Resumes the page parked by `dismissFailure()`. Driven by whatever the UI shows in place
    /// of the missing page, which is the only thing left that can ask for it once its
    /// triggering row has already appeared.
    func startRetryingParkedPage() {
        guard let index = parkedPageIndex else { return }
        startRequestedWork { await $0.retryPage(at: index) }
    }
    
    func reload() async {
        invalidateInFlightWork()
        failure = nil
        parkedPageIndex = nil
        furthestRequestedIndex = -1
        hasLoadedInitialPage = false
        items = []
        paginator.reset()
        await loadInitialPageIfNeeded()
    }
    
    func startReloading() {
        startRequestedWork { await $0.reload() }
    }
    
    // MARK: - Pausing and resuming
    
    func pausePagination() {
        prefetchTask?.cancel()
        paginator.cancelInFlightFetch()
    }
    
    func resumePrefetchIfNeeded() {
        guard parkedPageIndex == nil, furthestRequestedIndex >= 0 else { return }
        prefetchIfNeeded(at: furthestRequestedIndex, force: true)
    }
    
    func waitForPendingWork() async {
        await retryTask?.value
        await prefetchTask?.value
    }
    
    // MARK: - Private
    
    private func retryPage(at index: Int) async {
        parkedPageIndex = nil
        guard let task = prefetchIfNeeded(at: index, force: true) else { return }
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }
    
    private func startRequestedWork(
        _ work: @escaping @MainActor (PaginatedCollectionLoader) async -> Void
    ) {
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            guard let self else { return }
            await work(self)
        }
    }
    
    /// Marks everything currently in flight as stale, so a result already on its way back
    /// cannot revive a state the user has just moved on from.
    private func invalidateInFlightWork() {
        generation &+= 1
        pausePagination()
    }
    
    private func record(_ error: Error, for load: FailedLoad, generation: Int) {
        guard !(error is CancellationError), generation == self.generation else { return }
        failure = Failure(load: load, error: error)
    }
}
