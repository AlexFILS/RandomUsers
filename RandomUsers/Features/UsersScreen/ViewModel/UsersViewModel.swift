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

    @ObservationIgnored let screenTitle = String(localized: "Users")
    @ObservationIgnored private let paginationConfiguration: UsersPaginationConfiguration
    @ObservationIgnored private let fetcher: UserPageFetcher
    @ObservationIgnored private let paginator: Paginator<UserPageFetcher>
    @ObservationIgnored private let searchController: SearchController<UserModel>
    @ObservationIgnored private let searchDebounceDuration: Duration
    @ObservationIgnored private var retryTask: Task<Void, Never>?
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
    
    /// Dismisses the error without retrying. Pagination is resumed explicitly: the row that
    /// would normally re-trigger it has already appeared, so nothing else would ever ask
    /// again and the list would be stuck at its current length.
    func clearErrors() {
        state = .loaded
        resumePrefetchIfNeeded()
    }

    func retry() async {
        guard case .failed(
            let failedFetch,
            _
        ) = state, let failedFetch else { return }
        // Not `clearErrors()`: this path retries the failed fetch itself, so it must not also
        // kick off a resume for the same page.
        state = .loaded
        switch failedFetch {
        case .initialUsers:
            await fetchUsersIfNeeded()
        case .nextPage(let index):
            await prefetchNextPageIfNeeded(at: index, force: true)?.value
        }
    }

    func retryTapped() {
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            await self?.retry()
            self?.retryTask = nil
        }
    }

    func fetchUsersIfNeeded() async {
        guard users.isEmpty, !isLoading else { return }
        state = .loading
        do {
            users = try await fetcher.fetchPage(0)
            state = .loaded
        } catch is CancellationError {
            state = .loaded
        } catch {
            handle(error, retryingWith: .initialUsers)
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
            guard force || index > furthestAppearedIndex else { return }
            furthestAppearedIndex = max(furthestAppearedIndex, index)
            guard searchResults == nil, !isFetchingNextPage, paginator.hasMorePages else { return }
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
                    )
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
        guard furthestAppearedIndex >= 0 else { return }
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
        paginator.cancelInFlightFetch()
        do {
            try await Task.sleep(for: searchDebounceDuration)
            searchResults = try await searchController.search(query: searchText, in: users)
        } catch {
            handle(error)
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
        retryingWith retry: FailedFetch? = nil
    ) {
        guard !(error is CancellationError) else { return }
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
