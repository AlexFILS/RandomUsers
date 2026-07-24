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
    
    private static func makeViewModel(
        users: [UserModel] = [],
        service: StubService = StubService(),
        searchService: SearchableCollectionProtocol = ImmediateSearchService(),
        prefetchOffsetFromEnd: Int = 0,
        searchDebounceDuration: Duration = .zero
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
            searchDebounceDuration: searchDebounceDuration
        )
    }
    
    // MARK: - fetchUsersIfNeeded: error + retry
    
    @Test
    func fetchUsersIfNeededSurfacesErrorOnFailure() async {
        let service = StubService()
        service.errorToThrow = StubService.StubError()
        let viewModel = Self.makeViewModel(service: service)
        
        await viewModel.fetchUsersIfNeeded()
        
        #expect(viewModel.hasError)
        #expect(viewModel.errorDescription == Constants.ErrorDescription.defaultError)
        #expect(viewModel.users.isEmpty)
    }
    
    @Test
    func retryReRunsFetchUsersIfNeededAndClearsErrorOnSuccess() async {
        let service = StubService()
        service.errorToThrow = StubService.StubError()
        let viewModel = Self.makeViewModel(service: service)
        
        await viewModel.fetchUsersIfNeeded()
        #expect(viewModel.hasError)
        
        service.errorToThrow = nil
        service.response = UsersResponse(
            results: [Self.makeUser(id: "1")],
            info: ResponseInfo(seed: "seed", results: 1, page: 1, version: "1.4")
        )
        
        await viewModel.retry()
        
        #expect(!viewModel.hasError)
        #expect(viewModel.users.map(\.id) == ["1"])
    }
    
    @Test
    func clearErrorsReturnsToStateBeforeTheFailedFetch() async {
        let service = StubService()
        service.errorToThrow = StubService.StubError()
        let viewModel = Self.makeViewModel(service: service)
        
        await viewModel.fetchUsersIfNeeded()
        #expect(viewModel.hasError)
        
        viewModel.clearErrors()
        
        #expect(!viewModel.hasError)
        #expect(viewModel.users.isEmpty)
        
        let requestCountAfterClear = service.requestCount
        await viewModel.retry()
        #expect(service.requestCount == requestCountAfterClear)
        #expect(!viewModel.hasError)
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
        
        #expect(!viewModel.hasError)
        #expect(!viewModel.isLoading)
        #expect(viewModel.users.isEmpty)
    }
    
    // MARK: - prefetchNextPageIfNeeded: error + retry
    
    @Test
    func prefetchNextPageIfNeededSurfacesErrorOnFailure() async {
        let service = StubService()
        service.errorToThrow = StubService.StubError()
        let viewModel = Self.makeViewModel(users: [Self.makeUser(id: "0")], service: service)
        
        await viewModel.prefetchNextPageIfNeeded(at: 0)?.value
        
        #expect(viewModel.hasError)
        #expect(viewModel.users.count == 1)
    }
    
    @Test
    func retryReRunsPrefetchNextPageIfNeededAndAppendsUsersOnSuccess() async {
        let service = StubService()
        service.errorToThrow = StubService.StubError()
        let viewModel = Self.makeViewModel(users: [Self.makeUser(id: "0")], service: service)
        
        await viewModel.prefetchNextPageIfNeeded(at: 0)?.value
        #expect(viewModel.hasError)
        
        service.errorToThrow = nil
        service.response = UsersResponse(
            results: [Self.makeUser(id: "1")],
            info: ResponseInfo(seed: "seed", results: 1, page: 2, version: "1.4")
        )
        
        await viewModel.retry()
        
        #expect(!viewModel.hasError)
        #expect(viewModel.users.map(\.id) == ["0", "1"])
    }
    
    @Test
    func prefetchCancellationFromAConcurrentSearchDoesNotSurfaceAsError() async {
        let gate = Gate()
        let service = StubService()
        service.gate = gate
        let viewModel = Self.makeViewModel(users: [Self.makeUser(id: "0")], service: service)
        
        let task = viewModel.prefetchNextPageIfNeeded(at: 0)
        await gate.waitForArrivals(count: 1)
        
        viewModel.searchText = "test"
        await viewModel.search()
        
        await gate.open()
        await task?.value
        
        #expect(!viewModel.hasError)
        #expect(viewModel.users.count == 1)
    }
    
    // MARK: - search: reads a fresh snapshot, not one taken before the debounce
    
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
            searchService: UserSearchService(),
            searchDebounceDuration: .milliseconds(200)
        )
        
        let fetchTask = Task { await viewModel.fetchUsersIfNeeded() }
        await gate.waitForArrivals(count: 1)
        
        viewModel.searchText = "1@example.com"
        let searchTask = Task { await viewModel.search() }
        
        // The fetch resolves (and populates `users`) while `search()` is still asleep
        // for its debounce. If `search()` had snapshotted `users` before sleeping, the
        // result below would be empty instead of containing the newly fetched user.
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
        
        let task = viewModel.prefetchNextPageIfNeeded(at: 0)
        await gate.waitForArrivals(count: 1)
        
        // `isLoading` drives a full-screen blur that disables the list, so paging must not
        // set it - only `isFetchingNextPage`, which renders as a footer spinner.
        #expect(viewModel.isFetchingNextPage)
        #expect(!viewModel.isLoading)
        
        await gate.open()
        await task?.value
    }
    
    // MARK: - pagination resumes after an interrupted fetch
    
    @Test
    func dismissingAPrefetchErrorParksPaginationInsteadOfRefiringIt() async {
        let service = StubService()
        service.errorToThrow = StubService.StubError()
        let viewModel = Self.makeViewModel(users: [Self.makeUser(id: "0")], service: service)

        await viewModel.prefetchNextPageIfNeeded(at: 0)?.value
        #expect(viewModel.hasError)

        let requestCountAtFailure = service.requestCount
        viewModel.clearErrors()
        await viewModel.prefetchTask?.value

        // "OK" used to re-fire the same fetch, which failed again and put the error straight
        // back on screen - the user could never dismiss it while the failure persisted.
        #expect(service.requestCount == requestCountAtFailure)
        #expect(!viewModel.hasError)
        #expect(viewModel.hasPendingPageRetry)
    }

    @Test
    func aParkedPageIsNotPickedBackUpByARowAppearing() async {
        let service = StubService()
        service.errorToThrow = StubService.StubError()
        let viewModel = Self.makeViewModel(users: [Self.makeUser(id: "0")], service: service)

        await viewModel.prefetchNextPageIfNeeded(at: 0)?.value
        viewModel.clearErrors()
        await viewModel.prefetchTask?.value

        let requestCountAfterDismissal = service.requestCount
        // Returning from another screen re-runs `onAppear` for the rows already on screen.
        await viewModel.prefetchNextPageIfNeeded(at: 1)?.value

        #expect(service.requestCount == requestCountAfterDismissal)
        #expect(!viewModel.hasError)
    }

    @Test
    func theFooterRetryResumesAParkedPage() async {
        let service = StubService()
        service.errorToThrow = StubService.StubError()
        let viewModel = Self.makeViewModel(users: [Self.makeUser(id: "0")], service: service)

        await viewModel.prefetchNextPageIfNeeded(at: 0)?.value
        viewModel.clearErrors()
        await viewModel.prefetchTask?.value
        #expect(viewModel.hasPendingPageRetry)

        service.errorToThrow = nil
        service.response = UsersResponse(
            results: [Self.makeUser(id: "1")],
            info: ResponseInfo(seed: "seed", results: 1, page: 2, version: "1.4")
        )

        // Row 0 has already appeared and will never appear again, so without this the list
        // would stay one page long forever.
        viewModel.retryPendingPage()
        await viewModel.retryTask?.value

        #expect(viewModel.users.map(\.id) == ["0", "1"])
        #expect(!viewModel.hasPendingPageRetry)
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

        let prefetch = viewModel.prefetchNextPageIfNeeded(at: 0)
        await gate.waitForArrivals(count: 1)

        // Previously that failure re-raised the error the user had just dismissed - often
        // while a pushed screen hid it, so it reappeared out of nowhere on the way back.
        viewModel.clearErrors()
        await gate.open()
        await prefetch?.value

        #expect(!viewModel.hasError)
    }

    @Test
    func leavingSearchResumesThePaginationItCancelled() async {
        let gate = Gate()
        let service = StubService()
        service.gate = gate
        let viewModel = Self.makeViewModel(users: [Self.makeUser(id: "0")], service: service)
        
        let prefetch = viewModel.prefetchNextPageIfNeeded(at: 0)
        await gate.waitForArrivals(count: 1)
        
        viewModel.searchText = "test"
        await viewModel.search()
        
        await gate.open()
        await prefetch?.value
        // The page the search interrupted never landed.
        #expect(viewModel.users.count == 1)
        
        service.gate = nil
        service.response = UsersResponse(
            results: [Self.makeUser(id: "1")],
            info: ResponseInfo(seed: "seed", results: 1, page: 2, version: "1.4")
        )
        
        viewModel.cancelSearch()
        await viewModel.prefetchTask?.value
        
        #expect(viewModel.searchResults == nil)
        #expect(viewModel.users.map(\.id) == ["0", "1"])
    }
}
