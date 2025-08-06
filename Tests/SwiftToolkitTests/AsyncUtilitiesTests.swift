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

@Suite("AsyncThrottler Tests")
struct AsyncThrottlerTests {
    
    @Test("Basic throttling functionality")
    func basicThrottling() async throws {
        let throttler = tocheck__AsyncThrottler<String, Int>(defaultThrottleInterval: 0.1)
        let executionCounter = Counter()
        
        // Create operation that increments counter
        let operation = {
            await executionCounter.increment()
            return await executionCounter.value
        }
        
        // Schedule multiple operations rapidly
        let results = await withTaskGroup(of: Int.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    return try! await throttler.schedule(forKey: "test", operation: operation)
                }
            }
            
            var collectedResults: [Int] = []
            for await result in group {
                collectedResults.append(result)
            }
            return collectedResults
        }
        
        let finalCount = await executionCounter.value
        
        // All calls should get the same result (operation executed once)
        #expect(finalCount == 1, "Operation should execute only once due to throttling")
        #expect(results.allSatisfy { $0 == 1 }, "All callers should get the same result")
        #expect(results.count == 5, "All callers should receive a result")
    }
    
    @Test("Different keys execute independently")
    func differentKeysIndependent() async throws {
        let throttler = tocheck__AsyncThrottler<String, String>(defaultThrottleInterval: 0.1)
        
        let result1 = try await throttler.schedule(forKey: "key1") { "result1" }
        let result2 = try await throttler.schedule(forKey: "key2") { "result2" }
        let result3 = try await throttler.schedule(forKey: "key3") { "result3" }
        
        #expect(result1 == "result1")
        #expect(result2 == "result2") 
        #expect(result3 == "result3")
    }
    
    @Test("Custom throttle interval per operation")
    func customThrottleInterval() async throws {
        let throttler = tocheck__AsyncThrottler<String, Int>(defaultThrottleInterval: 0.5)
        let executionCounter = Counter()
        
        // Use short custom interval
        let start = Date()
        
        let results = await withTaskGroup(of: Int.self) { group in
            for _ in 0..<3 {
                group.addTask {
                    return try! await throttler.schedule(
                        forKey: "test", 
                        throttleInterval: 0.05 // Short interval
                    ) {
                        await executionCounter.increment()
                        return await executionCounter.value
                    }
                }
            }
            
            var collectedResults: [Int] = []
            for await result in group {
                collectedResults.append(result)
            }
            return collectedResults
        }
        
        let elapsed = Date().timeIntervalSince(start)
        let finalCount = await executionCounter.value
        
        #expect(finalCount == 1)
        #expect(results.allSatisfy { $0 == 1 })
        #expect(elapsed < 0.3, "Should complete quickly with short interval")
    }
    
    @Test("Error handling in throttled operations")
    func errorHandling() async throws {
        let throttler = tocheck__AsyncThrottler<String, String>(defaultThrottleInterval: 0.05)
        
        struct TestError: Error, Equatable {}
        
        // Schedule multiple operations that will throw
        let results = await withTaskGroup(of: Result<String, Error>.self) { group in
            for _ in 0..<3 {
                group.addTask {
                    do {
                        let result = try await throttler.schedule(forKey: "error-test") {
                            throw TestError()
                        }
                        return .success(result)
                    } catch {
                        return .failure(error)
                    }
                }
            }
            
            var collectedResults: [Result<String, Error>] = []
            for await result in group {
                collectedResults.append(result)
            }
            return collectedResults
        }
        
        // All should receive the same error
        #expect(results.count == 3)
        #expect(results.allSatisfy { result in
            if case .failure(let error) = result {
                return error is TestError
            }
            return false
        })
    }
    
    @Test("Cancellation for specific key")
    func cancellationForKey() async throws {
        let throttler = tocheck__AsyncThrottler<String, String>(defaultThrottleInterval: 0.2)
        
        // Start a long-running operation
        let operationTask = Task {
            do {
                return try await throttler.schedule(forKey: "cancel-test") {
                    try await Task.sleep(nanoseconds: 500_000_000) // 500ms
                    return "completed"
                }
            } catch {
                return "cancelled"
            }
        }
        
        // Give it time to start
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Cancel operations for this key
        await throttler.cancel(forKey: "cancel-test")
        
        let result = await operationTask.value
        
        // The operation should be cancelled or fail
        #expect(result == "cancelled")
    }
    
    @Test("CancelAll functionality")
    func cancelAllFunctionality() async throws {
        let throttler = tocheck__AsyncThrottler<String, String>(defaultThrottleInterval: 0.2)
        
        // Start multiple operations
        let task1 = Task {
            do {
                return try await throttler.schedule(forKey: "key1") {
                    try await Task.sleep(nanoseconds: 300_000_000) // 300ms
                    return "key1-completed"
                }
            } catch {
                return "key1-cancelled"
            }
        }
        
        let task2 = Task {
            do {
                return try await throttler.schedule(forKey: "key2") {
                    try await Task.sleep(nanoseconds: 300_000_000) // 300ms
                    return "key2-completed"
                }
            } catch {
                return "key2-cancelled"
            }
        }
        
        // Give them time to start
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Cancel all
        await throttler.cancelAll()
        
        let result1 = await task1.value
        let result2 = await task2.value
        
        // Both should be cancelled
        #expect(result1 == "key1-cancelled")
        #expect(result2 == "key2-cancelled")
    }
}

@Suite("DebounceAsync Tests")
struct DebounceAsyncTests {
    
    @Test("Basic debouncing functionality")
    func basicDebouncing() async throws {
        let debouncer = DebounceAsync()
        let executionCounter = Counter()
        
        // Schedule multiple operations rapidly
        await debouncer.schedule(after: 0.1) { await executionCounter.increment() }
        await debouncer.schedule(after: 0.1) { await executionCounter.increment() }
        await debouncer.schedule(after: 0.1) { await executionCounter.increment() }
        await debouncer.schedule(after: 0.1) { await executionCounter.increment() }
        
        // Wait for debounce to complete
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Only the last operation should execute
        let finalCount = await executionCounter.value
        #expect(finalCount == 1)
    }
    
    @Test("Debounce delay timing")
    func debounceDelayTiming() async throws {
        let debouncer = DebounceAsync()
        let executed = BooleanFlag()
        let startTime = Date()
        
        // Schedule operation with 100ms delay
        await debouncer.schedule(after: 0.1) {
            await executed.setTrue()
        }
        
        // Check that it hasn't executed immediately
        let initialState = await executed.value
        #expect(initialState == false)
        
        // Wait for execution
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms
        
        let elapsed = Date().timeIntervalSince(startTime)
        let finalState = await executed.value
        
        #expect(finalState == true)
        #expect(elapsed >= 0.1, "Should wait at least 100ms")
        #expect(elapsed < 0.2, "Should not wait too long")
    }
    
    @Test("Cancellation stops execution")
    func cancellationStopsExecution() async throws {
        let debouncer = DebounceAsync()
        let executed = BooleanFlag()
        
        // Schedule operation
        await debouncer.schedule(after: 0.1) {
            await executed.setTrue()
        }
        
        // Cancel before execution
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        await debouncer.cancel()
        
        // Wait past the original execution time
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        let finalState = await executed.value
        #expect(finalState == false, "Operation should not execute after cancellation")
    }
    
    @Test("New operation cancels previous")
    func newOperationCancelsPrevious() async throws {
        let debouncer = DebounceAsync()
        let firstExecuted = BooleanFlag()
        let secondExecuted = BooleanFlag()
        
        // Schedule first operation
        await debouncer.schedule(after: 0.1) {
            await firstExecuted.setTrue()
        }
        
        // Schedule second operation before first completes
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        await debouncer.schedule(after: 0.1) {
            await secondExecuted.setTrue()
        }
        
        // Wait for second operation to complete
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        let firstState = await firstExecuted.value
        let secondState = await secondExecuted.value
        
        #expect(firstState == false, "First operation should be cancelled")
        #expect(secondState == true, "Second operation should execute")
    }
    
    @Test("Zero delay executes immediately")
    func zeroDelayExecutesImmediately() async throws {
        let debouncer = DebounceAsync()
        let executed = BooleanFlag()
        let startTime = Date()
        
        // Schedule with zero delay
        await debouncer.schedule(after: 0) {
            await executed.setTrue()
        }
        
        // Give minimal time for execution
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        let elapsed = Date().timeIntervalSince(startTime)
        let finalState = await executed.value
        
        #expect(finalState == true)
        #expect(elapsed < 0.05, "Should execute very quickly with zero delay")
    }
    
    @Test("Multiple rapid calls with different delays")
    func multipleRapidCallsWithDifferentDelays() async throws {
        let debouncer = DebounceAsync()
        let executionOrder = StringCollector()
        
        // Schedule operations with different delays in quick succession
        await debouncer.schedule(after: 0.2) { await executionOrder.append("first") }
        await debouncer.schedule(after: 0.15) { await executionOrder.append("second") }
        await debouncer.schedule(after: 0.1) { await executionOrder.append("third") }
        await debouncer.schedule(after: 0.05) { await executionOrder.append("fourth") }
        
        // Wait for execution
        try await Task.sleep(nanoseconds: 300_000_000) // 300ms
        
        // Only the last scheduled operation should execute
        let results = await executionOrder.values
        #expect(results.count == 1)
        #expect(results.first == "fourth")
    }
    
    @Test("Synchronous cancel method")
    func synchronousCancelMethod() async throws {
        let debouncer = DebounceAsync()
        let executed = BooleanFlag()
        
        // Schedule operation
        await debouncer.schedule(after: 0.1) {
            await executed.setTrue()
        }
        
        // Use sync cancel method
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        debouncer.cancelSync()
        
        // Wait past execution time
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        let finalState = await executed.value
        #expect(finalState == false, "Operation should not execute after sync cancellation")
    }
    
    @Test("Concurrent debounce operations")
    func concurrentDebounceOperations() async throws {
        let debouncer = DebounceAsync()
        let finalValue = IntegerHolder()
        
        // Simulate rapid user input with concurrent scheduling
        await withTaskGroup(of: Void.self) { group in
            for i in 1...10 {
                group.addTask {
                    await debouncer.schedule(after: 0.05) {
                        await finalValue.setValue(i)
                    }
                    try? await Task.sleep(nanoseconds: 5_000_000) // 5ms between schedules
                }
            }
        }
        
        // Wait for final execution
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Should have the value from the last scheduled operation
        let result = await finalValue.value
        #expect(result == 10)
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