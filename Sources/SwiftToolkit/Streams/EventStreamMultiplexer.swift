import Foundation
import os

// MARK: - UUID Extension for Logging

extension UUID {
    /// Short string representation (first 8 characters) for logging
    var shortString: String {
        String(uuidString.prefix(8))
    }
}

/// Generic event stream multiplexer for multi-subscriber patterns
/// Based on MockEventStreamManager architecture with consistent multi-subscriber support
///
/// This actor manages multiple independent AsyncStream subscribers for the same event type,
/// ensuring each subscriber receives all events without interference from other subscribers.
///
/// ## Usage
/// ```swift
/// let multiplexer = EventStreamMultiplexer<ReconnectionEvent>(debugPrefix: "AutoReconnect")
///
/// // Multiple subscribers can observe independently
/// let stream1 = multiplexer.createEventStream()
/// let stream2 = multiplexer.createEventStream()
///
/// // Events are broadcast to all active streams
/// await multiplexer.emitEvent(someEvent)
/// ```
///
/// ## Key Features
/// - **Multi-Subscriber Support**: Unlimited independent subscribers
/// - **Automatic Cleanup**: Streams self-remove on termination
/// - **Type Safety**: Generic implementation for any Sendable event type
/// - **Resource Efficient**: No overhead when no subscribers present
/// - **Debug Support**: Optional debug prefix with automatic EventType fallback
public actor EventStreamMultiplexer<EventType: Sendable> {

    // MARK: - Stream Registry

    /// Active event stream continuations keyed by stream ID
    /// Each entry represents an independent subscriber with its own lifecycle
    private var eventStreams: [UUID: AsyncStream<EventType>.Continuation] = [:]

    private let logger: LoggerWrapper
    private let debugPrefix: String

    // MARK: - Initialization

    /// Initialize event stream multiplexer with optional debug prefix
    /// - Parameter debugPrefix: Custom debug prefix for logging. If nil, uses EventType description
    public init(debugPrefix: String? = nil, debugEnabled: Bool = false) {
        // Smart default: use EventType description if no prefix provided
        self.debugPrefix = debugPrefix ?? String(describing: EventType.self)
        self.logger = LoggerWrapper(
            logger: .init(subsystem: "com.swifttoolkit.streams", category: "EventMultiplexer"),
            prefix: "[\(self.debugPrefix)]",
            enabled: debugEnabled
        )

        logger.log(.debug, .structuredLog(action: "multiplexer", status: "initialized", params: [("prefix", self.debugPrefix)]))
    }

    // MARK: - Stream Management

    /// Add a new event stream and return its ID
    /// - Parameters:
    ///   - streamID: Unique identifier for this stream
    ///   - continuation: AsyncStream continuation for event delivery
    /// - Returns: The stream ID for tracking purposes
    public func addEventStream(
        streamID: UUID,
        continuation: AsyncStream<EventType>.Continuation
    ) -> UUID {
        eventStreams[streamID] = continuation
        logger.log(.debug, .structuredLog(action: "multiplexer", status: "stream-added", params: [("id", streamID.shortString), ("total", "\(eventStreams.count)")]))
        return streamID
    }

    /// Remove an event stream by ID
    /// Called automatically when streams terminate or are cancelled
    /// - Parameter streamID: UUID of the stream to remove
    public func removeEventStream(streamID: UUID) {
        if eventStreams.removeValue(forKey: streamID) != nil {
            logger.log(.debug, .structuredLog(action: "multiplexer", status: "stream-removed", params: [("id", streamID.shortString), ("remaining", "\(eventStreams.count)")]))
        }
    }

    /// Emit an event to all active streams
    /// Events are broadcast to every registered continuation simultaneously
    /// - Parameter event: Event to broadcast to all subscribers
    public func emitEvent(_ event: EventType) {
        guard !eventStreams.isEmpty else {
            return
        }

        for (_, continuation) in eventStreams {
            continuation.yield(event)
        }
    }

    /// Emit an event synchronously (fire-and-forget)
    ///
    /// This is a convenience method for non-async contexts like SwiftUI button actions.
    /// Use the async `emitEvent` method when possible.
    ///
    /// ## Example
    /// ```swift
    /// Button("Trigger Event") {
    ///     multiplexer.emitEventSync(.buttonTapped)
    /// }
    /// ```
    ///
    /// - Parameter event: Event to broadcast to all subscribers
    public nonisolated func emitEventSync(_ event: EventType) {
        Task { await emitEvent(event) }
    }

    /// Cancel all event streams
    /// Useful for cleanup during shutdown or error conditions
    public func cancelAllStreams() {
        guard !eventStreams.isEmpty else {
            return
        }

        logger.log(.debug, .structuredLog(action: "multiplexer", status: "streams-cancelling", params: [("count", "\(eventStreams.count)")]))

        for (_, continuation) in eventStreams {
            continuation.finish()
        }

        eventStreams.removeAll()
    }

    /// Cancel a specific event stream by ID
    /// - Parameter streamID: UUID of the stream to cancel
    public func cancelStream(streamID: UUID) {
        if let continuation = eventStreams.removeValue(forKey: streamID) {
            continuation.finish()
        }
    }

    // MARK: - Statistics

    /// Get current number of active streams
    /// Useful for monitoring and debugging subscriber count
    public var activeStreamCount: Int {
        eventStreams.count
    }

    /// Get all active stream IDs
    /// Useful for debugging and monitoring specific subscribers
    public var activeStreamIDs: [UUID] {
        Array(eventStreams.keys)
    }
}

// MARK: - Stream Creation Extension

extension EventStreamMultiplexer {

    /// Create a new event stream for monitoring events
    /// Returns unique stream per subscriber (multi-subscriber pattern)
    ///
    /// ✅ Pattern 1: makeStream() with registration BEFORE return
    /// IMPORTANT: We must use Pattern 1 because:
    /// 1. addEventStream() involves async actor isolation
    /// 2. Pattern 2 (closure-based) could cause race condition - stream returned before continuation registered
    /// 3. Early events could be lost before registration completes
    ///
    /// Each call to this method creates an independent AsyncStream that:
    /// - Receives all events emitted after subscription
    /// - Has independent lifecycle (can be cancelled without affecting others)
    /// - Automatically cleans up when terminated
    ///
    /// - Returns: New AsyncStream for this subscriber
    public func createEventStream() -> AsyncStream<EventType> {
        let streamID = UUID()
        let (stream, continuation) = AsyncStream<EventType>.makeStream()

        // Setup automatic cleanup when stream terminates
        continuation.onTermination = { @Sendable [weak self] _ in
            Task {
                await self?.removeEventStream(streamID: streamID)
            }
        }

        // Register continuation with multiplexer (completes before return)
        _ = addEventStream(streamID: streamID, continuation: continuation)

        return stream  // ✅ Stream is fully registered and ready to receive events
    }
}
