//
//  PaginatorTests.swift
//  RandomUsersTests
//
//  Created by Alexandru Mihai on 22/07/2026.
//

import Testing
@testable import RandomUsers

@MainActor
struct PaginatorTests {
    
    private struct StubPageFetcher: PaginationFetcherProtocol {
        struct StubError: Error {}
        
        var pages: [Int: [String]] = [:]
        var errorToThrow: Error?
        var gate: Gate?
        
        func fetchPage(_ page: Int) async throws -> [String] {
            if let gate {
                await gate.wait()
            }
            if let errorToThrow {
                throw errorToThrow
            }
            return pages[page] ?? []
        }
    }
    
    @Test
    func doesNothingBeforeThePrefetchThreshold() async throws {
        let paginator = Paginator(
            fetcher: StubPageFetcher(pages: [1: ["b"]]),
            maxPage: 2,
            prefetchOffsetFromEnd: 1
        )
        
        // totalCount 5, offset 1 -> threshold index is 3; row 0 is nowhere near it.
        let result = try await paginator.prefetchNextPageIfNeeded(at: 0, totalCount: 5)
        
        #expect(result == nil)
    }
    
    @Test
    func fetchesTheNextPageAtTheThreshold() async throws {
        let paginator = Paginator(
            fetcher: StubPageFetcher(pages: [1: ["b", "c"]]),
            maxPage: 2,
            prefetchOffsetFromEnd: 1
        )
        
        let result = try await paginator.prefetchNextPageIfNeeded(at: 3, totalCount: 5)
        
        #expect(result == ["b", "c"])
    }
    
    @Test
    func fetchesWhenIndexOvershootsTheThreshold() async throws {
        let paginator = Paginator(
            fetcher: StubPageFetcher(pages: [1: ["b", "c"]]),
            maxPage: 2,
            prefetchOffsetFromEnd: 1
        )
        
        // totalCount 5, offset 1 -> threshold index is 3, but a fast scroll can skip
        // straight past it (e.g. row 3's `onAppear` never fires) to row 4. The fetch
        // must still fire rather than staying silent until the user scrolls back up.
        let result = try await paginator.prefetchNextPageIfNeeded(at: 4, totalCount: 5)
        
        #expect(result == ["b", "c"])
    }
    
    @Test
    func stopsFetchingOncePastMaxPage() async throws {
        let paginator = Paginator(
            fetcher: StubPageFetcher(pages: [1: ["b"]]),
            maxPage: 1,
            prefetchOffsetFromEnd: 0
        )
        
        _ = try await paginator.prefetchNextPageIfNeeded(at: 0, totalCount: 1)
        let result = try await paginator.prefetchNextPageIfNeeded(at: 0, totalCount: 1)
        
        #expect(result == nil)
    }
    
    @Test
    func ignoresOverlappingCallsWhileAFetchIsInFlight() async throws {
        let gate = Gate()
        let paginator = Paginator(
            fetcher: StubPageFetcher(pages: [1: ["b"]], gate: gate),
            maxPage: 2,
            prefetchOffsetFromEnd: 0
        )
        
        let firstResultTask = Task { try await paginator.prefetchNextPageIfNeeded(at: 0, totalCount: 1) }
        await gate.waitForArrivals(count: 1)
        
        let secondResult = try await paginator.prefetchNextPageIfNeeded(at: 0, totalCount: 1)
        #expect(secondResult == nil)
        
        await gate.open()
        let firstResult = try await firstResultTask.value
        
        #expect(firstResult == ["b"])
    }
    
    @Test
    func cancellingInFlightFetchSuppressesItsCompletion() async throws {
        let gate = Gate()
        let paginator = Paginator(
            fetcher: StubPageFetcher(pages: [1: ["b"]], gate: gate),
            maxPage: 2,
            prefetchOffsetFromEnd: 0
        )
        
        let resultTask = Task { try await paginator.prefetchNextPageIfNeeded(at: 0, totalCount: 1) }
        await gate.waitForArrivals(count: 1)
        
        paginator.cancelInFlightFetch()
        await gate.open()
        let result = try await resultTask.value
        
        #expect(result == nil)
    }
    
    @Test
    func cancellingInFlightFetchFreesThePaginatorImmediately() async throws {
        let gate = Gate()
        let paginator = Paginator(
            fetcher: StubPageFetcher(pages: [1: ["b"]], gate: gate),
            maxPage: 2,
            prefetchOffsetFromEnd: 0
        )

        let resultTask = Task { try await paginator.prefetchNextPageIfNeeded(at: 0, totalCount: 1) }
        await gate.waitForArrivals(count: 1)
        #expect(!paginator.shouldPrefetch(at: 0, totalCount: 1))

        paginator.cancelInFlightFetch()

        // Callers decide whether to spawn a fetch by asking synchronously, so a replacement has to
        // be startable right away. Waiting for the cancelled fetch to resume and tear itself down
        // would have the replacement rejected as a duplicate of the request just abandoned.
        #expect(paginator.shouldPrefetch(at: 0, totalCount: 1))
        #expect(!paginator.isFetchingNextPage)

        await gate.open()
        #expect(try await resultTask.value == nil)
    }

    @Test
    func nonCancellationErrorsAreReported() async {
        let paginator = Paginator(
            fetcher: StubPageFetcher(errorToThrow: StubPageFetcher.StubError()),
            maxPage: 2,
            prefetchOffsetFromEnd: 0
        )
        
        await #expect(throws: StubPageFetcher.StubError.self) {
            try await paginator.prefetchNextPageIfNeeded(at: 0, totalCount: 1)
        }
    }
}
