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

    private struct StubPageFetcher: PagnationFetcherProtocol {
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
    func doesNothingBeforeThePrefetchThreshold() async {
        let paginator = Paginator(
            fetcher: StubPageFetcher(pages: [1: ["b"]]),
            maxPage: 2,
            prefetchOffsetFromEnd: 1
        )

        var completionCalled = false
        // totalCount 5, offset 1 -> threshold index is 3; row 0 is nowhere near it.
        paginator.prefetchNextPageIfNeeded(at: 0, totalCount: 5) { _ in completionCalled = true }

        await Task.yield()
        #expect(completionCalled == false)
    }

    @Test
    func fetchesTheNextPageAtTheThreshold() async throws {
        let paginator = Paginator(
            fetcher: StubPageFetcher(pages: [1: ["b", "c"]]),
            maxPage: 2,
            prefetchOffsetFromEnd: 1
        )

        let result = await withCheckedContinuation { continuation in
            paginator.prefetchNextPageIfNeeded(at: 3, totalCount: 5) { result in
                continuation.resume(returning: result)
            }
        }

        try #expect(result.get() == ["b", "c"])
    }

    @Test
    func stopsFetchingOncePastMaxPage() async {
        let paginator = Paginator(
            fetcher: StubPageFetcher(pages: [1: ["b"]]),
            maxPage: 1,
            prefetchOffsetFromEnd: 0
        )

        _ = await withCheckedContinuation { continuation in
            paginator.prefetchNextPageIfNeeded(at: 0, totalCount: 1) { result in
                continuation.resume(returning: result)
            }
        }

        var completionCalled = false
        paginator.prefetchNextPageIfNeeded(at: 0, totalCount: 1) { _ in completionCalled = true }

        await Task.yield()
        #expect(completionCalled == false)
    }

    @Test
    func ignoresOverlappingCallsWhileAFetchIsInFlight() async {
        let gate = Gate()
        let paginator = Paginator(
            fetcher: StubPageFetcher(pages: [1: ["b"]], gate: gate),
            maxPage: 2,
            prefetchOffsetFromEnd: 0
        )

        var firstCompletionCount = 0
        paginator.prefetchNextPageIfNeeded(at: 0, totalCount: 1) { _ in firstCompletionCount += 1 }
        await gate.waitForArrivals(count: 1)

        var secondCompletionCalled = false
        paginator.prefetchNextPageIfNeeded(at: 0, totalCount: 1) { _ in secondCompletionCalled = true }

        await gate.open()
        await Task.yield()
        await Task.yield()

        #expect(firstCompletionCount == 1)
        #expect(secondCompletionCalled == false)
    }

    @Test
    func cancellingInFlightFetchSuppressesItsCompletion() async {
        let gate = Gate()
        let paginator = Paginator(
            fetcher: StubPageFetcher(pages: [1: ["b"]], gate: gate),
            maxPage: 2,
            prefetchOffsetFromEnd: 0
        )

        var completionCalled = false
        paginator.prefetchNextPageIfNeeded(at: 0, totalCount: 1) { _ in completionCalled = true }
        await gate.waitForArrivals(count: 1)

        paginator.cancelInFlightFetch()
        await gate.open()
        await Task.yield()
        await Task.yield()

        #expect(completionCalled == false)
    }

    @Test
    func nonCancellationErrorsAreReported() async {
        let paginator = Paginator(
            fetcher: StubPageFetcher(errorToThrow: StubPageFetcher.StubError()),
            maxPage: 2,
            prefetchOffsetFromEnd: 0
        )

        let result = await withCheckedContinuation { continuation in
            paginator.prefetchNextPageIfNeeded(at: 0, totalCount: 1) { result in
                continuation.resume(returning: result)
            }
        }

        #expect(throws: StubPageFetcher.StubError.self) { try result.get() }
    }
}
