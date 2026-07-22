//
//  Gate.swift
//  RandomUsersTests
//
//  Created by Alexandru Mihai on 22/07/2026.
//

/// Test helper that lets a test control exactly when an awaited async call resumes,
/// so cancellation races can be exercised deterministically instead of via sleeps or
/// blind `Task.yield()` calls (which only prove a task *could* have run, not that it did).
actor Gate {
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var arrivalWatchers: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func wait() async {
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
            notifyArrivalWatchers()
        }
    }

    /// Suspends until at least `count` callers are parked in `wait()`. Use this to prove
    /// every task under test has actually reached the gate before calling `open()`,
    /// instead of guessing with a fixed number of yields.
    func waitForArrivals(count: Int) async {
        if continuations.count >= count { return }
        await withCheckedContinuation { continuation in
            arrivalWatchers.append((count, continuation))
        }
    }

    func open() {
        let waiters = continuations
        continuations = []
        for continuation in waiters {
            continuation.resume()
        }
    }

    private func notifyArrivalWatchers() {
        let readyCount = continuations.count
        arrivalWatchers.removeAll { watcher in
            guard readyCount >= watcher.count else { return false }
            watcher.continuation.resume()
            return true
        }
    }
}
