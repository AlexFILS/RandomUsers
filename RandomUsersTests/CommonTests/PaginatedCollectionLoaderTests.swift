//
//  PaginatedCollectionLoaderTests.swift
//  RandomUsersTests
//
//  Created by Alexandru Mihai on 25/07/2026.
//

import Testing
@testable import RandomUsers

@MainActor
struct PaginatedCollectionLoaderTests {

    private static func makeLoader(
        fetcher: StubPageFetcher = StubPageFetcher(),
        items: [Int] = [],
        prefetchOffsetFromEnd: Int = 0
    ) -> PaginatedCollectionLoader<StubPageFetcher> {
        PaginatedCollectionLoader(
            fetcher: fetcher,
            configuration: StubPaginationConfiguration(
                prefetchOffsetFromEnd: prefetchOffsetFromEnd
            ),
            items: items
        )
    }

    // MARK: - prefetchIfNeeded: no task unless a page is genuinely due

    @Test
    func aRowBelowThePrefetchThresholdStartsNoTaskAtAll() {
        let fetcher = StubPageFetcher()
        let loader = Self.makeLoader(fetcher: fetcher, items: [0, 1, 2])

        // Threshold for 3 items at offset 0 is index 2, so row 0 is nowhere near it. Returning a
        // task here would mean every row scrolled past spawns one only to discover it has nothing
        // to do - and each one silently orphans the handle to whichever task is really fetching.
        let task = loader.prefetchIfNeeded(at: 0)

        #expect(task == nil)
        #expect(fetcher.fetchCount == 0)
    }

    @Test
    func aRowAppearingDuringAnInFlightFetchStartsNoTaskAtAll() async {
        let gate = Gate()
        let fetcher = StubPageFetcher()
        fetcher.gate = gate
        let loader = Self.makeLoader(fetcher: fetcher, items: [0])

        let inFlight = loader.prefetchIfNeeded(at: 0)
        await gate.waitForArrivals(count: 1)

        // The next row appears while the page it would have asked for is already on its way.
        let duplicate = loader.prefetchIfNeeded(at: 1)
        #expect(duplicate == nil)

        // The loader must still be holding the fetch that is really running, or nothing can
        // cancel it: it was previously replaced by tasks like `duplicate` that returned
        // immediately, leaving the real one to land long after the screen had moved on.
        loader.pausePagination()
        await gate.open()
        await loader.waitForPendingWork()

        #expect(fetcher.fetchCount == 1)
        #expect(loader.items == [0])
    }

    @Test
    func aCancelledPrefetchDoesNotReportItsFailure() async {
        let gate = Gate()
        let fetcher = StubPageFetcher()
        fetcher.gate = gate
        fetcher.errorToThrow = StubPageFetcher.StubError()
        // The request fails for real, so the failure escapes as itself rather than as a
        // `CancellationError` the paginator would swallow on the way out.
        fetcher.ignoresCancellation = true
        let loader = Self.makeLoader(fetcher: fetcher, items: [0])

        let prefetch = loader.prefetchIfNeeded(at: 0)
        await gate.waitForArrivals(count: 1)

        prefetch?.cancel()
        await gate.open()
        await loader.waitForPendingWork()

        // Nobody is waiting on this page any more, so its failure is not news worth reporting.
        #expect(loader.failure == nil)
        #expect(loader.items == [0])
    }

    // MARK: - the initial page

    @Test
    func anInitialPageThatComesBackEmptyStillCountsAsLoaded() async {
        let fetcher = StubPageFetcher()
        fetcher.itemsPerPage = 0
        let loader = Self.makeLoader(fetcher: fetcher)

        await loader.loadInitialPageIfNeeded()

        // "Nothing to show" and "not asked yet" both leave `items` empty, and callers have to be
        // able to tell them apart - otherwise the load re-fires forever with nothing to show.
        #expect(loader.items.isEmpty)
        #expect(loader.hasLoadedInitialPage)

        await loader.loadInitialPageIfNeeded()
        #expect(fetcher.fetchCount == 1)
    }

    @Test
    func anInitialPageInvalidatedMidFlightIsNotPublished() async {
        let gate = Gate()
        let fetcher = StubPageFetcher()
        fetcher.gate = gate
        fetcher.ignoresCancellation = true
        let loader = Self.makeLoader(fetcher: fetcher)

        let load = Task { await loader.loadInitialPageIfNeeded() }
        await gate.waitForArrivals(count: 1)

        // The user moves on while the first page is still in the air. Its results describe a
        // list nobody is looking at any more, so they must not overwrite the current one.
        loader.dismissFailure()
        await gate.open()
        await load.value

        #expect(loader.items.isEmpty)
        #expect(!loader.hasLoadedInitialPage)
        #expect(loader.failure == nil)
    }

    @Test
    func reloadPagesFromTheStartAgain() async {
        let fetcher = StubPageFetcher()
        let loader = Self.makeLoader(fetcher: fetcher)

        await loader.loadInitialPageIfNeeded()
        loader.prefetchIfNeeded(at: 0)
        await loader.waitForPendingWork()
        #expect(loader.items == [0, 1])

        await loader.reload()

        // Not "page 2 next": a reload is a fresh collection, so the paginator has to go back to
        // the beginning rather than resume where the discarded run left off.
        #expect(loader.items == [0])
        #expect(fetcher.requestedPages == [0, 1, 0])
    }

    // MARK: - parking and resuming

    @Test
    func dismissingAPageFailureParksItForAnExplicitRetry() async {
        let fetcher = StubPageFetcher()
        fetcher.errorToThrow = StubPageFetcher.StubError()
        let loader = Self.makeLoader(fetcher: fetcher, items: [0])

        loader.prefetchIfNeeded(at: 0)
        await loader.waitForPendingWork()
        #expect(loader.failure != nil)

        loader.dismissFailure()
        #expect(loader.failure == nil)
        #expect(loader.hasParkedPage)

        // A parked page is not picked back up by a row appearing - only by asking for it.
        let fetchCountAfterDismissal = fetcher.fetchCount
        loader.prefetchIfNeeded(at: 1)
        await loader.waitForPendingWork()
        #expect(fetcher.fetchCount == fetchCountAfterDismissal)

        fetcher.errorToThrow = nil
        loader.startRetryingParkedPage()
        await loader.waitForPendingWork()

        #expect(loader.items == [0, 1])
        #expect(!loader.hasParkedPage)
    }

    @Test
    func pausingAndResumingPicksUpThePageTheLastSeenRowWouldHaveAskedFor() async {
        let gate = Gate()
        let fetcher = StubPageFetcher()
        fetcher.gate = gate
        let loader = Self.makeLoader(fetcher: fetcher, items: [0])

        loader.prefetchIfNeeded(at: 0)
        await gate.waitForArrivals(count: 1)
        loader.pausePagination()
        await gate.open()
        await loader.waitForPendingWork()
        #expect(loader.items == [0])

        // Rows appear once, so nothing else is going to ask for this page on the way back.
        fetcher.gate = nil
        loader.resumePrefetchIfNeeded()
        await loader.waitForPendingWork()

        #expect(loader.items == [0, 1])
    }
}
