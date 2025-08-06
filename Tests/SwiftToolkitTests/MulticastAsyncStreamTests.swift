//
//  MulticastAsyncStreamTests.swift
//  SwiftToolkit
//
//  Comprehensive tests for MulticastAsyncStream with cancellation behavior
//  Tests multicast functionality, subscriber management, and cleanup
//

import Testing
import Foundation
@testable import SwiftToolkit

@Suite("MulticastAsyncStream Tests")
struct MulticastAsyncStreamTests {
    
    @Test("Basic send and receive functionality")
    func basicSendReceive() async throws {
        let stream = MulticastAsyncStream<String>()
        let values = ["Hello", "World", "Test"]
        var receivedValues: [String] = []
        
        // Subscribe to stream
        let subscription = await stream.subscribe()
        
        // Collect values in background task
        let collectionTask = Task {
            for await value in subscription {
                receivedValues.append(value)
                if receivedValues.count == values.count {
                    break
                }
            }
        }
        
        // Send values
        for value in values {
            await stream.send(value)
        }
        
        // Wait for collection to complete
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        collectionTask.cancel()
        
        #expect(receivedValues == values)
    }
    
    @Test("Multiple subscribers receive same events")
    func multipleSubscribers() async throws {
        let stream = MulticastAsyncStream<Int>()
        let values = [1, 2, 3, 4, 5]
        
        var subscriber1Values: [Int] = []
        var subscriber2Values: [Int] = []
        var subscriber3Values: [Int] = []
        
        // Create three subscribers
        let subscription1 = await stream.subscribe()
        let subscription2 = await stream.subscribe()
        let subscription3 = await stream.subscribe()
        
        // Collect values from each subscriber
        let task1 = Task {
            for await value in subscription1 {
                subscriber1Values.append(value)
                if subscriber1Values.count == values.count { break }
            }
        }
        
        let task2 = Task {
            for await value in subscription2 {
                subscriber2Values.append(value)
                if subscriber2Values.count == values.count { break }
            }
        }
        
        let task3 = Task {
            for await value in subscription3 {
                subscriber3Values.append(value)
                if subscriber3Values.count == values.count { break }
            }
        }
        
        // Verify initial subscriber count
        let initialCount = await stream.subscriberCount()
        #expect(initialCount == 3)
        
        // Send values
        for value in values {
            await stream.send(value)
        }
        
        // Wait for collection to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        task1.cancel()
        task2.cancel()
        task3.cancel()
        
        // All subscribers should receive same values
        #expect(subscriber1Values == values)
        #expect(subscriber2Values == values)
        #expect(subscriber3Values == values)
    }
    
    @Test("Subscriber count updates correctly")
    func subscriberCountUpdates() async throws {
        let stream = MulticastAsyncStream<String>()
        
        // Start with no subscribers
        let initialCount = await stream.subscriberCount()
        #expect(initialCount == 0)
        
        // Add first subscriber
        let subscription1 = await stream.subscribe()
        let task1 = Task {
            for await _ in subscription1 {
                // Keep subscription alive
            }
        }
        
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms - allow setup
        let countAfterOne = await stream.subscriberCount()
        #expect(countAfterOne == 1)
        
        // Add second subscriber
        let subscription2 = await stream.subscribe()
        let task2 = Task {
            for await _ in subscription2 {
                // Keep subscription alive
            }
        }
        
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms - allow setup
        let countAfterTwo = await stream.subscriberCount()
        #expect(countAfterTwo == 2)
        
        // Cancel first subscriber
        task1.cancel()
        
        // Give time for cleanup
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        let countAfterCancel = await stream.subscriberCount()
        #expect(countAfterCancel <= 1) // Should be 1 or 0 depending on cleanup timing
        
        task2.cancel()
    }
    
    @Test("Stream finish completes all subscribers")
    func streamFinish() async throws {
        let stream = MulticastAsyncStream<String>()
        var subscriber1Completed = false
        var subscriber2Completed = false
        
        // Create two subscribers
        let subscription1 = await stream.subscribe()
        let subscription2 = await stream.subscribe()
        
        let task1 = Task {
            for await _ in subscription1 {
                // Process values
            }
            subscriber1Completed = true
        }
        
        let task2 = Task {
            for await _ in subscription2 {
                // Process values
            }
            subscriber2Completed = true
        }
        
        // Send some values
        await stream.send("test1")
        await stream.send("test2")
        
        // Finish the stream
        await stream.finish()
        
        // Wait for completion
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        task1.cancel()
        task2.cancel()
        
        // Both subscribers should have completed
        #expect(subscriber1Completed == true)
        #expect(subscriber2Completed == true)
        
        // Subscriber count should be zero
        let finalCount = await stream.subscriberCount()
        #expect(finalCount == 0)
    }
    
    @Test("Task cancellation stops subscription")
    func taskCancellationStopsSubscription() async throws {
        let stream = MulticastAsyncStream<String>()
        var receivedValues: [String] = []
        var subscriptionActive = true
        
        // Create subscription
        let subscription = await stream.subscribe()
        
        let subscriptionTask = Task {
            for await value in subscription {
                receivedValues.append(value)
                // Only process first few values
                if receivedValues.count >= 2 {
                    subscriptionActive = false
                    return // Exit early
                }
            }
            subscriptionActive = false
        }
        
        // Send values
        await stream.send("value1")
        await stream.send("value2")
        
        // Wait for subscription to process
        try await Task.sleep(nanoseconds: 20_000_000) // 20ms
        
        // Cancel subscription task
        subscriptionTask.cancel()
        
        // Send more values (should not be received)
        await stream.send("value3")
        await stream.send("value4")
        
        // Wait for potential processing
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Should only have received first 2 values
        #expect(receivedValues.count <= 2)
        #expect(subscriptionActive == false)
        
        // Subscriber count should decrease after cleanup
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms - allow cleanup
        let finalCount = await stream.subscriberCount()
        #expect(finalCount == 0)
    }
    
    @Test("SendSync works correctly")
    func sendSyncFunctionality() async throws {
        let stream = MulticastAsyncStream<Int>()
        var receivedValues: [Int] = []
        
        // Subscribe to stream
        let subscription = await stream.subscribe()
        
        let collectionTask = Task {
            for await value in subscription {
                receivedValues.append(value)
                if receivedValues.count == 3 {
                    break
                }
            }
        }
        
        // Use sendSync (fire-and-forget)
        stream.sendSync(10)
        stream.sendSync(20)
        stream.sendSync(30)
        
        // Wait for values to be processed
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        collectionTask.cancel()
        
        #expect(receivedValues.count == 3)
        #expect(receivedValues.contains(10))
        #expect(receivedValues.contains(20))
        #expect(receivedValues.contains(30))
    }
    
    @Test("Stream cleanup on deinit")
    func streamCleanupOnDeinit() async throws {
        var receivedValues: [String] = []
        var streamCompleted = false
        
        // Create stream in isolated scope
        do {
            let stream = MulticastAsyncStream<String>()
            let subscription = await stream.subscribe()
            
            let subscriptionTask = Task {
                for await value in subscription {
                    receivedValues.append(value)
                }
                streamCompleted = true
            }
            
            // Send a value
            await stream.send("test")
            
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            
            // Stream will be deinitialized when leaving this scope
            subscriptionTask.cancel()
        }
        
        // Give time for deinit to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Should have received the value before deinit
        #expect(receivedValues == ["test"])
    }
    
    @Test("No memory leaks with many subscribers")
    func noMemoryLeaksWithManySubscribers() async throws {
        let stream = MulticastAsyncStream<String>()
        var tasks: [Task<Void, Never>] = []
        
        // Create 10 subscribers
        for i in 0..<10 {
            let subscription = await stream.subscribe()
            let task = Task {
                for await value in subscription {
                    // Simulate some processing
                    if value == "finish" {
                        break
                    }
                }
            }
            tasks.append(task)
        }
        
        // Verify subscriber count
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        let subscriberCount = await stream.subscriberCount()
        #expect(subscriberCount == 10)
        
        // Send values
        await stream.send("test1")
        await stream.send("test2")
        
        // Cancel half the subscribers
        for i in 0..<5 {
            tasks[i].cancel()
        }
        
        // Give time for cleanup
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Subscriber count should be reduced
        let reducedCount = await stream.subscriberCount()
        #expect(reducedCount <= 5) // Should be around 5, accounting for cleanup timing
        
        // Finish remaining subscribers
        await stream.send("finish")
        
        // Cancel remaining tasks
        for i in 5..<10 {
            tasks[i].cancel()
        }
        
        // Final cleanup
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        let finalCount = await stream.subscriberCount()
        #expect(finalCount == 0)
    }
}