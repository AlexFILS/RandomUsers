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
    enum StatusAction: Equatable {
        case dismissError
        case retryFailedFetch
        case clearSearchInput
        case reloadUsers
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

    var searchText: String {
        get { searchCoordinator.text }
        set { searchCoordinator.text = newValue }
    }

    var isSearchBarVisible: Bool { searchCoordinator.isActive }
    var users: [UserModel] { loader.items }
    var searchResults: [UserModel]? { searchCoordinator.results }

    /// A search failure has no fetch behind it to retry, so it is tracked here rather than
    /// pushed into the loader and dressed up as a load that failed.
    private var searchFailureMessage: String?

    @ObservationIgnored let screenTitle = String(localized: .usersScreenTitle)
    @ObservationIgnored private let loader: PaginatedCollectionLoader<UserPageFetcher>
    @ObservationIgnored private let searchCoordinator: SearchCoordinator<UserModel>
    @ObservationIgnored private let onSelectUser: (UserModel) -> Void

    var content: Content {
        if let searchResults = searchCoordinator.results {
            guard searchResults.isEmpty else { return .users(searchResults) }
            return .empty(noMatchesStatus)
        }
        guard loader.items.isEmpty, loader.hasLoadedInitialPage else {
            return .users(loader.items)
        }
        return .empty(noUsersStatus)
    }

    var overlay: Overlay? {
        if loader.isLoadingInitialPage { return .loading }
        if let failure = loader.failure {
            return .status(errorStatus(for: failure.load, message: message(for: failure.error)))
        }
        if let searchFailureMessage {
            return .status(errorStatus(for: nil, message: searchFailureMessage))
        }
        return nil
    }

    var footer: Footer? {
        if loader.isFetchingNextPage { return .loadingNextPage }
        if loader.hasParkedPage { return .retryNextPage }
        return nil
    }

    init(
        users: [UserModel] = [],
        service: ServiceProtocol,
        searchService: SearchableCollectionProtocol,
        paginationConfiguration: UsersPaginationConfiguration = .default,
        searchConfiguration: SearchConfiguration = .default,
        onSelectUser: @escaping (UserModel) -> Void
    ) {
        self.onSelectUser = onSelectUser
        self.loader = PaginatedCollectionLoader(
            fetcher: UserPageFetcher(
                service: service,
                configuration: paginationConfiguration
            ),
            configuration: paginationConfiguration,
            items: users
        )
        self.searchCoordinator = SearchCoordinator(
            searchService: searchService,
            configuration: searchConfiguration
        )
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
        case .reloadUsers:
            reloadTapped()
        }
    }

    /// Awaits whatever the screen has in flight. Exists so callers can act on a settled state
    /// without reaching for the task handles themselves.
    func waitForPendingWork() async {
        await loader.waitForPendingWork()
    }

    // MARK: - Loading

    func fetchUsersIfNeeded() async {
        await loader.loadInitialPageIfNeeded()
    }

    func prefetchNextPageIfNeeded(at index: Int) {
        loader.prefetchIfNeeded(at: index)
    }

    func clearErrors() {
        searchFailureMessage = nil
        loader.dismissFailure()
    }

    func retry() async {
        await loader.retryFailedLoad()
    }

    func retryTapped() {
        loader.startRetryingFailedLoad()
    }

    func retryPendingPage() {
        loader.startRetryingParkedPage()
    }

    func reloadTapped() {
        loader.startReloading()
    }

    // MARK: - Search

    func startSearching() {
        searchCoordinator.activate()
    }

    func cancelSearch() {
        guard searchCoordinator.cancel() else { return }
        loader.resumePrefetchIfNeeded()
    }

    func clearSearchInput() {
        searchCoordinator.clearText()
    }

    func search() async {
        guard searchCoordinator.hasMatchableQuery else {
            clearSearchResults()
            return
        }
        // Before the debounce rather than after it: a page fetched during the wait is one the
        // user has already shown they are no longer scrolling towards.
        loader.pausePagination()
        do {
            try await searchCoordinator.run(over: { loader.items })
        } catch is CancellationError {
            return
        } catch {
            searchFailureMessage = message(for: error)
        }
    }

    private func clearSearchResults() {
        guard searchCoordinator.clearResults() else { return }
        loader.resumePrefetchIfNeeded()
    }

    // MARK: - Status presentation

    private var noMatchesStatus: Status {
        Status(
            kind: .info,
            title: String(localized: .statusInfoTitle),
            message: Constants.ErrorDescription.noMatchingUsers,
            primaryButton: Status.Button(
                title: String(localized: .ok),
                action: .clearSearchInput
            )
        )
    }

    private var noUsersStatus: Status {
        Status(
            kind: .info,
            title: String(localized: .statusInfoTitle),
            message: Constants.ErrorDescription.noUsers,
            primaryButton: Status.Button(
                title: String(localized: .retry),
                action: .reloadUsers
            )
        )
    }

    private func errorStatus(
        for failedLoad: PaginatedCollectionLoader<UserPageFetcher>.FailedLoad?,
        message: String
    ) -> Status {
        let title = String(localized: .statusErrorTitle)
        let dismiss = Status.Button(title: String(localized: .ok), action: .dismissError)
        let retry = Status.Button(title: String(localized: .retry), action: .retryFailedFetch)

        // No load behind it - a search failure. "Retry" would provably do nothing.
        guard let failedLoad else {
            return Status(kind: .error, title: title, message: message, primaryButton: dismiss)
        }

        switch failedLoad {
        case .initialPage:
            // Dismissing would reveal a blank screen, so retrying is the only way forward.
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

    private func message(for error: Error) -> String {
        (error as? DescribableErrorProtocol)?.description
        ?? Constants.ErrorDescription.defaultError
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
