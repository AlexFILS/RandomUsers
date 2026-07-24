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

    /// Collapses loading/error into one state instead of parallel `isLoading`/`hasError`/
    /// `error` flags, so the description shown alongside an error can never go stale - each
    /// transition into `.failed` carries its own message, computed fresh at the point of failure.
    private enum ScreenState {
        case loading
        case loaded
        case failed(FailedFetch?, message: String)
    }

    var searchText: String = ""

    private(set) var users: [UserModel]
    private(set) var isSearchBarVisible = false
    private(set) var searchResults: [UserModel]?
    private var state: ScreenState = .loaded

    @ObservationIgnored let screenTitle = "Users"
    @ObservationIgnored private let service: ServiceProtocol
    @ObservationIgnored private let paginationConfiguration: UsersPaginationConfiguration
    @ObservationIgnored private let paginator: Paginator<UserPageFetcher>
    @ObservationIgnored private let searchController: SearchController<UserModel>
    @ObservationIgnored private let searchDebounceDuration: Duration
    @ObservationIgnored private var retryTask: Task<Void, Never>?

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
            return Constants.ErrorDescription.defaultError.rawValue
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
        self.service = service
        self.paginationConfiguration = paginationConfiguration
        self.searchDebounceDuration = searchDebounceDuration
        self.paginator = Paginator(
            fetcher: UserPageFetcher(
                service: service,
                configuration: paginationConfiguration
            ),
            maxPage: paginationConfiguration.maxPage,
            prefetchOffsetFromEnd: paginationConfiguration.prefetchOffsetFromEnd
        )
        self.searchController = SearchController(searchService: searchService)
    }
    
    deinit {
        retryTask?.cancel()
    }
    
    func clearErrors() {
        state = .loaded
    }

    func retry() async {
        guard case .failed(let failedFetch, _) = state, let failedFetch else { return }
        clearErrors()
        switch failedFetch {
        case .initialUsers:
            await fetchUsersIfNeeded()
        case .nextPage(let index):
            prefetchNextPageIfNeeded(at: index)
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
            let response: UsersResponse = try await service.request(
                paginationConfiguration.endpoint(forPage: 0)
            )
            users = response.results
            state = .loaded
        } catch is CancellationError {
            state = .loaded
        } catch {
            handle(error, retryingWith: .initialUsers)
        }
    }

    func prefetchNextPageIfNeeded(at index: Int) {
        guard searchResults == nil else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                guard let newUsers = try await paginator.prefetchNextPageIfNeeded(
                    at: index,
                    totalCount: users.count
                ) else { return }
                users.append(contentsOf: newUsers)
            } catch {
                handle(error, retryingWith: .nextPage(index: index))
            }
        }
    }

    func startSearching() {
        isSearchBarVisible = true
    }
    
    func cancelSearch() {
        isSearchBarVisible = false
        searchText = ""
    }
    
    func clearSearchInput() {
        searchText = ""
    }
    
    func search() async {
        guard !searchText.isEmpty else {
            searchResults = nil
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
    
    private func handle(
        _ error: Error,
        retryingWith retry: FailedFetch? = nil
    ) {
        guard !(error is CancellationError) else { return }
        let message = (error as? DescribableErrorProtocol)?.description
            ?? Constants.ErrorDescription.defaultError.rawValue
        state = .failed(retry, message: message)
    }
}

extension UsersViewModel {
    static func develop() -> UsersViewModel {
        UsersViewModel(
            service: UsersServiceStub(),
            searchService: UserSearchService()
        )
    }
}
