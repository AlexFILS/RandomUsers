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
    
    // MARK: - Test doubles
    
    /// Stands in for `NetworkingClient`. Only ever asked to decode `UsersResponse`,
    /// mirroring the ViewModel's and `UserPageFetcher`'s actual usage.
    private final class StubService: ServiceProtocol {
        struct StubError: Error, Equatable {}
        
        var response = UsersResponse(results: [], info: ResponseInfo(seed: "seed", results: 0, page: 0, version: "1.4"))
        var errorToThrow: Error?
        var gate: Gate?
        private(set) var requestCount = 0
        
        func request<Response: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> Response {
            requestCount += 1
            if let gate {
                await gate.wait()
                try Task.checkCancellation()
            }
            if let errorToThrow {
                throw errorToThrow
            }
            guard let typedResponse = response as? Response else {
                fatalError("StubService only supports decoding UsersResponse")
            }
            return typedResponse
        }
    }
    
    private struct ImmediateSearchService: SearchableCollectionProtocol {
        func search<T: SearchableModelProtocol>(query: String, in elements: [T]) async throws -> [T] {
            elements
        }
    }
    
    private static func makeUser(id: String) -> User {
        User(
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
        users: [User] = [],
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
        #expect(viewModel.errorDescription == Constants.ErrorDescription.defaultError.rawValue)
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
        let gate = Gate()
        let service = StubService()
        service.gate = gate
        service.errorToThrow = StubService.StubError()
        let viewModel = Self.makeViewModel(users: [Self.makeUser(id: "0")], service: service)
        
        viewModel.prefetchNextPageIfNeeded(at: 0)
        await gate.waitForArrivals(count: 1)
        await gate.open()
        await Task.yield()
        await Task.yield()
        
        #expect(viewModel.hasError)
        #expect(viewModel.users.count == 1)
    }
    
    @Test
    func retryReRunsPrefetchNextPageIfNeededAndAppendsUsersOnSuccess() async {
        let gate = Gate()
        let service = StubService()
        service.gate = gate
        service.errorToThrow = StubService.StubError()
        let viewModel = Self.makeViewModel(users: [Self.makeUser(id: "0")], service: service)
        
        viewModel.prefetchNextPageIfNeeded(at: 0)
        await gate.waitForArrivals(count: 1)
        await gate.open()
        await Task.yield()
        await Task.yield()
        #expect(viewModel.hasError)
        
        service.errorToThrow = nil
        service.response = UsersResponse(
            results: [Self.makeUser(id: "1")],
            info: ResponseInfo(seed: "seed", results: 1, page: 2, version: "1.4")
        )
        
        await viewModel.retry()
        await gate.waitForArrivals(count: 1)
        await gate.open()
        await Task.yield()
        await Task.yield()
        
        #expect(!viewModel.hasError)
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
        await Task.yield()
        await Task.yield()
        
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
}
