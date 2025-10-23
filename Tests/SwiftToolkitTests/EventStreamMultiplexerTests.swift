import Testing
import Foundation
@testable import SwiftToolkit

/// Standard timing constants for async test coordination
private enum TestTiming {
    static let quick: UInt64 = 10_000_000      // 10ms - minimal delays
    static let fast: UInt64 = 50_000_000       // 50ms - event coordination
}

/// Comprehensive tests for EventStreamMultiplexer multi-subscriber functionality
/// Uses proper Swift Testing confirmation patterns to avoid hanging tests
@Suite("EventStreamMultiplexer Tests", .timeLimit(.minutes(1)))
struct EventStreamMultiplexerTests {

    // MARK: - Test Event Types

    struct TestEvent: Sendable, Equatable {
        let id: String
        let timestamp: Date

        init(_ id: String) {
            self.id = id
            self.timestamp = Date()
        }
    }

    enum SimpleEvent: String, Sendable, CaseIterable {
        case started = "started"
        case progress = "progress"
        case completed = "completed"
        case failed = "failed"
    }

    // MARK: - Basic Functionality Tests

    @Test("EventStreamMultiplexer can be created and managed")
    func testMultiplexerCreation() async throws {
        let multiplexer = EventStreamMultiplexer<String>(debugPrefix: "Test")
        #expect(await multiplexer.activeStreamCount == 0)

        // Test automatic prefix
        let autoMultiplexer = EventStreamMultiplexer<String>()
        #expect(await autoMultiplexer.activeStreamCount == 0)

        // Test event emission with no subscribers
        await multiplexer.emitEvent("test")
        #expect(await multiplexer.activeStreamCount == 0)
    }

    @Test("Single subscriber receives events correctly")
    func testSingleSubscriber() async throws {
        let multiplexer = EventStreamMultiplexer<String>(debugPrefix: "SingleTest")
        let stream = await multiplexer.createEventStream()

        try await confirmation(expectedCount: 3) { confirm in
            let task = Task {
                var eventCount = 0
                for await _ in stream {
                    confirm()
                    eventCount += 1
                    if eventCount >= 3 {
                        break // Exit after receiving 3 events
                    }
                }
            }

            // Allow stream registration to complete
            try await Task.sleep(nanoseconds: TestTiming.quick)
            #expect(await multiplexer.activeStreamCount == 1)

            // Emit exactly 3 events
            await multiplexer.emitEvent("event1")
            await multiplexer.emitEvent("event2")
            await multiplexer.emitEvent("event3")

            // Wait for task to complete
            await task.value
        }

        // Clean up
        await multiplexer.cancelAllStreams()
        #expect(await multiplexer.activeStreamCount == 0)
    }

    @Test("Multiple subscribers receive same events independently")
    func testMultipleSubscribers() async throws {
        let multiplexer = EventStreamMultiplexer<SimpleEvent>()

        let stream1 = await multiplexer.createEventStream()
        let stream2 = await multiplexer.createEventStream()
        let stream3 = await multiplexer.createEventStream()

        // Allow stream registration to complete
        try await Task.sleep(nanoseconds: TestTiming.quick)

        let streamCount = await multiplexer.activeStreamCount
        #expect(streamCount == 3)

        // Expect 6 total confirmations (2 events × 3 subscribers)
        try await confirmation(expectedCount: 6) { confirm in
            let task1 = Task {
                for await _ in stream1 {
                    confirm()
                }
            }

            let task2 = Task {
                for await _ in stream2 {
                    confirm()
                }
            }

            let task3 = Task {
                for await _ in stream3 {
                    confirm()
                }
            }

            // Allow tasks to start listening
            try await Task.sleep(nanoseconds: 5_000_000) // 5ms

            await multiplexer.emitEvent(.started)

            // Allow event delivery coordination
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms

            await multiplexer.emitEvent(.progress)

            // Allow events to be received
            try await Task.sleep(nanoseconds: TestTiming.quick)

            // Clean up
            await multiplexer.cancelAllStreams()
            task1.cancel()
            task2.cancel()
            task3.cancel()
        }

        let finalCount = await multiplexer.activeStreamCount
        #expect(finalCount == 0)
    }

    // MARK: - Stream Isolation Tests

    @Test("Stream termination doesn't affect other streams")
    func testStreamIsolation() async throws {
        let multiplexer = EventStreamMultiplexer<SimpleEvent>(debugPrefix: "IsolationTest")

        let stream1 = await multiplexer.createEventStream()
        let stream2 = await multiplexer.createEventStream()

        // Wait for stream registration
        try await Task.sleep(nanoseconds: TestTiming.fast)
        #expect(await multiplexer.activeStreamCount == 2)

        // Stream1 should get 1 event, Stream2 should get 2 events = 3 total confirmations
        try await confirmation(expectedCount: 3) { confirm in
            let task1 = Task {
                for await _ in stream1 {
                    confirm()
                    break // Terminate after first event
                }
            }

            let task2 = Task {
                for await _ in stream2 {
                    confirm()
                }
            }

            // Give tasks time to start listening
            try await Task.sleep(nanoseconds: TestTiming.fast)

            // Emit first event - both streams receive it
            await multiplexer.emitEvent(.started)

            // Give task1 time to exit
            try await Task.sleep(nanoseconds: TestTiming.fast)

            // Emit second event - only stream2 should receive it
            await multiplexer.emitEvent(.progress)

            // Wait for events to be processed
            try await Task.sleep(nanoseconds: TestTiming.fast)

            // Clean up remaining stream
            await multiplexer.cancelAllStreams()
            task1.cancel()
            task2.cancel()
        }

        #expect(await multiplexer.activeStreamCount == 0)
    }

    @Test("Stream cancellation removes stream properly")
    func testStreamCancellation() async throws {
        let multiplexer = EventStreamMultiplexer<TestEvent>(debugPrefix: "CancelTest")

        let stream1 = await multiplexer.createEventStream()
        let stream2 = await multiplexer.createEventStream()

        // Wait for stream registration
        try await Task.sleep(nanoseconds: TestTiming.fast)
        #expect(await multiplexer.activeStreamCount == 2)

        // Stream1 will be cancelled after 1 event, Stream2 will get 2 events = 3 total
        try await confirmation(expectedCount: 3) { confirm in
            let task1 = Task {
                for await _ in stream1 {
                    confirm()
                }
            }

            let task2 = Task {
                for await _ in stream2 {
                    confirm()
                }
            }

            // Give tasks time to start listening
            try await Task.sleep(nanoseconds: TestTiming.fast)

            // Emit first event
            await multiplexer.emitEvent(TestEvent("before_cancel"))

            // Wait for first event to be processed
            try await Task.sleep(nanoseconds: TestTiming.fast)

            // Cancel first task (simulates subscriber disconnecting)
            task1.cancel()

            // Give time for cleanup
            try await Task.sleep(nanoseconds: TestTiming.fast)

            // Emit second event - only stream2 should receive it
            await multiplexer.emitEvent(TestEvent("after_cancel"))

            // Wait for second event to be processed
            try await Task.sleep(nanoseconds: TestTiming.fast)

            // Clean up
            await multiplexer.cancelAllStreams()
            task2.cancel()
        }

        #expect(await multiplexer.activeStreamCount == 0)
    }

    // MARK: - Edge Cases Tests

    @Test("Events emitted with no subscribers are handled gracefully")
    func testEmptySubscriberList() async throws {
        let multiplexer = EventStreamMultiplexer<SimpleEvent>(debugPrefix: "EmptyTest")

        #expect(await multiplexer.activeStreamCount == 0)

        // Should not crash or cause issues
        await multiplexer.emitEvent(.started)
        await multiplexer.emitEvent(.completed)

        #expect(await multiplexer.activeStreamCount == 0)
    }

    @Test("Cancel all streams works correctly")
    func testCancelAllStreams() async throws {
        let multiplexer = EventStreamMultiplexer<SimpleEvent>(debugPrefix: "CancelAllTest")

        let stream1 = await multiplexer.createEventStream()
        let stream2 = await multiplexer.createEventStream()
        let stream3 = await multiplexer.createEventStream()

        // Wait for stream registration
        try await Task.sleep(nanoseconds: TestTiming.quick)
        #expect(await multiplexer.activeStreamCount == 3)

        // Use expectedCount: 0 to ensure no events are received (streams cancelled before events)
        await confirmation(expectedCount: 0) { confirm in
            let task1 = Task {
                for await _ in stream1 {
                    confirm() // Should never be called
                }
            }

            let task2 = Task {
                for await _ in stream2 {
                    confirm() // Should never be called
                }
            }

            let task3 = Task {
                for await _ in stream3 {
                    confirm() // Should never be called
                }
            }

            // Cancel all streams before emitting events
            await multiplexer.cancelAllStreams()

            #expect(await multiplexer.activeStreamCount == 0)

            // These events should not reach any streams
            await multiplexer.emitEvent(.started)
            await multiplexer.emitEvent(.completed)

            task1.cancel()
            task2.cancel()
            task3.cancel()
        }

        #expect(await multiplexer.activeStreamCount == 0)
    }

    // MARK: - Concurrent Access Tests

    @Test("Concurrent stream creation and event broadcasting")
    func testConcurrentAccess() async throws {
        let multiplexer = EventStreamMultiplexer<TestEvent>(debugPrefix: "ConcurrentTest")

        // Create 3 streams
        let stream1 = await multiplexer.createEventStream()
        let stream2 = await multiplexer.createEventStream()
        let stream3 = await multiplexer.createEventStream()
        let streams = [stream1, stream2, stream3]

        // Wait for stream registration
        try await Task.sleep(nanoseconds: TestTiming.fast)
        #expect(await multiplexer.activeStreamCount == 3)

        // Expect 6 total confirmations (2 events × 3 streams)
        try await confirmation(expectedCount: 6) { confirm in
            let tasks = streams.map { stream in
                Task {
                    for await _ in stream {
                        confirm()
                    }
                }
            }

            // Give tasks time to start listening
            try await Task.sleep(nanoseconds: TestTiming.fast)

            // Emit events concurrently
            await multiplexer.emitEvent(TestEvent("concurrent1"))
            await multiplexer.emitEvent(TestEvent("concurrent2"))

            // Wait for events to be processed
            try await Task.sleep(nanoseconds: TestTiming.fast)

            // Clean up
            await multiplexer.cancelAllStreams()
            for task in tasks {
                task.cancel()
            }
        }

        #expect(await multiplexer.activeStreamCount == 0)
    }

    // MARK: - Type Safety Tests

    @Test("Different event types work independently")
    func testTypeSafety() async throws {
        let stringMultiplexer = EventStreamMultiplexer<String>(debugPrefix: "StringTest")
        let intMultiplexer = EventStreamMultiplexer<Int>(debugPrefix: "IntTest")

        let stringStream = await stringMultiplexer.createEventStream()
        let intStream = await intMultiplexer.createEventStream()

        // Wait for stream registration
        try await Task.sleep(nanoseconds: TestTiming.fast)
        #expect(await stringMultiplexer.activeStreamCount == 1)
        #expect(await intMultiplexer.activeStreamCount == 1)

        // Expect 4 total confirmations (2 string events + 2 int events)
        try await confirmation(expectedCount: 4) { confirm in
            let stringTask = Task {
                for await _ in stringStream {
                    confirm()
                }
            }

            let intTask = Task {
                for await _ in intStream {
                    confirm()
                }
            }

            // Give tasks time to start listening
            try await Task.sleep(nanoseconds: TestTiming.fast)

            // Emit different types to different multiplexers
            await stringMultiplexer.emitEvent("Hello")
            await intMultiplexer.emitEvent(42)
            await stringMultiplexer.emitEvent("World")
            await intMultiplexer.emitEvent(100)

            // Wait for events to be processed
            try await Task.sleep(nanoseconds: TestTiming.fast)

            // Clean up
            await stringMultiplexer.cancelAllStreams()
            await intMultiplexer.cancelAllStreams()
            stringTask.cancel()
            intTask.cancel()
        }

        #expect(await stringMultiplexer.activeStreamCount == 0)
        #expect(await intMultiplexer.activeStreamCount == 0)
    }

    // MARK: - Stream Lifecycle Tests

    @Test("Stream count tracking is accurate")
    func testStreamCountTracking() async throws {
        let multiplexer = EventStreamMultiplexer<String>(debugPrefix: "CountTest")

        #expect(await multiplexer.activeStreamCount == 0)

        let stream1 = await multiplexer.createEventStream()
        try await Task.sleep(nanoseconds: TestTiming.quick)
        #expect(await multiplexer.activeStreamCount == 1)

        let stream2 = await multiplexer.createEventStream()
        try await Task.sleep(nanoseconds: TestTiming.quick)
        #expect(await multiplexer.activeStreamCount == 2)

        let stream3 = await multiplexer.createEventStream()
        try await Task.sleep(nanoseconds: TestTiming.quick)
        #expect(await multiplexer.activeStreamCount == 3)

        // Start tasks to prevent immediate cleanup
        let task1 = Task { for await _ in stream1 { } }
        let task2 = Task { for await _ in stream2 { } }
        let task3 = Task { for await _ in stream3 { } }

        // Cancel individual streams
        task1.cancel()
        try await Task.sleep(nanoseconds: 10_000_000)
        try await Task.sleep(nanoseconds: TestTiming.quick)
        #expect(await multiplexer.activeStreamCount == 2)

        task2.cancel()
        try await Task.sleep(nanoseconds: 10_000_000)
        try await Task.sleep(nanoseconds: TestTiming.quick)
        #expect(await multiplexer.activeStreamCount == 1)

        task3.cancel()
        try await Task.sleep(nanoseconds: 10_000_000)
        #expect(await multiplexer.activeStreamCount == 0)
    }
}
