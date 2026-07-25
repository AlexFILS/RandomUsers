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
    
    enum StatusAction: Equatable {
        case dismissError
        case retryFailedFetch
        case clearSearchInput
    }
    
    typealias Status = StatusPresentation<StatusAction>
    
    /// What the list area shows.
    enum Content: Equatable {
        case users([UserModel])
        case empty(Status)
    }
    
    enum Overlay: Equatable {
        case loading
        case status(Status)
    }
    
    enum Footer: Equatable {
        case loadingNextPage
        case retryNextPage
    }
    
    private static let minimumSearchCharacterCount = 3
    
    var searchText: String = ""
    
    private(set) var users: [UserModel]
    private(set) var isSearchBarVisible = false
    private(set) var searchResults: [UserModel]?
    private var state: ScreenState = .loaded
    private var pendingPageRetryIndex: Int?
    
    @ObservationIgnored let screenTitle = String(localized: .usersScreenTitle)
    @ObservationIgnored private let paginationConfiguration: UsersPaginationConfiguration
    @ObservationIgnored private let fetcher: UserPageFetcher
    @ObservationIgnored private let paginator: Paginator<UserPageFetcher>
    @ObservationIgnored private let searchController: SearchController<UserModel>
    @ObservationIgnored private let searchDebounceDuration: Duration
    @ObservationIgnored private let onSelectUser: (UserModel) -> Void
    @ObservationIgnored private(set) var retryTask: Task<Void, Never>?
    @ObservationIgnored private var fetchGeneration = 0
    @ObservationIgnored private(set) var prefetchTask: Task<Void, Never>?
    @ObservationIgnored private var furthestAppearedIndex = -1
    
    var content: Content {
        guard let searchResults else { return .users(users) }
        guard searchResults.isEmpty else { return .users(searchResults) }
        return .empty(
            Status(
                kind: .info,
                title: String(localized: .statusInfoTitle),
                message: Constants.ErrorDescription.noMatchingUsers,
                primaryButton: Status.Button(
                    title: String(localized: .ok),
                    action: .clearSearchInput
                )
            )
        )
    }
    
    var overlay: Overlay? {
        switch state {
        case .loading:
            return .loading
        case .loaded:
            return nil
        case .failed(let failedFetch, let message):
            return .status(errorStatus(for: failedFetch, message: message))
        }
    }
    
    var footer: Footer? {
        if paginator.isFetchingNextPage { return .loadingNextPage }
        if pendingPageRetryIndex != nil { return .retryNextPage }
        return nil
    }
    
    private var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }
    
    init(
        users: [UserModel] = [],
        service: ServiceProtocol,
        searchService: SearchableCollectionProtocol,
        paginationConfiguration: UsersPaginationConfiguration = .default,
        searchDebounceDuration: Duration = .seconds(1),
        onSelectUser: @escaping (UserModel) -> Void
    ) {
        self.users = users
        self.paginationConfiguration = paginationConfiguration
        self.searchDebounceDuration = searchDebounceDuration
        self.onSelectUser = onSelectUser
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
    
    func select(_ user: UserModel) {
        onSelectUser(user)
    }
    
    /// Single entry point for every status-screen button, so the view forwards an intent rather
    /// than choosing which method a given button maps to.
    func perform(_ action: StatusAction) {
        switch action {
        case .dismissError:
            clearErrors()
        case .retryFailedFetch:
            retryTapped()
        case .clearSearchInput:
            clearSearchInput()
        }
    }
    
    /// Dismisses the failure. A page that was mid-flight stays parked rather than silently
    /// re-firing, so the footer offers an explicit retry rather than the list silently ending.
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
        guard let task = prefetchNextPageIfNeeded(at: index, force: true) else { return }
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }
    
    /// Stops pagination without touching the error state, leaving the page to be re-asked for
    /// later by `resumePrefetchIfNeeded()`.
    private func pausePagination() {
        prefetchTask?.cancel()
        prefetchTask = nil
        paginator.cancelInFlightFetch()
    }
    
    /// Stops whatever is in flight and marks its result as stale, so a failure that is already
    /// on its way back cannot revive an error state the user has just moved on from.
    private func invalidateInFlightFetches() {
        fetchGeneration &+= 1
        pausePagination()
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
    
    @discardableResult
    func prefetchNextPageIfNeeded(at index: Int, force: Bool = false) -> Task<Void, Never>? {
        if !force {
            guard pendingPageRetryIndex == nil, index > furthestAppearedIndex else { return nil }
        }
        furthestAppearedIndex = max(furthestAppearedIndex, index)
        
        let totalCount = users.count
        guard paginator.shouldPrefetch(at: index, totalCount: totalCount) else { return nil }
        
        let generation = fetchGeneration
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                guard let newUsers = try await paginator.prefetchNextPageIfNeeded(
                    at: index,
                    totalCount: totalCount
                ) else { return }
                try Task.checkCancellation()
                guard generation == fetchGeneration else { return }
                users.append(contentsOf: newUsers)
            } catch {
                guard !Task.isCancelled else { return }
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
        do {
            try await Task.sleep(for: searchDebounceDuration)
            pausePagination()
            let results = try await searchController.search(query: searchText, in: users)
            // `.task(id:)` cancels this on the next keystroke, but the matching itself has no
            // suspension point at which to notice - so check before publishing
            try Task.checkCancellation()
            searchResults = results
        } catch {
            handle(error, generation: generation)
        }
    }
    
    private func clearSearchResults() {
        guard searchResults != nil else { return }
        searchResults = nil
        resumePrefetchIfNeeded()
    }
    
    private func errorStatus(for failedFetch: FailedFetch?, message: String) -> Status {
        let title = String(localized: .statusErrorTitle)
        let dismiss = Status.Button(title: String(localized: .ok), action: .dismissError)
        let retry = Status.Button(title: String(localized: .retry), action: .retryFailedFetch)
        
        guard let failedFetch else {
            return Status(kind: .error, title: title, message: message, primaryButton: dismiss)
        }
        
        switch failedFetch {
        case .initialUsers:
            return Status(kind: .error, title: title, message: message, primaryButton: retry)
        case .nextPage:
            return Status(
                kind: .error,
                title: title,
                message: message,
                primaryButton: dismiss,
                secondaryButton: retry
            )
        }
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
            searchService: SearchService(),
            onSelectUser: { _ in }
        )
    }
    
    static func developWithError() -> UsersViewModel {
        UsersViewModel(
            service: UsersServiceErrorStub(),
            searchService: SearchService(),
            onSelectUser: { _ in }
        )
    }
}
#endif
