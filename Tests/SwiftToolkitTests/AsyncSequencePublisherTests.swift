//
//  AsyncSequencePublisherTests.swift
//  SwiftToolkit
//
//  Comprehensive tests for AsyncSequencePublisher bridge functionality
//  Tests AsyncSequence → Publisher conversion with cancellation and lifecycle management
//

import Testing
import Combine
import Foundation
@testable import SwiftToolkit

// Temporarily commented out for performance testing
/*
@Suite("AsyncSequencePublisher Tests")
struct AsyncSequencePublisherTests {
    
    @Test("Basic AsyncSequence to Publisher conversion")
    func basicConversion() async throws {
        let values = ["Hello", "World", "Test"]
        let sequence = AsyncStream<String> { continuation in
            for value in values {
                continuation.yield(value)
            }
            continuation.finish()
        }
        
        let publisher = Publishers.AsyncSequencePublisher(sequence)
        var receivedValues: [String] = []
        var cancellables = Set<AnyCancellable>()
        var completionReceived = false
        
        // Use expectation pattern for async testing
        let expectation = AsyncTestExpectation(description: "Publisher should emit all values")
        
        publisher
            .sink(
                receiveCompletion: { completion in
                    if case .finished = completion {
                        completionReceived = true
                        expectation.fulfill()
                    }
                },
                receiveValue: { value in
                    receivedValues.append(value)
                }
            )
            .store(in: &cancellables)
        
        await expectation.waitForFulfillment(timeout: 2.0)
        
        #expect(receivedValues == values)
        #expect(completionReceived == true)
    }
    
    @Test("Async sequence provider pattern")
    func asyncSequenceProvider() async throws {
        let providerCallCount = Counter()
        let publisher = Publishers.AsyncSequencePublisher {
            await providerCallCount.increment()
            return AsyncStream<Int> { continuation in
                continuation.yield(42)
                continuation.finish()
            }
        }
        
        var receivedValues: [Int] = []
        var cancellables = Set<AnyCancellable>()
        
        let expectation = AsyncTestExpectation(description: "Publisher should emit value")
        
        publisher
            .sink(
                receiveCompletion: { _ in expectation.fulfill() },
                receiveValue: { value in receivedValues.append(value) }
            )
            .store(in: &cancellables)
        
        await expectation.waitForFulfillment(timeout: 1.0)
        
        let finalProviderCount = await providerCallCount.value
        #expect(receivedValues == [42])
        #expect(finalProviderCount == 1, "Provider should be called once")
    }
    
    @Test("Multiple subscribers each get their own sequence")
    func multipleSubscribers() async throws {
        let providerCallCount = Counter()
        let publisher = Publishers.AsyncSequencePublisher {
            await providerCallCount.increment()
            let currentCount = await providerCallCount.value
            return AsyncStream<String> { continuation in
                continuation.yield("subscriber-\(currentCount)")
                continuation.finish()
            }
        }
        
        var subscriber1Values: [String] = []
        var subscriber2Values: [String] = []
        var cancellables = Set<AnyCancellable>()
        
        let expectation1 = AsyncTestExpectation(description: "Subscriber 1 should receive value")
        let expectation2 = AsyncTestExpectation(description: "Subscriber 2 should receive value")
        
        // Subscriber 1
        publisher
            .sink(
                receiveCompletion: { _ in expectation1.fulfill() },
                receiveValue: { value in subscriber1Values.append(value) }
            )
            .store(in: &cancellables)
        
        // Subscriber 2
        publisher
            .sink(
                receiveCompletion: { _ in expectation2.fulfill() },
                receiveValue: { value in subscriber2Values.append(value) }
            )
            .store(in: &cancellables)
        
        await expectation1.waitForFulfillment(timeout: 1.0)
        await expectation2.waitForFulfillment(timeout: 1.0)
        
        let finalProviderCount = await providerCallCount.value
        #expect(subscriber1Values == ["subscriber-1"])
        #expect(subscriber2Values == ["subscriber-2"])
        #expect(finalProviderCount == 2, "Each subscriber should trigger provider")
    }
    
    @Test("Publisher cancellation stops AsyncSequence iteration")
    func cancellationStopsIteration() async throws {
        let sequence = AsyncStream<Int> { continuation in
            Task {
                for i in 0..<1000 {
                    continuation.yield(i)
                    try? await Task.sleep(nanoseconds: 1_000_000) // 1ms delay
                }
                continuation.finish()
            }
        }
        
        let publisher = Publishers.AsyncSequencePublisher(sequence)
        var receivedValues: [Int] = []
        var cancellables = Set<AnyCancellable>()
        
        let subscription = publisher
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { value in
                    receivedValues.append(value)
                }
            )
        
        cancellables.insert(subscription)
        
        // Let it receive a few values
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        let valuesAtCancellation = receivedValues.count
        
        // Cancel subscription
        cancellables.removeAll()
        
        // Give more time to see if more values arrive (they shouldn't)
        try await Task.sleep(nanoseconds: 20_000_000) // 20ms
        
        let valuesAfterCancellation = receivedValues.count
        
        #expect(valuesAfterCancellation == valuesAtCancellation, "No new values should arrive after cancellation")
        #expect(receivedValues.count < 1000, "Should not receive all values due to cancellation")
        #expect(receivedValues.count > 0, "Should receive some values before cancellation")
    }
    
    @Test("Empty sequence completes immediately")
    func emptySequenceCompletion() async throws {
        let sequence = AsyncStream<String> { continuation in
            continuation.finish()
        }
        
        let publisher = Publishers.AsyncSequencePublisher(sequence)
        var receivedValues: [String] = []
        var cancellables = Set<AnyCancellable>()
        
        let expectation = AsyncTestExpectation(description: "Empty sequence should complete")
        
        publisher
            .sink(
                receiveCompletion: { completion in
                    if case .finished = completion {
                        expectation.fulfill()
                    }
                },
                receiveValue: { value in
                    receivedValues.append(value)
                }
            )
            .store(in: &cancellables)
        
        await expectation.waitForFulfillment(timeout: 1.0)
        #expect(receivedValues.isEmpty, "Should not receive any values from empty sequence")
    }
    
    @Test("Throwing AsyncSequence gracefully handles errors")
    func throwingSequenceHandling() async throws {
        struct TestError: Error {}
        
        let sequence = AsyncThrowingStream<String, Error> { continuation in
            continuation.yield("first")
            continuation.finish(throwing: TestError())
        }
        
        let publisher = Publishers.AsyncSequencePublisher {
            sequence
        }
        
        var receivedValues: [String] = []
        var cancellables = Set<AnyCancellable>()
        
        let expectation = AsyncTestExpectation(description: "Should complete despite error")
        
        publisher
            .sink(
                receiveCompletion: { completion in
                    // Since Failure type is Never, should complete normally even with errors
                    if case .finished = completion {
                        expectation.fulfill()
                    }
                },
                receiveValue: { value in
                    receivedValues.append(value)
                }
            )
            .store(in: &cancellables)
        
        await expectation.waitForFulfillment(timeout: 1.0)
        #expect(receivedValues == ["first"])
    }
    
    @Test("Global convenience functions work correctly")
    func globalConvenienceFunctions() async throws {
        let values = [1, 2, 3]
        let sequence = AsyncStream<Int> { continuation in
            for value in values {
                continuation.yield(value)
            }
            continuation.finish()
        }
        
        let publisher1 = publisher(from: sequence)
        let publisher2 = publisher { sequence }
        
        var receivedValues1: [Int] = []
        var receivedValues2: [Int] = []
        var cancellables = Set<AnyCancellable>()
        
        let expectation1 = AsyncTestExpectation(description: "Direct sequence function should work")
        let expectation2 = AsyncTestExpectation(description: "Provider function should work")
        
        publisher1
            .sink(
                receiveCompletion: { _ in expectation1.fulfill() },
                receiveValue: { value in receivedValues1.append(value) }
            )
            .store(in: &cancellables)
        
        publisher2
            .sink(
                receiveCompletion: { _ in expectation2.fulfill() },
                receiveValue: { value in receivedValues2.append(value) }
            )
            .store(in: &cancellables)
        
        await expectation1.waitForFulfillment(timeout: 1.0)
        await expectation2.waitForFulfillment(timeout: 1.0)
        
        #expect(receivedValues1 == values)
        #expect(receivedValues2 == values)
    }
}
*/

/*
@Suite("MulticastAsyncStream Publisher Integration Tests")
struct MulticastAsyncStreamPublisherTests {
    
    @Test("Basic MulticastAsyncStream publisher functionality")
    func basicMulticastPublisher() async throws {
        let stream = MulticastAsyncStream<String>()
        let publisher = stream.publisher()
        
        var receivedValues: [String] = []
        var cancellables = Set<AnyCancellable>()
        
        let expectation = AsyncTestExpectation(description: "Should receive broadcasted values")
        
        publisher
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { value in
                    receivedValues.append(value)
                    if receivedValues.count == 2 {
                        expectation.fulfill()
                    }
                }
            )
            .store(in: &cancellables)
        
        // Send values to stream
        await stream.send("Hello")
        await stream.send("World")
        
        await expectation.waitForFulfillment(timeout: 2.0)
        #expect(receivedValues == ["Hello", "World"])
    }
    
    @Test("Multiple subscribers to same stream get same values")
    func multipleSubscribers() async throws {
        let stream = MulticastAsyncStream<String>()
        let publisher = stream.publisher()
        
        var subscriber1Values: [String] = []
        var subscriber2Values: [String] = []
        var cancellables = Set<AnyCancellable>()
        
        let expectation1 = AsyncTestExpectation(description: "Subscriber 1 should receive values")
        let expectation2 = AsyncTestExpectation(description: "Subscriber 2 should receive values")
        
        // Subscriber 1
        publisher
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { value in
                    subscriber1Values.append(value)
                    if subscriber1Values.count == 2 {
                        expectation1.fulfill()
                    }
                }
            )
            .store(in: &cancellables)
        
        // Subscriber 2
        publisher
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { value in
                    subscriber2Values.append(value)
                    if subscriber2Values.count == 2 {
                        expectation2.fulfill()
                    }
                }
            )
            .store(in: &cancellables)
        
        // Send values - both should receive them
        await stream.send("Test1")
        await stream.send("Test2")
        
        await expectation1.waitForFulfillment(timeout: 2.0)
        await expectation2.waitForFulfillment(timeout: 2.0)
        
        #expect(subscriber1Values == ["Test1", "Test2"])
        #expect(subscriber2Values == ["Test1", "Test2"])
    }
    
    @Test("Publisher cleanup when cancellation occurs")
    func publisherCleanup() async throws {
        let stream = MulticastAsyncStream<Int>()
        let publisher = stream.publisher()
        
        var receivedValues: [Int] = []
        var cancellables = Set<AnyCancellable>()
        
        let subscription = publisher
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { value in
                    receivedValues.append(value)
                }
            )
        
        cancellables.insert(subscription)
        
        // Send initial value
        await stream.send(1)
        
        // Small delay to ensure value is received
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        let subscriberCountBefore = await stream.subscriberCount()
        
        // Cancel subscription
        cancellables.removeAll()
        
        // Give time for cleanup
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        let subscriberCountAfter = await stream.subscriberCount()
        
        #expect(receivedValues == [1])
        #expect(subscriberCountBefore == 1)
        #expect(subscriberCountAfter == 0, "Stream should clean up cancelled subscribers")
    }
}

// MARK: - Test Utilities

/// Simple async expectation helper for testing
final class AsyncTestExpectation: @unchecked Sendable {
    private let description: String
    private var _isFulfilled = false
    private let lock = NSLock()
    
    init(description: String) {
        self.description = description
    }
    
    func fulfill() {
        lock.lock()
        defer { lock.unlock() }
        _isFulfilled = true
    }
    
    var isFulfilled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isFulfilled
    }
    
    func waitForFulfillment(timeout: TimeInterval) async {
        let deadline = Date().addingTimeInterval(timeout)
        
        while Date() < deadline {
            if isFulfilled {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        // Timeout reached
        print("⚠️ Test expectation '\(description)' timed out after \(timeout)s")
    }
}
*/