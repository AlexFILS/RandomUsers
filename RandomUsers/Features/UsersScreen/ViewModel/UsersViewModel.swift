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
    @ObservationIgnored private let service: ServiceProtocol
    @ObservationIgnored private let searchService: SearchableCollectionProtocol
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    var displayedUsers: [User] {
        searchResults ?? users
    }

    var hasNoSearchResults: Bool {
        searchResults?.isEmpty ?? false
    }

    init(
        users: [User] = [],
        service: ServiceProtocol = NetworkingClient(baseURL: Constants.Networking.baseURL),
        searchService: SearchableCollectionProtocol = UserSearchService()
    ) {
        self.users = users
        self.service = service
        self.searchService = searchService
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
                Endpoint(path: Constants.Networking.usersEndpoint)
            )
            users = response.results
        }
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
}
