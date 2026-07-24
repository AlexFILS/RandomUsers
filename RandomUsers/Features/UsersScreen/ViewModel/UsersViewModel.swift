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
    
    private(set) var users: [UserModel]
    private(set) var isSearchBarVisible = false
    private(set) var searchResults: [UserModel]?
    private(set) var isLoading = false
    private(set) var hasError = false
    
    @ObservationIgnored private(set) var error: DescribableErrorProtocol?
    @ObservationIgnored let screenTitle = "Users"
    @ObservationIgnored private let service: ServiceProtocol
    @ObservationIgnored private let paginationConfiguration: UsersPaginationConfiguration
    @ObservationIgnored private let paginator: Paginator<UserPageFetcher>
    @ObservationIgnored private let searchController: SearchController<UserModel>
    @ObservationIgnored private let searchDebounceDuration: Duration
    @ObservationIgnored private var failedFetch: FailedFetch?
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    
    var errorDescription: String {
        error?.description ?? Constants.ErrorDescription.defaultError.rawValue
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
        if case .initialUsers = failedFetch { return true }
        return false
    }
    
    /// Dependencies have no concrete-type defaults here on purpose - resolving the production
    /// `NetworkingClient`/`UserSearchService` is a composition-root concern, not the initializer's.
    /// See `UsersViewModel.production()` for the app's actual wiring.
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
            fetcher: UserPageFetcher(service: service, configuration: paginationConfiguration),
            maxPage: paginationConfiguration.maxPage,
            prefetchOffsetFromEnd: paginationConfiguration.prefetchOffsetFromEnd
        )
        self.searchController = SearchController(searchService: searchService)
    }
    
    deinit {
        retryTask?.cancel()
    }
    
    var searchText: String = ""
    
    func clearErrors() {
        hasError = false
        error = nil
        failedFetch = nil
    }
    
    func retry() async {
        guard let failedFetch else { return }
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
        isLoading = true
        defer { isLoading = false }
        do {
            let response: UsersResponse = try await service.request(
                paginationConfiguration.endpoint(forPage: 0)
            )
            users = response.results
        } catch {
            handle(error, retryingWith: .initialUsers)
        }
    }
    
    func prefetchNextPageIfNeeded(at index: Int) {
        guard searchResults == nil else { return }
        paginator.prefetchNextPageIfNeeded(
            at: index,
            totalCount: users.count
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let newUsers):
                users.append(contentsOf: newUsers)
            case .failure(let error):
                handle(
                    error,
                    retryingWith: .nextPage(index: index)
                )
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
        if let describableError = error as? DescribableErrorProtocol {
            self.error = describableError
        }
        failedFetch = retry
        hasError = true
    }
}

extension UsersViewModel {
    static func production() -> UsersViewModel {
        UsersViewModel(
            service: NetworkingClient(baseURL: Constants.Networking.baseURL),
            searchService: UserSearchService()
        )
    }
}
