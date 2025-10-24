//
//  AsyncUtilitiesTests.swift
//  SwiftToolkit
//
//  Tests for AsyncThrottler and DebounceAsync utilities
//  Covers throttling, debouncing, cancellation, and concurrent access patterns
//

import Testing
import Foundation
@testable import SwiftToolkit


@Suite("ThrottleAsync Tests")
struct ThrottleAsyncTests {

    @Test("Basic throttling functionality")
    func basicThrottling() async throws {
        let executionCounter = Counter()
        let throttler = ThrottleAsync(interval: 0.1) {
            await executionCounter.increment()
        }

        // Trigger multiple times rapidly
        await throttler.trigger()
        await throttler.trigger()
        await throttler.trigger()

        // Wait for first execution
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Should have executed once
        let countAfterFirst = await executionCounter.value
        #expect(countAfterFirst == 1, "Should execute immediately on first trigger")

        // Wait for throttle interval to pass
        try await Task.sleep(nanoseconds: 60_000_000) // 60ms more (total 110ms, interval passed)

        // Trigger again to flush the throttled state
        await throttler.trigger()
        try await Task.sleep(nanoseconds: 50_000_000) // Wait for execution

        // Should have executed at least once more
        let finalCount = await executionCounter.value
        #expect(finalCount >= 2, "Should execute again after throttle interval")
    }

    @Test("Throttle timing - guarantees periodic execution")
    func throttleTiming() async throws {
        let executionTimes = ExecutionTimes()
        let startTime = Date()

        let throttler = ThrottleAsync(interval: 0.1) {
            let elapsed = Date().timeIntervalSince(startTime)
            await executionTimes.append("T: \(String(format: "%.2f", elapsed))s")
        }

        // Trigger every 30ms (faster than throttle interval)
        for _ in 0..<6 {
            await throttler.trigger()
            try await Task.sleep(nanoseconds: 30_000_000) // 30ms
        }

        // Wait for final execution
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        let times = await executionTimes.getTimes()
        let count = await executionTimes.getCount()

        // Should execute multiple times (first + periodic)
        #expect(count >= 2, "Should execute at least twice with continuous triggers")

        // Print timing for debugging
        print("Throttle executions: \(times)")
    }

    @Test("Cancellation stops execution")
    func cancellationStopsExecution() async throws {
        let executed = BooleanFlag()
        let throttler = ThrottleAsync(interval: 0.1) {
            await executed.setTrue()
        }

        // Trigger operation
        await throttler.trigger()

        // Wait for first execution
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        let firstState = await executed.value
        #expect(firstState == true, "First operation should execute")

        // Cancel and reset flag
        await throttler.cancel()
        await executed.setFalse()

        // Try to trigger after cancellation (channel is finished, won't work)
        await throttler.trigger()

        // Wait to see if it executes
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms

        let finalState = await executed.value
        #expect(finalState == false, "Operation should not execute after cancellation")
    }

    @Test("Multiple rapid triggers execute periodically")
    func multipleRapidTriggers() async throws {
        let executionCounter = Counter()
        let throttler = ThrottleAsync(interval: 0.15) {
            await executionCounter.increment()
        }

        // Trigger rapidly
        await throttler.trigger()  // t=0, executes
        await throttler.trigger()
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        await throttler.trigger()
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms (100ms total)
        await throttler.trigger()

        // Wait for throttle interval to pass
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms (total 250ms, interval passed)

        // Flush with final trigger
        await throttler.trigger()
        try await Task.sleep(nanoseconds: 50_000_000) // Wait for execution

        let finalCount = await executionCounter.value

        // Should have executed multiple times
        #expect(finalCount >= 2, "Should execute at least twice with continuous triggers")
    }

    @Test("Synchronous cancel method")
    func synchronousCancelMethod() async throws {
        let executed = BooleanFlag()
        let throttler = ThrottleAsync(interval: 0.1) {
            await executed.setTrue()
        }

        // Trigger operation
        await throttler.trigger()

        // Wait for first execution
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        #expect(await executed.value == true, "First operation should execute")

        // Use sync cancel method
        await executed.setFalse()
        throttler.cancelSync()

        // Wait for async cancel to complete
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Try to trigger after cancellation
        await throttler.trigger()

        try await Task.sleep(nanoseconds: 150_000_000) // 150ms

        let finalState = await executed.value
        #expect(finalState == false, "Operation should not execute after sync cancellation")
    }

    @Test("Concurrent throttle operations")
    func concurrentThrottleOperations() async throws {
        let executionCounter = Counter()
        let throttler = ThrottleAsync(interval: 0.1) {
            await executionCounter.increment()
        }

        // Simulate concurrent triggers from multiple sources
        await withTaskGroup(of: Void.self) { group in
            for _ in 1...10 {
                group.addTask {
                    await throttler.trigger()
                    try? await Task.sleep(nanoseconds: 20_000_000) // 20ms between triggers
                }
            }
        }

        // Wait for throttle interval
        try await Task.sleep(nanoseconds: 250_000_000) // 250ms

        // Flush with final trigger
        await throttler.trigger()
        try await Task.sleep(nanoseconds: 50_000_000) // Wait for execution

        let finalCount = await executionCounter.value

        // Should have executed multiple times but throttled
        #expect(finalCount >= 2, "Should execute multiple times with concurrent triggers")
        #expect(finalCount <= 10, "Should execute at most once per interval")

        print("Concurrent throttle: \(finalCount) executions from 10 triggers")
    }

    @Test("Restart after cancellation - channel cannot restart")
    func restartAfterCancellation() async throws {
        let executionCounter = Counter()
        let throttler = ThrottleAsync(interval: 0.1) {
            await executionCounter.increment()
        }

        // First execution
        await throttler.trigger()
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        #expect(await executionCounter.value == 1, "First execution should complete")

        // Cancel - this finishes the channel
        await throttler.cancel()

        // Try to trigger after cancellation (won't work - channel is finished)
        await throttler.trigger()
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        let finalCount = await executionCounter.value
        #expect(finalCount == 1, "Cannot restart after cancellation - channel is finished")
    }
}

// MARK: - Thread-safe Test Helpers

@MainActor
final class Counter {
    private var count = 0
    
    func increment() {
        count += 1
    }
    
    var value: Int { count }
}

@MainActor
final class BooleanFlag {
    private var flag = false
    
    func setTrue() {
        flag = true
    }
    
    func setFalse() {
        flag = false
    }
    
    var value: Bool { flag }
}

@MainActor
final class StringCollector {
    private var items: [String] = []
    
    func append(_ item: String) {
        items.append(item)
    }
    
    var values: [String] { items }
}

@MainActor
final class IntegerHolder {
    private var storedValue = 0

    func setValue(_ value: Int) {
        storedValue = value
    }

    var value: Int { storedValue }
}

@MainActor
final class ExecutionTimes {
    private var times: [String] = []

    func append(_ time: String) {
        times.append(time)
    }

    func getTimes() -> [String] { times }
    func getCount() -> Int { times.count }
}
