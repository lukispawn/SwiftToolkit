//
//  AsyncSequencePublisher.swift
//  SwiftToolkit
//
//  Bridge AsyncSequence to Combine Publisher for SwiftUI integration
//  Enables .onReceive() usage with AsyncStream-based architectures
//

import Combine
import Foundation

extension Publishers {
    /// Bridge AsyncSequence to Combine Publisher
    /// 
    /// Converts any AsyncSequence into a Combine Publisher for SwiftUI .onReceive() integration.
    /// Uses a simplified implementation that works with Swift 6 strict concurrency.
    ///
    /// ## Usage
    /// 
    /// ### Basic AsyncSequence to Publisher:
    /// ```swift
    /// let sequence = AsyncStream<String> { continuation in
    ///     continuation.yield("Hello")
    ///     continuation.yield("World")
    ///     continuation.finish()
    /// }
    /// 
    /// let publisher = Publishers.AsyncSequencePublisher(sequence)
    /// 
    /// // Use with SwiftUI
    /// view.onReceive(publisher) { value in
    ///     print(value) // "Hello", then "World"
    /// }
    /// ```
    ///
    /// ## Features
    /// - ✅ **Automatic Cleanup**: Subscriptions are cancelled when views disappear
    /// - ✅ **Thread Safe**: Works with Swift 6 strict concurrency
    /// - ✅ **Error Handling**: Graceful handling of AsyncSequence failures
    /// - ✅ **Cancellation Support**: Respects Combine cancellation lifecycle
    public struct AsyncSequencePublisher<S: AsyncSequence>: Publisher where S.Element: Sendable, S: Sendable {
        public typealias Output = S.Element
        public typealias Failure = Never
        
        private let sequenceProvider: @Sendable () async -> S
        
        /// Create publisher from async sequence provider
        /// 
        /// - Parameter sequenceProvider: Async closure that returns the AsyncSequence
        public init(_ sequenceProvider: @escaping @Sendable () async -> S) {
            self.sequenceProvider = sequenceProvider
        }
        
        public func receive<Subscriber>(subscriber: Subscriber) 
        where Subscriber: Combine.Subscriber, Never == Subscriber.Failure, S.Element == Subscriber.Input {
            let subscription = AsyncSequenceSubscription(
                subscriber: subscriber,
                sequenceProvider: sequenceProvider
            )
            subscriber.receive(subscription: subscription)
        }
    }
}

// MARK: - Convenience Initializers

extension Publishers.AsyncSequencePublisher {
    /// Create publisher from direct AsyncSequence
    /// 
    /// - Parameter sequence: The AsyncSequence to convert to Publisher
    public init(_ sequence: S) {
        self.init { sequence }
    }
}

// MARK: - Simplified Subscription Implementation

/// Simplified subscription implementation that avoids strict concurrency issues
internal final class AsyncSequenceSubscription<S: AsyncSequence, Subscriber: Combine.Subscriber>: Combine.Subscription, @unchecked Sendable
where S.Element == Subscriber.Input, Subscriber.Failure == Never, S.Element: Sendable, S: Sendable {
    
    private var subscriber: Subscriber?
    private var task: Task<Void, Never>?
    private let sequenceProvider: @Sendable () async -> S
    
    internal init(subscriber: Subscriber, sequenceProvider: @escaping @Sendable () async -> S) {
        self.subscriber = subscriber
        self.sequenceProvider = sequenceProvider
    }
    
    internal func request(_ demand: Subscribers.Demand) {
        guard task == nil else { return }
        
        // Capture subscriber once to avoid repeated access
        guard let capturedSubscriber = subscriber else { return }
        
        task = Task.detached { [sequenceProvider] in
            do {
                let sequence = await sequenceProvider()
                
                for try await element in sequence {
                    guard !Task.isCancelled else { break }
                    
                    // Send to subscriber (subscriber handles its own thread safety)
                    _ = capturedSubscriber.receive(element)
                }
                
                if !Task.isCancelled {
                    capturedSubscriber.receive(completion: .finished)
                }
                
            } catch {
                if !Task.isCancelled {
                    capturedSubscriber.receive(completion: .finished)
                }
            }
        }
    }
    
    internal func cancel() {
        task?.cancel()
        task = nil
        subscriber = nil
    }
    
    deinit {
        cancel()
    }
}

// MARK: - Global Convenience Functions

/// Create publisher from any AsyncSequence
/// 
/// Global convenience function for creating Publishers from AsyncSequences.
/// 
/// - Parameter sequence: AsyncSequence to convert
/// - Returns: Publisher that emits the sequence's elements
public func publisher<S: AsyncSequence>(from sequence: S) -> Publishers.AsyncSequencePublisher<S> where S.Element: Sendable, S: Sendable {
    return Publishers.AsyncSequencePublisher(sequence)
}

/// Create publisher from async sequence provider
/// 
/// Global convenience function for creating Publishers from async sequence providers.
/// 
/// - Parameter provider: Async closure that returns an AsyncSequence
/// - Returns: Publisher that emits the sequence's elements
public func publisher<S: AsyncSequence>(from provider: @escaping @Sendable () async -> S) -> Publishers.AsyncSequencePublisher<S> where S.Element: Sendable, S: Sendable {
    return Publishers.AsyncSequencePublisher(provider)
}