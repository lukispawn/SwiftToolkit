import Foundation
import AsyncAlgorithms

// MARK: - AsyncAlgorithms Extensions

/// AsyncAlgorithms integration for EventStreamMultiplexer
/// Provides convenient stream processing capabilities like filtering, throttling, debouncing, etc.
extension EventStreamMultiplexer {

    /// Filter events using a predicate
    ///
    /// Creates a new stream that only emits events matching the provided predicate.
    ///
    /// ## Example
    /// ```swift
    /// let errorStream = await multiplexer.filteredStream { event in
    ///     if case .error = event { return true }
    ///     return false
    /// }
    /// ```
    ///
    /// - Parameter isIncluded: Closure that returns true for events to include
    /// - Returns: Filtered async sequence
    public func filteredStream(
        _ isIncluded: @Sendable @escaping (EventType) -> Bool
    ) -> AsyncFilterSequence<AsyncStream<EventType>> {
        createEventStream().filter(isIncluded)
    }

    /// Throttle events - emit at most one event per interval
    ///
    /// Creates a stream that limits the rate of events to one per specified interval.
    ///
    /// ## Example
    /// ```swift
    /// // Emit at most one event per second
    /// let throttled = await multiplexer.throttledStream(for: .seconds(1))
    /// ```
    ///
    /// - Parameters:
    ///   - interval: Minimum time between emitted events
    ///   - latest: If true, emits the most recent event; if false, emits the first
    /// - Returns: Throttled async sequence
    public func throttledStream(
        for interval: Duration,
        latest: Bool = true
    ) -> AsyncThrottleSequence<AsyncStream<EventType>, ContinuousClock, EventType> {
        createEventStream().throttle(for: interval, latest: latest)
    }

    /// Debounce events - emit only after a period of inactivity
    ///
    /// Creates a stream that only emits events after the specified interval of inactivity.
    ///
    /// ## Example
    /// ```swift
    /// // Only emit after 500ms of no events
    /// let debounced = await multiplexer.debouncedStream(for: .milliseconds(500))
    /// ```
    ///
    /// - Parameter interval: Duration of inactivity required before emitting
    /// - Returns: Debounced async sequence
    public func debouncedStream(
        for interval: Duration
    ) -> AsyncDebounceSequence<AsyncStream<EventType>, ContinuousClock> {
        createEventStream().debounce(for: interval)
    }

    /// Remove duplicate consecutive events
    ///
    /// Creates a stream that filters out consecutive duplicate events.
    ///
    /// ## Example
    /// ```swift
    /// let unique = await multiplexer.removeDuplicatesStream()
    /// ```
    ///
    /// - Returns: Async sequence without consecutive duplicates
    public func removeDuplicatesStream() -> AsyncRemoveDuplicatesSequence<AsyncStream<EventType>> where EventType: Equatable {
        createEventStream().removeDuplicates()
    }

    /// Compact map events (transform and filter nil results)
    ///
    /// Creates a stream that transforms events and filters out nil results.
    ///
    /// ## Example
    /// ```swift
    /// let userIDs = await multiplexer.compactMappedStream { event in
    ///     event.userID
    /// }
    /// ```
    ///
    /// - Parameter transform: Closure that transforms events to optional values
    /// - Returns: Compact mapped async sequence
    public func compactMappedStream<T>(
        _ transform: @Sendable @escaping (EventType) async -> T?
    ) -> AsyncCompactMapSequence<AsyncStream<EventType>, T> {
        createEventStream().compactMap(transform)
    }

    /// Convenience overload for sync transforms.
    public func compactMappedStream<T>(
        _ transform: @Sendable @escaping (EventType) -> T?
    ) -> AsyncCompactMapSequence<AsyncStream<EventType>, T> {
        createEventStream().compactMap { event in
            transform(event)
        }
    }

    /// Merge events from two multiplexers of the same event type
    ///
    /// Creates a stream that emits events from both multiplexers as they occur.
    ///
    /// ## Example
    /// ```swift
    /// let combined = await EventStreamMultiplexer.merge(multiplexer1, multiplexer2)
    /// ```
    ///
    /// - Parameters:
    ///   - multiplexer1: First event multiplexer
    ///   - multiplexer2: Second event multiplexer
    /// - Returns: Merged async sequence
    public static func merge(
        _ multiplexer1: EventStreamMultiplexer<EventType>,
        _ multiplexer2: EventStreamMultiplexer<EventType>
    ) async -> AsyncMerge2Sequence<AsyncStream<EventType>, AsyncStream<EventType>> {
        await AsyncAlgorithms.merge(multiplexer1.createEventStream(), multiplexer2.createEventStream())
    }

    /// Combine latest events from two multiplexers
    ///
    /// Creates a stream that emits a tuple whenever either multiplexer emits a new event,
    /// combining it with the most recent event from the other multiplexer.
    ///
    /// ## Example
    /// ```swift
    /// let combined = await EventStreamMultiplexer.combineLatest(multiplexer1, multiplexer2)
    /// for await (event1, event2) in combined {
    ///     // Process combined events
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - multiplexer1: First event multiplexer
    ///   - multiplexer2: Second event multiplexer
    /// - Returns: Combined latest async sequence
    public static func combineLatest<E1, E2>(
        _ multiplexer1: EventStreamMultiplexer<E1>,
        _ multiplexer2: EventStreamMultiplexer<E2>
    ) async -> AsyncCombineLatest2Sequence<AsyncStream<E1>, AsyncStream<E2>> {
        await AsyncAlgorithms.combineLatest(multiplexer1.createEventStream(), multiplexer2.createEventStream())
    }

    /// Zip events from two multiplexers
    ///
    /// Creates a stream that pairs events from both multiplexers in order.
    ///
    /// ## Example
    /// ```swift
    /// let zipped = await EventStreamMultiplexer.zip(multiplexer1, multiplexer2)
    /// for await (event1, event2) in zipped {
    ///     // Process paired events
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - multiplexer1: First event multiplexer
    ///   - multiplexer2: Second event multiplexer
    /// - Returns: Zipped async sequence
    public static func zip<E1, E2>(
        _ multiplexer1: EventStreamMultiplexer<E1>,
        _ multiplexer2: EventStreamMultiplexer<E2>
    ) async -> AsyncZip2Sequence<AsyncStream<E1>, AsyncStream<E2>> {
        await AsyncAlgorithms.zip(multiplexer1.createEventStream(), multiplexer2.createEventStream())
    }
}
