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
    let screenTitle = "Users"
    private(set) var users: [User]
    private(set) var isSearchBarVisible = false
    private(set) var searchResults: [User]?
    private(set) var isLoading = false
    private(set) var hasError = false
    @ObservationIgnored private(set) var error: DescribableErrorProtocol?

    @ObservationIgnored private let service: ServiceProtocol
    @ObservationIgnored private let paginationConfiguration: UsersPaginationConfiguration
    @ObservationIgnored private let paginator: Paginator<UserPageFetcher>
    @ObservationIgnored private let searchController: SearchController<User>

    var errorDescription: String {
        error?.description ?? Constants.ErrorDescription.defaultError.rawValue
    }

    var isFetchingNextPage: Bool {
        paginator.isFetchingNextPage
    }

    var displayedUsers: [User] {
        searchResults ?? users
    }

    var hasNoSearchResults: Bool {
        searchResults?.isEmpty ?? false
    }

    init(
        users: [User] = [],
        service: ServiceProtocol = NetworkingClient(baseURL: Constants.Networking.baseURL),
        searchService: SearchableCollectionProtocol = UserSearchService(),
        paginationConfiguration: UsersPaginationConfiguration = .default
    ) {
        self.users = users
        self.service = service
        self.paginationConfiguration = paginationConfiguration
        self.paginator = Paginator(
            fetcher: UserPageFetcher(service: service, configuration: paginationConfiguration),
            maxPage: paginationConfiguration.maxPage,
            prefetchOffsetFromEnd: paginationConfiguration.prefetchOffsetFromEnd
        )
        self.searchController = SearchController(searchService: searchService)
    }

    var searchText: String = ""

    func clearErrors() {
        hasError = false
        error = nil
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
            handle(error)
        }
    }

    func prefetchNextPageIfNeeded(at index: Int) {
        guard searchResults == nil else { return }
        paginator.prefetchNextPageIfNeeded(at: index, totalCount: users.count) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let newUsers):
                users.append(contentsOf: newUsers)
            case .failure(let error):
                handle(error)
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
            searchResults = try await searchController.search(query: searchText, in: users)
        } catch {
            handle(error)
        }
    }

    /// Shared error-reporting policy for any async work run outside of `fetchUsersIfNeeded`
    /// (e.g. the paginator's background fetch). Cancellation is a normal lifecycle event,
    /// not a failure, so it's filtered out here rather than surfaced as `hasError`.
    private func handle(_ error: Error) {
        guard !(error is CancellationError) else { return }
        if let describableError = error as? DescribableErrorProtocol {
            self.error = describableError
        }
        hasError = true
    }
}
