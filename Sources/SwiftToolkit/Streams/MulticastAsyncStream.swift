//  Helpers.swift
//  APIConnectKit
//
//  Created by Lukasz Zajdel on 09/05/2025.
//

import AsyncAlgorithms
import Foundation

/// Improved MulticastAsyncStream with proper cleanup and no memory leaks
/// Uses AsyncStream with continuation tracking for automatic cleanup
/// Each subscriber gets their own stream - works like NotificationCenter
public final actor MulticastAsyncStream<Event: Sendable>: Sendable {

    private struct StreamInfo {
        let id: UUID
        let continuation: AsyncStream<Event>.Continuation
        var isFinished: Bool = false
    }
    
    private var streams: [UUID: StreamInfo] = [:]
    private let logger: LoggerWrapper?
    
    public init(logger: LoggerWrapper? = nil) {
        self.logger = logger
        logger?.debug("Initialized")
    }
    
    deinit {
        logger?.debug("Deinitializing - finishing all streams")
        for (_, streamInfo) in streams {
            if !streamInfo.isFinished {
                streamInfo.continuation.finish()
            }
        }
        streams.removeAll()
    }
    
    /// Send an event to all active subscribers (non-blocking multicast)
    public func send(_ event: Event) {
        logger?.debug("Sending event to \(activeStreamCount()) active subscribers")
        
        // Clean up finished streams first
        cleanupFinishedStreams()
        
        // Send to all active subscribers
        for (_, streamInfo) in streams {
            if !streamInfo.isFinished {
                streamInfo.continuation.yield(event)
            }
        }
    }
    
    /// Send an event synchronously (fire-and-forget)
    public nonisolated func sendSync(_ event: Event) {
        Task { await send(event) }
    }
    
    /// Create a new subscriber stream (each subscriber gets their own stream)
    private func createStream() -> AsyncStream<Event> {
        let id = UUID()
        
        return AsyncStream<Event> { continuation in
            Task { [weak self] in
                await self?.addStream(id: id, continuation: continuation)
                
                // Setup cleanup when continuation is finished
                continuation.onTermination = { [weak self] _ in
                    Task { [weak self] in
                        await self?.markStreamAsFinished(id: id)
                        await self?.removeSubscriber(id: id)
                    }
                }
            }
        }
    }

    /// Type-erased sequence access
    public  func subscribe()  -> AsyncStream<Event> {
        return  createStream()
    }
    
    
    
    /// Finish all subscribers (no more events will be sent)
    public func finish() {
        logger?.debug("Finishing all \(streams.count) subscribers")
        for (_, streamInfo) in streams {
            if !streamInfo.isFinished {
                streamInfo.continuation.finish()
            }
        }
        streams.removeAll()
    }
    
    /// Get current active subscriber count
    public func subscriberCount() -> Int {
        return activeStreamCount()
    }
    
    // MARK: - Private Methods
    
    private func addStream(id: UUID, continuation: AsyncStream<Event>.Continuation) {
        let streamInfo = StreamInfo(id: id, continuation: continuation)
        streams[id] = streamInfo
        logger?.debug("New subscriber created, total: \(streams.count)")
    }
    
    private func markStreamAsFinished(id: UUID) {
        if var streamInfo = streams[id] {
            streamInfo.isFinished = true
            streams[id] = streamInfo
            logger?.debug("Stream \(id) marked as finished")
        }
    }
    
    private func cleanupFinishedStreams() {
        let originalCount = streams.count
        streams = streams.filter { !$0.value.isFinished }
        let removedCount = originalCount - streams.count
        
        if removedCount > 0 {
            logger?.debug("Cleaned up \(removedCount) finished streams, remaining: \(streams.count)")
        }
    }
    
    private func removeSubscriber(id: UUID) {
        streams.removeValue(forKey: id)
        logger?.debug("Stream \(id) removed, remaining: \(streams.count)")
    }
    
    private func activeStreamCount() -> Int {
        return streams.values.filter { !$0.isFinished }.count
    }
}


public extension MulticastAsyncStream {
    
    func filteredStream(
        _ isIncluded: @Sendable @escaping (Event) -> Bool
    )  ->  AsyncFilterSequence<AsyncStream<Event>> {
        createStream().filter(isIncluded)
    }
    
    /// Throttle events - emit at most one event per interval
    func throttledStream(
        for interval: Duration,
        latest: Bool = true
    ) -> AsyncThrottleSequence<AsyncStream<Event>, ContinuousClock, Event> {
        
        return createStream().throttle(for: interval, latest: latest)
    }
    
    /// Debounce events - emit only after a period of inactivity
    func debouncedStream(
        for interval: Duration
    ) -> AsyncDebounceSequence<AsyncStream<Event>, ContinuousClock> {
        return createStream().debounce(for: interval)
    }
    
    /// Remove duplicate consecutive events
    func removeDuplicatesStream() -> AsyncRemoveDuplicatesSequence<AsyncStream<Event>> where Event: Equatable {
        return createStream().removeDuplicates()
    }
    
    /// Compact map events (transform and filter nil results)
    func compactMappedStream<T>(
        _ transform: @Sendable @escaping (Event) -> T?
    ) -> AsyncCompactMapSequence<AsyncStream<Event>, T> {
        return createStream().compactMap(transform)
    }
    
    /// Merge with another event emitter of the same event type
    nonisolated static func merge(
        _ emitter1: MulticastAsyncStream<Event>,
        _ emitter2: MulticastAsyncStream<Event>
    ) async -> AsyncMerge2Sequence<AsyncStream<Event>, AsyncStream<Event>> {
        return await AsyncAlgorithms.merge(emitter1.createStream(), emitter2.createStream())
    }
    
    /// Combine latest events from two emitters
    nonisolated static func combineLatest<E1, E2>(
        _ emitter1: MulticastAsyncStream<E1>,
        _ emitter2: MulticastAsyncStream<E2>
    ) async -> AsyncCombineLatest2Sequence<AsyncStream<E1>, AsyncStream<E2>> {
        return await AsyncAlgorithms.combineLatest(emitter1.createStream(), emitter2.createStream())
    }
    
    /// Zip events from two emitters
    nonisolated static func zip<E1, E2>(
        _ emitter1: MulticastAsyncStream<E1>,
        _ emitter2: MulticastAsyncStream<E2>
    ) async -> AsyncZip2Sequence<AsyncStream<E1>, AsyncStream<E2>> {
        return await AsyncAlgorithms.zip(emitter1.createStream(), emitter2.createStream())
    }
}

/*
/// Enhanced MulticastAsyncStream powered by AsyncAlgorithms
/// Provides advanced stream processing capabilities like throttling, debouncing, filtering, etc.
/// Each subscriber gets their own channel - works like NotificationCenter
public final actor MulticastAsyncStream_v2<Event: Sendable>: Sendable {
    private var subscribers: [UUID: AsyncChannel<Event>] = [:]
    private let logger: LoggerWrapper?
    
    public init(logger: LoggerWrapper? = nil) {
        self.logger = logger
        logger?.debug("Initialized")
    }
    
    deinit {
        logger?.debug("Deinitializing - finishing all subscribers")
        for (_, channel) in subscribers {
            channel.finish()
        }
        subscribers.removeAll()
    }
    
    /// Send an event to all subscribers (non-blocking multicast)
    public func send(_ event: Event) {
        logger?.debug("Sending event to \(subscribers.count) subscribers")
        
        // Send to all subscribers without blocking
        for (_, channel) in subscribers {
            Task {
                await channel.send(event)
            }
        }
    }
    
    /// Send an event synchronously (fire-and-forget)
    public nonisolated func sendSync(_ event: Event) {
        Task { await send(event) }
    }
    
    /// Create a new subscriber channel (each subscriber gets their own channel)
    private func createChannel() -> AsyncChannel<Event> {
        let id = UUID()
        let channel = AsyncChannel<Event>()
      
        // Add subscriber in actor context
        self.addSubscriber(id: id, channel: channel)
        self.autoRemoveOnFinish(id: id, channel: channel)
        
        return channel
    }

    private func autoRemoveOnFinish(id: UUID, channel: AsyncChannel<Event>) {
        Task {
            for await _ in channel {
                // Just draining until finished
            }
            removeSubscriber(id)
        }
    }
    
    public nonisolated func subscribe() async -> any AsyncSequence<Event, Never> {
        return await createChannel()
    }
    
    public nonisolated func filteredStream(
        _ isIncluded: @Sendable @escaping (Event) -> Bool
    ) async -> any AsyncSequence<Event, Never> {
        return await createChannel().filter(isIncluded)
    }
    
    /// Finish all subscribers (no more events will be sent)
    public func finish() {
        logger?.debug("Finishing all \(subscribers.count) subscribers")
        for (_, channel) in subscribers {
            channel.finish()
        }
        subscribers.removeAll()
    }
    
    /// Get current subscriber count
    public func subscriberCount() -> Int {
        return subscribers.count
    }
    
    // Helper method for adding subscriber
    private func addSubscriber(id: UUID, channel: AsyncChannel<Event>) {
        subscribers[id] = channel
        logger?.debug("New subscriber created, total: \(subscribers.count)")
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers.removeValue(forKey: id)
        logger?.debug("Subscriber removed, remaining: \(subscribers.count)")
    }
}
*/



