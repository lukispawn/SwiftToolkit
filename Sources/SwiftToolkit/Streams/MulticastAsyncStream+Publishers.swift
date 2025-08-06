//
//  MulticastAsyncStream+Publishers.swift  
//  SwiftToolkit
//
//  Combine Publisher extensions for MulticastAsyncStream
//  Enables seamless integration between AsyncStream and SwiftUI .onReceive()
//

import Combine

// MARK: - MulticastAsyncStream Combine Integration

extension MulticastAsyncStream {
    
    /// Create Combine Publisher from MulticastAsyncStream
    /// 
    /// Provides seamless integration between MulticastAsyncStream and Combine
    /// for SwiftUI .onReceive() compatibility.
    ///
    /// ## Usage
    /// ```swift
    /// let stream = MulticastAsyncStream<String>()
    /// 
    /// // SwiftUI integration
    /// view.onReceive(stream.publisher()) { value in
    ///     handleValue(value)
    /// }
    /// 
    /// // Send values
    /// await stream.send("Hello World")
    /// ```
    /// 
    /// ## Features
    /// - ✅ **Multiple Subscribers**: Each subscriber gets their own stream
    /// - ✅ **Automatic Cleanup**: Subscriptions cleaned up when views disappear
    /// - ✅ **Thread Safe**: Actor-safe multicast to all subscribers
    /// - ✅ **SwiftUI Native**: Perfect .onReceive() integration
    /// 
    /// - Returns: AnyPublisher that emits all events from the stream
    public nonisolated func publisher() -> AnyPublisher<Event, Never> {
        return Publishers.AsyncSequencePublisher {
            await self.subscribe()
        }
        .eraseToAnyPublisher()
    }
}