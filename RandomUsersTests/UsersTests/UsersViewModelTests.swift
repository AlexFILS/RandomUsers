//
//  UsersViewModelTests.swift
//  RandomUsersTests
//
//  Created by Alexandru Mihai on 22/07/2026.
//

import Testing
import Foundation
import Networking
@testable import RandomUsers

@MainActor
struct UsersViewModelTests {
    
    private struct ImmediateSearchService: SearchableCollectionProtocol {
        func search<T: SearchableModelProtocol>(query: String, in elements: [T]) async throws -> [T] {
            elements
        }
    }

    private struct FailingSearchService: SearchableCollectionProtocol {
        struct SearchError: Error {}

        func search<T: SearchableModelProtocol>(query: String, in elements: [T]) async throws -> [T] {
            throw SearchError()
        }
    }

    /// Matching that can be held mid-flight, so a search can be cancelled at the one moment that
    /// matters: after the query has been handed over, but before its results are published.
    private struct GatedSearchService: SearchableCollectionProtocol {
        let gate: Gate

        func search<T: SearchableModelProtocol>(query: String, in elements: [T]) async throws -> [T] {
            await gate.wait()
            return elements
        }
    }

    private static func makeUser(id: String) -> UserModel {
        UserModel(
            gender: .female,
            name: Name(title: "Mx", first: "Test", last: "User"),
            location: Location(
                street: Street(number: 1, name: "Main St"),
                city: "City",
                state: "State",
                country: "Country",
                postcode: "00000",
                coordinates: Coordinates(latitude: "0", longitude: "0"),
                timezone: TimeZoneInfo(offset: "+0:00", description: "UTC")
            ),
            email: "\(id)@example.com",
            login: Login(uuid: id, username: id, password: "x", salt: "x", md5: "x", sha1: "x", sha256: "x"),
            dateOfBirth: DateInfo(date: Date(timeIntervalSince1970: 0), age: 30),
            registered: DateInfo(date: Date(timeIntervalSince1970: 0), age: 1),
            phone: "000",
            cell: "000",
            identification: UserIdentification(name: "ID", value: "1"),
            picture: Picture(large: "", medium: "", thumbnail: ""),
            nationality: "US"
        )
    }
    
    /// Stands in for the coordinator: records the navigation the screen asked for, without any
    /// `NavigationPath` being involved.
    private final class SelectionSpy {
        private(set) var selected: [UserModel] = []

        func record(_ user: UserModel) {
            selected.append(user)
        }
    }

    private static func makeViewModel(
        users: [UserModel] = [],
        service: StubService = StubService(),
        searchService: SearchableCollectionProtocol = ImmediateSearchService(),
        prefetchOffsetFromEnd: Int = 0,
        searchDebounceDuration: Duration = .zero,
        onSelectUser: @escaping (UserModel) -> Void = { _ in }
    ) -> UsersViewModel {
        UsersViewModel(
            users: users,
            service: service,
            searchService: searchService,
            paginationConfiguration: UsersPaginationConfiguration(
                resultsPerPage: 1,
                maxPage: 2,
                seed: "seed",
                prefetchOffsetFromEnd: prefetchOffsetFromEnd
            ),
            searchConfiguration: SearchConfiguration(
                debounceDuration: searchDebounceDuration,
                minimumQueryLength: 3
            ),
            onSelectUser: onSelectUser
        )
    }
    
    // MARK: - fetchUsersIfNeeded: error + retry
    
    @Test
    func fetchUsersIfNeededSurfacesErrorOnFailure() async {
        let service = StubService()
        service.errorToThrow = StubService.StubError()
        let viewModel = Self.makeViewModel(service: service)
        
        await viewModel.fetchUsersIfNeeded()
        
        #expect(viewModel.isShowingError)
        #expect(viewModel.errorStatus?.message == Constants.ErrorDescription.defaultError)
        #expect(viewModel.users.isEmpty)
    }
    
    @Test
    func retryReRunsFetchUsersIfNeededAndClearsErrorOnSuccess() async {
        let service = StubService()
        service.errorToThrow = StubService.StubError()
        let viewModel = Self.makeViewModel(service: service)
        
        await viewModel.fetchUsersIfNeeded()
        #expect(viewModel.isShowingError)
        
        service.errorToThrow = nil
        service.response = UsersResponse(
            results: [Self.makeUser(id: "1")],
            info: ResponseInfo(seed: "seed", results: 1, page: 1, version: "1.4")
        )
        
        await viewModel.retry()
        
        #expect(!viewModel.isShowingError)
        #expect(viewModel.users.map(\.id) == ["1"])
    }
    
    @Test
    func clearErrorsReturnsToStateBeforeTheFailedFetch() async {
        let service = StubService()
        service.errorToThrow = StubService.StubError()
        let viewModel = Self.makeViewModel(service: service)
        
        await viewModel.fetchUsersIfNeeded()
        #expect(viewModel.isShowingError)
        
        viewModel.clearErrors()
        
        #expect(!viewModel.isShowingError)
        #expect(viewModel.users.isEmpty)
        
        let requestCountAfterClear = service.requestCount
        await viewModel.retry()
        #expect(service.requestCount == requestCountAfterClear)
        #expect(!viewModel.isShowingError)
    }
    
    @Test
    func fetchUsersIfNeededCancellationDoesNotSurfaceAsError() async {
        let gate = Gate()
        let service = StubService()
        service.gate = gate
        let viewModel = Self.makeViewModel(service: service)
        
        let task = Task { await viewModel.fetchUsersIfNeeded() }
        await gate.waitForArrivals(count: 1)
        
        task.cancel()
        await gate.open()
        await task.value
        
        #expect(viewModel.overlay == nil)
        #expect(viewModel.users.isEmpty)
    }
    
    // MARK: - prefetchNextPageIfNeeded: error + retry
    
    @Test
    func prefetchNextPageIfNeededSurfacesErrorOnFailure() async {
        let service = StubService()
        service.errorToThrow = StubService.StubError()
        let viewModel = Self.makeViewModel(users: [Self.makeUser(id: "0")], service: service)
        
        viewModel.prefetchNextPageIfNeeded(at: 0)
        await viewModel.waitForPendingWork()
        
        #expect(viewModel.isShowingError)
        #expect(viewModel.users.count == 1)
    }
    
    @Test
    func retryReRunsPrefetchNextPageIfNeededAndAppendsUsersOnSuccess() async {
        let service = StubService()
        service.errorToThrow = StubService.StubError()
        let viewModel = Self.makeViewModel(users: [Self.makeUser(id: "0")], service: service)
        
        viewModel.prefetchNextPageIfNeeded(at: 0)
        await viewModel.waitForPendingWork()
        #expect(viewModel.isShowingError)
        
        service.errorToThrow = nil
        service.response = UsersResponse(
            results: [Self.makeUser(id: "1")],
            info: ResponseInfo(seed: "seed", results: 1, page: 2, version: "1.4")
        )
        
        await viewModel.retry()
        
        #expect(!viewModel.isShowingError)
        #expect(viewModel.users.map(\.id) == ["0", "1"])
    }
    
    @Test
    func prefetchCancellationFromAConcurrentSearchDoesNotSurfaceAsError() async {
        let gate = Gate()
        let service = StubService()
        service.gate = gate
        let viewModel = Self.makeViewModel(users: [Self.makeUser(id: "0")], service: service)
        
        viewModel.prefetchNextPageIfNeeded(at: 0)
        await gate.waitForArrivals(count: 1)
        
        viewModel.searchText = "test"
        await viewModel.search()
        
        await gate.open()
        await viewModel.waitForPendingWork()
        
        #expect(!viewModel.isShowingError)
        #expect(viewModel.users.count == 1)
    }

    // MARK: - search: reads a fresh snapshot, not one taken before the debounce

    @Test
    func aCancelledSearchDoesNotPublishItsResults() async {
        let gate = Gate()
        let viewModel = Self.makeViewModel(
            users: [Self.makeUser(id: "0")],
            searchService: GatedSearchService(gate: gate)
        )

        viewModel.searchText = "abc"
        let search = Task { await viewModel.search() }
        await gate.waitForArrivals(count: 1)

        // What `.task(id: searchText)` does on the next keystroke. The matching itself has no
        // suspension point at which to notice, so it runs to completion regardless - and used to
        // publish results for a query the user had already typed over.
        search.cancel()
        await gate.open()
        await search.value

        #expect(viewModel.searchResults == nil)
        #expect(!viewModel.isShowingError)
    }

    
    @Test
    func searchReflectsUsersFetchedDuringTheDebounceWindow() async {
        let gate = Gate()
        let service = StubService()
        service.gate = gate
        service.response = UsersResponse(
            results: [Self.makeUser(id: "1")],
            info: ResponseInfo(seed: "seed", results: 1, page: 1, version: "1.4")
        )
        let viewModel = Self.makeViewModel(
            service: service,
            searchService: SearchService(),
            searchDebounceDuration: .milliseconds(200)
        )
        
        let fetchTask = Task { await viewModel.fetchUsersIfNeeded() }
        await gate.waitForArrivals(count: 1)
        
        viewModel.searchText = "1@example.com"
        let searchTask = Task { await viewModel.search() }
        
        await gate.open()
        await fetchTask.value
        await searchTask.value
        
        #expect(viewModel.searchResults?.map(\.id) == ["1"])
    }
    
    @Test
    func searchBelowTheMinimumQueryLengthClearsResultsWithoutMatching() async {
        let viewModel = Self.makeViewModel(users: [Self.makeUser(id: "0")])
        
        viewModel.searchText = "abc"
        await viewModel.search()
        #expect(viewModel.searchResults != nil)
        
        viewModel.searchText = "ab"
        await viewModel.search()
        #expect(viewModel.searchResults == nil)
    }
    
    // MARK: - loading state
    
    @Test
    func fetchingTheNextPageIsNotReportedAsBlockingLoading() async {
        let gate = Gate()
        let service = StubService()
        service.gate = gate
        let viewModel = Self.makeViewModel(users: [Self.makeUser(id: "0")], service: service)
        
        viewModel.prefetchNextPageIfNeeded(at: 0)
        await gate.waitForArrivals(count: 1)

        #expect(viewModel.footer == .loadingNextPage)
        #expect(viewModel.overlay == nil)

        await gate.open()
        await viewModel.waitForPendingWork()
    }
    
    // MARK: - pagination resumes after an interrupted fetch
    
    @Test
    func dismissingAPrefetchErrorParksPaginationInsteadOfRefiringIt() async {
        let service = StubService()
        service.errorToThrow = StubService.StubError()
        let viewModel = Self.makeViewModel(users: [Self.makeUser(id: "0")], service: service)

        viewModel.prefetchNextPageIfNeeded(at: 0)
        await viewModel.waitForPendingWork()
        #expect(viewModel.isShowingError)

        let requestCountAtFailure = service.requestCount
        viewModel.clearErrors()
        await viewModel.waitForPendingWork()

        // "OK" used to re-fire the same fetch, which failed again and put the error straight
        // back on screen - the user could never dismiss it while the failure persisted.
        #expect(service.requestCount == requestCountAtFailure)
        #expect(!viewModel.isShowingError)
        #expect(viewModel.footer == .retryNextPage)
    }

    @Test
    func aParkedPageIsNotPickedBackUpByARowAppearing() async {
        let service = StubService()
        service.errorToThrow = StubService.StubError()
        let viewModel = Self.makeViewModel(users: [Self.makeUser(id: "0")], service: service)

        viewModel.prefetchNextPageIfNeeded(at: 0)
        await viewModel.waitForPendingWork()
        viewModel.clearErrors()
        await viewModel.waitForPendingWork()

        let requestCountAfterDismissal = service.requestCount
        viewModel.prefetchNextPageIfNeeded(at: 1)
        await viewModel.waitForPendingWork()

        #expect(service.requestCount == requestCountAfterDismissal)
        #expect(!viewModel.isShowingError)
    }

    @Test
    func theFooterRetryResumesAParkedPage() async {
        let service = StubService()
        service.errorToThrow = StubService.StubError()
        let viewModel = Self.makeViewModel(users: [Self.makeUser(id: "0")], service: service)

        viewModel.prefetchNextPageIfNeeded(at: 0)
        await viewModel.waitForPendingWork()
        viewModel.clearErrors()
        await viewModel.waitForPendingWork()
        #expect(viewModel.footer == .retryNextPage)

        service.errorToThrow = nil
        service.response = UsersResponse(
            results: [Self.makeUser(id: "1")],
            info: ResponseInfo(seed: "seed", results: 1, page: 2, version: "1.4")
        )

        viewModel.retryPendingPage()
        await viewModel.waitForPendingWork()

        #expect(viewModel.users.map(\.id) == ["0", "1"])
        #expect(viewModel.footer == nil)
    }

    @Test
    func aFailureLandingAfterDismissalDoesNotReviveTheError() async {
        let gate = Gate()
        let service = StubService()
        service.gate = gate
        service.errorToThrow = StubService.StubError()
        let viewModel = Self.makeViewModel(users: [Self.makeUser(id: "0")], service: service)

        // The request is past the point of being cancellable: its real failure is already on
        // its way back when the user dismisses.
        service.ignoresCancellation = true

        viewModel.prefetchNextPageIfNeeded(at: 0)
        await gate.waitForArrivals(count: 1)

        // Previously that failure re-raised the error the user had just dismissed - often
        // while a pushed screen hid it, so it reappeared out of nowhere on the way back.
        viewModel.clearErrors()
        await gate.open()
        await viewModel.waitForPendingWork()

        #expect(!viewModel.isShowingError)
    }

    @Test
    func leavingSearchResumesThePaginationItCancelled() async {
        let gate = Gate()
        let service = StubService()
        service.gate = gate
        let viewModel = Self.makeViewModel(users: [Self.makeUser(id: "0")], service: service)
        
        viewModel.prefetchNextPageIfNeeded(at: 0)
        await gate.waitForArrivals(count: 1)
        
        viewModel.searchText = "test"
        await viewModel.search()
        
        await gate.open()
        await viewModel.waitForPendingWork()
        // The page the search interrupted never landed.
        #expect(viewModel.users.count == 1)
        
        service.gate = nil
        service.response = UsersResponse(
            results: [Self.makeUser(id: "1")],
            info: ResponseInfo(seed: "seed", results: 1, page: 2, version: "1.4")
        )
        
        viewModel.cancelSearch()
        await viewModel.waitForPendingWork()
        
        #expect(viewModel.searchResults == nil)
        #expect(viewModel.users.map(\.id) == ["0", "1"])
    }

    // MARK: - selection is a view model intent, not a view-to-coordinator shortcut

    @Test
    func selectingAUserReportsItForNavigation() {
        let spy = SelectionSpy()
        let viewModel = Self.makeViewModel(onSelectUser: spy.record)

        viewModel.select(Self.makeUser(id: "1"))

        // Previously this went straight from the row's `Button` to the coordinator, so there was
        // nothing to assert on here at all.
        #expect(spy.selected.map(\.id) == ["1"])
    }

    @Test
    func selectingUsersReportsEachOneSeparately() {
        let spy = SelectionSpy()
        let viewModel = Self.makeViewModel(onSelectUser: spy.record)

        viewModel.select(Self.makeUser(id: "1"))
        viewModel.select(Self.makeUser(id: "2"))

        #expect(spy.selected.map(\.id) == ["1", "2"])
    }

    // MARK: - status presentation: which buttons a failure is allowed to offer

    @Test
    func anInitialFetchFailureOffersRetryWithNoWayToDismissIt() async {
        let service = StubService()
        service.errorToThrow = StubService.StubError()
        let viewModel = Self.makeViewModel(service: service)

        await viewModel.fetchUsersIfNeeded()

        // Dismissing would reveal a blank screen, so retrying has to be the only way forward.
        #expect(viewModel.errorStatus?.primaryButton.action == .retryFailedFetch)
        #expect(viewModel.errorStatus?.secondaryButton == nil)
    }

    @Test
    func aPageFailureOffersBothDismissAndRetry() async {
        let service = StubService()
        service.errorToThrow = StubService.StubError()
        let viewModel = Self.makeViewModel(users: [Self.makeUser(id: "0")], service: service)

        viewModel.prefetchNextPageIfNeeded(at: 0)
        await viewModel.waitForPendingWork()

        // There is a list behind this one, so dismissing is safe - and the page is worth re-asking for.
        #expect(viewModel.errorStatus?.primaryButton.action == .dismissError)
        #expect(viewModel.errorStatus?.secondaryButton?.action == .retryFailedFetch)
    }

    @Test
    func aSearchFailureOffersNoRetryBecauseThereIsNoFetchBehindIt() async {
        let viewModel = Self.makeViewModel(
            users: [Self.makeUser(id: "0")],
            searchService: FailingSearchService()
        )

        viewModel.searchText = "abc"
        await viewModel.search()

        // "Retry" here would be a button that provably does nothing.
        #expect(viewModel.errorStatus?.primaryButton.action == .dismissError)
        #expect(viewModel.errorStatus?.secondaryButton == nil)
    }

    @Test
    func aSearchWithNoMatchesIsAnInfoStatusRatherThanAnError() async {
        let viewModel = Self.makeViewModel(
            users: [Self.makeUser(id: "0")],
            searchService: SearchService()
        )

        viewModel.searchText = "nobody@nowhere.test"
        await viewModel.search()

        guard case .empty(let status) = viewModel.content else {
            Issue.record("Expected an empty content state, got \(viewModel.content)")
            return
        }
        #expect(status.kind == .info)
        #expect(status.primaryButton.action == .clearSearchInput)
        // An empty search is not a failure, so nothing should be covering the list.
        #expect(viewModel.overlay == nil)
    }

    @Test
    func aFetchThatLegitimatelyReturnsNoUsersOffersAReload() async {
        let service = StubService()
        let viewModel = Self.makeViewModel(service: service)

        await viewModel.fetchUsersIfNeeded()

        // An empty first page used to render as a blank scroll view, and the `users.isEmpty`
        // guard meant every reappearance silently re-fetched it with nothing to show for it.
        guard case .empty(let status) = viewModel.content else {
            Issue.record("Expected an empty content state, got \(viewModel.content)")
            return
        }
        #expect(status.kind == .info)
        #expect(status.primaryButton.action == .reloadUsers)
        #expect(viewModel.overlay == nil)

        // ...and it is now a state the screen can actually get out of.
        service.response = UsersResponse(
            results: [Self.makeUser(id: "1")],
            info: ResponseInfo(seed: "seed", results: 1, page: 1, version: "1.4")
        )
        viewModel.perform(status.primaryButton.action)
        await viewModel.waitForPendingWork()

        #expect(viewModel.users.map(\.id) == ["1"])
    }

    @Test
    func performRoutesAStatusActionToTheMatchingIntent() async {
        let service = StubService()
        service.errorToThrow = StubService.StubError()
        let viewModel = Self.makeViewModel(users: [Self.makeUser(id: "0")], service: service)

        viewModel.prefetchNextPageIfNeeded(at: 0)
        await viewModel.waitForPendingWork()
        guard let dismiss = viewModel.errorStatus?.primaryButton else {
            Issue.record("Expected a dismissable error status")
            return
        }

        viewModel.perform(dismiss.action)
        await viewModel.waitForPendingWork()

        #expect(!viewModel.isShowingError)
        #expect(viewModel.footer == .retryNextPage)
    }
}

private extension UsersViewModel {
    /// The failure currently covering the screen. Keeps the assertions above reading as
    /// "is an error showing" without re-exposing a `hasError` flag on the view model itself.
    var errorStatus: Status? {
        guard case .status(let status) = overlay, status.kind == .error else { return nil }
        return status
    }

    var isShowingError: Bool {
        errorStatus != nil
    }
}
