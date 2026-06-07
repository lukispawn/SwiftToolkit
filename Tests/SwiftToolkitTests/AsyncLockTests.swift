//
//  AsyncLockTests.swift
//  SwiftToolkit
//
//  Regression + stress tests for AsyncLock (single-flight coalescing, cleanup on every
//  exit, cancel reset). Guards the timing-gap fix where a stale task's cleanup must not
//  clobber a newer active task.
//

import Testing
import Foundation
@testable import SwiftToolkit

@Suite("AsyncLock Tests")
struct AsyncLockTests {

    @Test("50 concurrent callers execute the action exactly once")
    func coalescesConcurrentCallers() async throws {
        let lock = AsyncLock<Int, Error>()
        let counter = Counter()

        let results = await withTaskGroup(of: Int.self) { group in
            for _ in 0 ..< 50 {
                group.addTask {
                    (try? await lock.perform {
                        // Keep the first task in flight long enough for the rest to coalesce.
                        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
                        await counter.increment()
                        return 7
                    }) ?? -1
                }
            }
            var out: [Int] = []
            for await r in group { out.append(r) }
            return out
        }

        #expect(await counter.value == 1, "action must run exactly once for coalesced callers")
        #expect(results.count == 50, "every caller returns")
        #expect(results.allSatisfy { $0 == 7 }, "all callers receive the single shared result")
        #expect(await lock.isActive == false, "lock clears after the flight completes")
    }

    @Test("sequential perform calls each execute fresh")
    func sequentialCallsRunAgain() async throws {
        let lock = AsyncLock<Int, Error>()
        let counter = Counter()

        for _ in 0 ..< 5 {
            _ = try await lock.perform {
                await counter.increment()
                return 1
            }
        }

        #expect(await counter.value == 5, "lock must clear between sequential calls")
        #expect(await lock.isActive == false)
    }

    @Test("a failing action clears the lock; the next caller runs fresh")
    func failureClearsLock() async throws {
        struct Boom: Error {}
        let lock = AsyncLock<Int, Error>()
        let counter = Counter()

        await #expect(throws: Boom.self) {
            _ = try await lock.perform { throw Boom() }
        }

        // Must not be stuck replaying the cached failure.
        let value = try await lock.perform {
            await counter.increment()
            return 42
        }
        #expect(value == 42)
        #expect(await counter.value == 1)
        #expect(await lock.isActive == false)
    }

    @Test("cancel resets the lock and a later perform runs without clobbering")
    func cancelResetsLock() async throws {
        let lock = AsyncLock<Int, Error>()
        let counter = Counter()

        let inFlight = Task {
            try await lock.perform {
                try await Task.sleep(nanoseconds: 200_000_000) // 200ms
                await counter.increment()
                return 1
            }
        }
        // Let the task install itself as active, then cancel it mid-flight.
        try await Task.sleep(nanoseconds: 20_000_000) // 20ms
        #expect(await lock.isActive == true)
        await lock.cancel()
        _ = try? await inFlight.value

        #expect(await lock.isActive == false, "cancel clears the active task")

        // A fresh perform after cancel runs normally — the cancelled task's cleanup must
        // not have left stale state nor clobber this one.
        let v = try await lock.perform {
            await counter.increment()
            return 9
        }
        #expect(v == 9)
        #expect(await lock.isActive == false)
    }

    @Test("performNonThrowing coalesces 50 callers and clears")
    func nonThrowingCoalesces() async {
        let lock = AsyncLock<Int, Never>()
        let counter = Counter()

        let results = await withTaskGroup(of: Int.self) { group in
            for _ in 0 ..< 50 {
                group.addTask {
                    await lock.performNonThrowing {
                        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                        await counter.increment()
                        return 3
                    }
                }
            }
            var out: [Int] = []
            for await r in group { out.append(r) }
            return out
        }

        #expect(await counter.value == 1)
        #expect(results.count == 50)
        #expect(results.allSatisfy { $0 == 3 })
        #expect(await lock.isActive == false)
    }
}
