//
//  UsersViewModel.swift
//  RandomUsers
//
//  Created by Alexandru Mihai on 21/07/2026.
//

import Foundation
import Networking
import Observation

@MainActor
@Observable
final class UsersViewModel {
    private enum FailedFetch {
        case initialUsers
        case nextPage(index: Int)
    }

    private enum ScreenState {
        case loading
        case loaded
        case failed(FailedFetch?, message: String)
    }

    private static let minimumSearchCharacterCount = 3

    var searchText: String = ""

    private(set) var users: [UserModel]
    private(set) var isSearchBarVisible = false
    private(set) var searchResults: [UserModel]?
    private var state: ScreenState = .loaded
    /// Index of a page fetch that failed and whose error the user dismissed. Pagination stays
    /// parked on it until they ask for it again - see `clearErrors()`.
    private var pendingPageRetryIndex: Int?

    @ObservationIgnored let screenTitle = String(localized: .usersScreenTitle)
    @ObservationIgnored private let paginationConfiguration: UsersPaginationConfiguration
    @ObservationIgnored private let fetcher: UserPageFetcher
    @ObservationIgnored private let paginator: Paginator<UserPageFetcher>
    @ObservationIgnored private let searchController: SearchController<UserModel>
    @ObservationIgnored private let searchDebounceDuration: Duration
    /// Readable so tests can await the work started by `retryTapped()`/`retryPendingPage()`.
    @ObservationIgnored private(set) var retryTask: Task<Void, Never>?
    /// Bumped whenever the user dismisses or restarts a fetch, and captured by each fetch when
    /// it starts. A fetch whose generation is stale by the time it fails is discarded: without
    /// this, a request still in flight when the user tapped "OK" would put the error they just
    /// dismissed straight back on screen - possibly while another screen is pushed on top.
    @ObservationIgnored private var fetchGeneration = 0
    /// Readable so tests can await pagination kicked off by `clearErrors()`/`cancelSearch()`,
    /// which return no task of their own.
    @ObservationIgnored private(set) var prefetchTask: Task<Void, Never>?
    /// Furthest row index the list has reported, used both to skip redundant prefetch checks
    /// when scrolling back up and as the resume point after a fetch is interrupted - see
    /// `resumePrefetchIfNeeded()`.
    @ObservationIgnored private var furthestAppearedIndex = -1

    /// Blocking, full-screen loading. Deliberately *excludes* `isFetchingNextPage`: loading a
    /// further page must not blur out and disable the list the user is already reading.
    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var hasError: Bool {
        if case .failed = state { return true }
        return false
    }

    var errorDescription: String {
        guard case .failed(_, let message) = state else {
            return Constants.ErrorDescription.defaultError
        }
        return message
    }

    var isFetchingNextPage: Bool {
        paginator.isFetchingNextPage
    }

    var displayedUsers: [UserModel] {
        searchResults ?? users
    }

    var hasNoSearchResults: Bool {
        searchResults?.isEmpty ?? false
    }

    /// True when dismissing the error would reveal a blank screen instead of a user list.
    var isInitialFetchFailure: Bool {
        if case .failed(.initialUsers, _) = state { return true }
        return false
    }

    /// Whether the current failure has a fetch worth re-running. A search failure has none, so
    /// offering "Retry" for it would be a button that provably does nothing.
    var canRetry: Bool {
        guard case .failed(let failedFetch, _) = state else { return false }
        return failedFetch != nil
    }

    /// Whether pagination is parked on a page whose error the user dismissed, and so needs an
    /// explicit nudge from the list footer to continue.
    var hasPendingPageRetry: Bool {
        pendingPageRetryIndex != nil
    }

    init(
        users: [UserModel] = [],
        service: ServiceProtocol,
        searchService: SearchableCollectionProtocol,
        paginationConfiguration: UsersPaginationConfiguration = .default,
        searchDebounceDuration: Duration = .seconds(1)
    ) {
        self.users = users
        self.paginationConfiguration = paginationConfiguration
        self.searchDebounceDuration = searchDebounceDuration
        let fetcher = UserPageFetcher(
            service: service,
            configuration: paginationConfiguration
        )
        self.fetcher = fetcher
        self.paginator = Paginator(
            fetcher: fetcher,
            maxPage: paginationConfiguration.maxPage,
            prefetchOffsetFromEnd: paginationConfiguration.prefetchOffsetFromEnd
        )
        self.searchController = SearchController(searchService: searchService)
    }
    
    deinit {
        retryTask?.cancel()
        prefetchTask?.cancel()
    }
    
    /// Dismisses the error without retrying, and makes the dismissal stick.
    ///
    /// This deliberately does *not* re-run the fetch that failed. Doing so made "OK" an
    /// invisible retry: the same request went straight back out, failed again, and put the
    /// error back on screen, so the user could never dismiss it while the failure persisted.
    /// A page failure is parked in `pendingPageRetryIndex` instead - the row that would
    /// normally re-trigger pagination has already appeared and never will again, so the list
    /// footer offers an explicit retry rather than the list silently ending.
    func clearErrors() {
        if case .failed(.nextPage(let index), _) = state {
            pendingPageRetryIndex = index
        }
        retryTask?.cancel()
        retryTask = nil
        invalidateInFlightFetches()
        state = .loaded
    }

    func retry() async {
        guard case .failed(
            let failedFetch,
            _
        ) = state, let failedFetch else { return }
        // Not `clearErrors()`: this path retries the failed fetch itself, so it must neither
        // park the page nor cancel the retry task it is running inside.
        invalidateInFlightFetches()
        state = .loaded
        switch failedFetch {
        case .initialUsers:
            await fetchUsersIfNeeded()
        case .nextPage(let index):
            await retryNextPage(at: index)
        }
    }

    func retryTapped() {
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            await self?.retry()
        }
    }

    /// Resumes pagination parked by `clearErrors()`. Driven by the list footer, which is the
    /// only thing left that can ask for the page once its triggering row has appeared.
    func retryPendingPage() {
        guard let index = pendingPageRetryIndex else { return }
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            await self?.retryNextPage(at: index)
        }
    }

    private func retryNextPage(at index: Int) async {
        pendingPageRetryIndex = nil
        await prefetchNextPageIfNeeded(at: index, force: true)?.value
    }

    /// Stops whatever is in flight and marks its result as stale, so a failure that is already
    /// on its way back cannot revive an error state the user has just moved on from.
    private func invalidateInFlightFetches() {
        fetchGeneration &+= 1
        // `prefetchTask` only holds the *most recent* prefetch attempt - a row appearing can
        // overwrite it with a no-op - so cancelling the paginator is what actually reaches the
        // request. Cancelling both keeps the bookkeeping honest either way.
        prefetchTask?.cancel()
        prefetchTask = nil
        paginator.cancelInFlightFetch()
    }

    func fetchUsersIfNeeded() async {
        guard users.isEmpty, !isLoading else { return }
        let generation = fetchGeneration
        state = .loading
        do {
            users = try await fetcher.fetchPage(0)
            state = .loaded
        } catch is CancellationError {
            state = .loaded
        } catch {
            handle(error, retryingWith: .initialUsers, generation: generation)
        }
    }

    /// - Parameter force: bypasses the `furthestAppearedIndex` guard. Used by the resume paths,
    ///   which need to re-ask for a row that has already appeared.
    @discardableResult
    func prefetchNextPageIfNeeded(at index: Int, force: Bool = false) -> Task<Void, Never>? {
        // The eligibility checks run *inside* the `Task` rather than synchronously here,
        // so that a row's `onAppear` never touches `@Observable` state directly during
        // List's own scroll-driven layout pass - reading `isFetchingNextPage`/`searchResults`
        // synchronously from `onAppear` was corrupting the List's scroll offset after
        // scrolling through many rows (visible as a blank gap with a stray separator at
        // the top once scrolled back up).
        let task = Task { [weak self] in
            guard let self else { return }
            if !force {
                // A parked page must not be picked back up by a row scrolling into view -
                // only by the footer's explicit retry.
                guard pendingPageRetryIndex == nil, index > furthestAppearedIndex else { return }
            }
            furthestAppearedIndex = max(furthestAppearedIndex, index)
            guard searchResults == nil, !isFetchingNextPage, paginator.hasMorePages else { return }
            let generation = fetchGeneration
            do {
                guard let newUsers = try await paginator.prefetchNextPageIfNeeded(
                    at: index,
                    totalCount: users.count
                ) else { return }
                users.append(contentsOf: newUsers)
            } catch {
                handle(
                    error,
                    retryingWith: .nextPage(
                        index: index
                    ),
                    generation: generation
                )
            }
        }
        prefetchTask = task
        return task
    }

    /// Re-asks for the page the furthest-seen row would have triggered.
    ///
    /// A prefetch can be abandoned without any row appearing again afterwards - the user was
    /// already at the bottom of the list when a search cancelled the in-flight fetch, or when
    /// the fetch failed and they dismissed the error. `onAppear` fires once per row, so
    /// without this the list would silently stop paginating with no way to recover.
    private func resumePrefetchIfNeeded() {
        // A page parked by a dismissed error stays parked: leaving search is not the user
        // asking to re-run a fetch they already chose to walk away from.
        guard pendingPageRetryIndex == nil, furthestAppearedIndex >= 0 else { return }
        prefetchNextPageIfNeeded(at: furthestAppearedIndex, force: true)
    }

    func startSearching() {
        isSearchBarVisible = true
    }

    func cancelSearch() {
        isSearchBarVisible = false
        searchText = ""
        clearSearchResults()
    }

    func clearSearchInput() {
        searchText = ""
    }

    func search() async {
        guard searchText.count >= Self.minimumSearchCharacterCount else {
            clearSearchResults()
            return
        }
        let generation = fetchGeneration
        paginator.cancelInFlightFetch()
        do {
            try await Task.sleep(for: searchDebounceDuration)
            searchResults = try await searchController.search(query: searchText, in: users)
        } catch {
            handle(error, generation: generation)
        }
    }

    /// Leaving search restores the full list, so the pagination that `search()` cancelled has
    /// to be picked back up. Guarded so that typing below the minimum query length doesn't
    /// re-trigger a fetch on every keystroke.
    private func clearSearchResults() {
        guard searchResults != nil else { return }
        searchResults = nil
        resumePrefetchIfNeeded()
    }

    private func handle(
        _ error: Error,
        retryingWith retry: FailedFetch? = nil,
        generation: Int
    ) {
        guard !(error is CancellationError), generation == fetchGeneration else { return }
        let message = (error as? DescribableErrorProtocol)?.description
            ?? Constants.ErrorDescription.defaultError
        state = .failed(retry, message: message)
    }
}

#if DEBUG
extension UsersViewModel {
    static func develop() -> UsersViewModel {
        UsersViewModel(
            service: UsersServiceStub(),
            searchService: UserSearchService()
        )
    }

    static func developWithError() -> UsersViewModel {
        UsersViewModel(
            service: UsersServiceErrorStub(),
            searchService: UserSearchService()
        )
    }
}
#endif
