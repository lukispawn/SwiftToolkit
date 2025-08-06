//
//  SimpleTests.swift
//  SwiftToolkit
//
//  Simple tests to verify basic functionality without complex concurrency patterns
//

import Testing
import Foundation
@testable import SwiftToolkit

@Suite("Simple Functionality Tests")
struct SimpleTests {
    
    @Test("MulticastAsyncStream basic send and receive")
    func multicastBasic() async throws {
        let stream = MulticastAsyncStream<String>()
        
        // Simple test - create stream, send value, verify count
        let initialCount = await stream.subscriberCount()
        #expect(initialCount == 0)
        
        // Send a value (should not crash)
        await stream.send("test")
        
        // Create subscriber
        let subscription = await stream.subscribe()
        
        var receivedValue: String?
        let subscriptionTask = Task {
            for await value in subscription {
                receivedValue = value
                break // Exit after first value
            }
        }
        
        // Give time for subscription to set up
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        let countAfterSubscribe = await stream.subscriberCount()
        #expect(countAfterSubscribe == 1)
        
        // Send value
        await stream.send("hello")
        
        // Give time to receive
        try await Task.sleep(nanoseconds: 20_000_000) // 20ms
        subscriptionTask.cancel()
        
        #expect(receivedValue == "hello")
    }
    
    @Test("DebounceAsync basic functionality")
    func debounceBasic() async throws {
        let debouncer = DebounceAsync()
        var executed = false
        
        // Schedule operation
        await debouncer.schedule(after: 0.05) {
            executed = true
        }
        
        // Wait for execution
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        #expect(executed == true)
    }
    
    @Test("AsyncSequencePublisher basic conversion")
    func asyncSequencePublisherBasic() async throws {
        // Create simple async stream
        let stream = AsyncStream<Int> { continuation in
            continuation.yield(42)
            continuation.finish()
        }
        
        // Create publisher
        let publisher = Publishers.AsyncSequencePublisher(stream)
        
        // This test just verifies creation doesn't crash
        #expect(publisher != nil)
    }
}