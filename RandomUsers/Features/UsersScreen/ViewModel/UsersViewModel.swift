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
final class UsersViewModel: BaseViewModel {
    let screenTitle = "Users"
    private(set) var users: [User]
    private(set) var isSearchBarVisible = false
    private(set) var searchResults: [User]?
    private(set) var isFetchingNextPage = false
    @ObservationIgnored private let service: ServiceProtocol
    @ObservationIgnored private let searchService: SearchableCollectionProtocol
    @ObservationIgnored private let paginationConfiguration: UsersPaginationConfiguration
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var nextPageTask: Task<Void, Never>?
    @ObservationIgnored private var currentPage = 0

    var displayedUsers: [User] {
        searchResults ?? users
    }

    var hasNoSearchResults: Bool {
        searchResults?.isEmpty ?? false
    }

    private var hasMorePages: Bool {
        currentPage < paginationConfiguration.maxPage
    }

    init(
        users: [User] = [],
        service: ServiceProtocol = NetworkingClient(baseURL: Constants.Networking.baseURL),
        searchService: SearchableCollectionProtocol = UserSearchService(),
        paginationConfiguration: UsersPaginationConfiguration = .default
    ) {
        self.users = users
        self.service = service
        self.searchService = searchService
        self.paginationConfiguration = paginationConfiguration
    }

    var searchText: String = "" {
        didSet {
            guard searchText != oldValue else { return }
            scheduleSearch()
        }
    }

    func fetchUsersIfNeeded() async {
        guard users.isEmpty else { return }
        await perform {
            let response: UsersResponse = try await service.request(
                paginationConfiguration.endpoint(forPage: currentPage)
            )
            users = appendingUniqueUsers(response.results, to: [])
        }
    }

    func prefetchNextPageIfNeeded(at index: Int) {
        guard searchResults == nil, hasMorePages else { return }
        let prefetchThreshold = users.count - 1 - paginationConfiguration.prefetchOffsetFromEnd
        guard index == prefetchThreshold else { return }
        print("CSID will start loading next page because we are at index \(index)")
        loadNextPage()
    }

    func startSearching() {
        isSearchBarVisible = true
    }

    func cancelSearch() {
        isSearchBarVisible = false
        searchText = ""
    }

    func cancelSearchTask() {
        searchTask?.cancel()
    }

    func clearSearchInput() {
        searchText = ""
    }
}

private extension UsersViewModel {
    func scheduleSearch() {
        searchTask?.cancel()
        guard !searchText.isEmpty else {
            searchResults = nil
            return
        }
        let query = searchText
        searchTask = Task { [weak self] in
            guard let self else { return }
            guard let results = try? await searchService.search(query: query, in: users) else { return }
            guard !Task.isCancelled else { return }
            searchResults = results
        }
    }

    func loadNextPage() {
        guard hasMorePages, nextPageTask == nil else { return }
        let pageToLoad = currentPage + 1
        nextPageTask = Task { [weak self] in
            guard let self else { return }
            await self.fetchNextPage(pageToLoad)
            self.nextPageTask = nil
        }
    }

    func fetchNextPage(_ page: Int) async {
        isFetchingNextPage = true
        defer { isFetchingNextPage = false }
        // A failed prefetch simply leaves the already-loaded users on screen;
        // the user can retry by scrolling back to the trigger position.
        guard let response: UsersResponse = try? await service.request(
            paginationConfiguration.endpoint(forPage: page)
        ) else { return }
        guard !Task.isCancelled else { return }
        users = appendingUniqueUsers(response.results, to: users)
        currentPage = page
        print("CSID fetched page \(page)")
    }

    /// `randomuser.me` can return the same `login.uuid` more than once across
    /// seeded pages, which would otherwise violate `ForEach`'s identity requirement.
    func appendingUniqueUsers(_ newUsers: [User], to existing: [User]) -> [User] {
        var seenIDs = Set(existing.map(\.id))
        var merged = existing
        for user in newUsers where seenIDs.insert(user.id).inserted {
            merged.append(user)
        }
        return merged
    }
}
