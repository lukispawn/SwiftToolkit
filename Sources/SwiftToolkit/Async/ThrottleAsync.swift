//
//  ThrottleAsync.swift
//  SwiftToolkit
//
//  Created by Lukasz Zajdel on 24/10/2025.
//

import Foundation
import AsyncAlgorithms

extension ThrottleAsync: Sendable {}

/// A simple throttle mechanism for async operations
///
/// Uses a queue pattern to guarantee periodic execution, making it ideal for side effects
/// like UI updates, statistics refresh, and logging where you want guaranteed execution
/// at regular intervals rather than rejection of events.
///
/// ## Example
///
/// ```swift
/// let throttler = ThrottleAsync(interval: 2.0) {
///     await updateStatistics()
/// }
///
/// // Trigger multiple times rapidly
/// await throttler.trigger()
/// await throttler.trigger()
/// ```
///
/// With continuous triggers (e.g., every 1s) and 2s throttle:
/// - 0.0s: trigger() → Execute immediately
/// - 1.0s: trigger() → Queued
/// - 2.0s: Throttle fires → Execute
/// - 3.0s: trigger() → Queued
/// - 4.0s: Throttle fires → Execute
///
/// This guarantees execution every N seconds, unlike reject-based throttling.
public final actor ThrottleAsync {
    private let channel = AsyncChannel<Void>()
    private var processingTask: Task<Void, Never>?
    private let interval: TimeInterval
    private let operation: @Sendable () async -> Void

    /// Initialize a throttle with the specified interval and operation
    /// - Parameters:
    ///   - interval: Minimum time between executions in seconds
    ///   - operation: The operation to execute when throttle fires
    public init(interval: TimeInterval, operation: @escaping @Sendable () async -> Void) {
        self.interval = interval
        self.operation = operation
    }

    /// Start processing throttled triggers
    /// Should be called once after initialization
    public func start() {
        guard processingTask == nil else { return }

        processingTask = Task { [channel, interval, operation] in
            // Use Swift Algorithms' throttle for rate limiting
            let throttled = channel.throttle(for: .seconds(interval), clock: .continuous)

            for await _ in throttled {
                guard !Task.isCancelled else { break }
                await operation()
            }
        }
    }

    /// Trigger the throttled operation
    /// The operation will execute immediately on first call, then at most once per interval
    public func trigger() async {
        // Ensure processing task is running
        if processingTask == nil {
            start()
        }
        await channel.send(())
    }

    /// Cancel all pending operations and stop processing
    public func cancel() {
        channel.finish()
        processingTask?.cancel()
        processingTask = nil
    }

    /// Synchronous cancel method for use from nonisolated contexts (e.g., deinit)
    public nonisolated func cancelSync() {
        Task { [weak self] in
            await self?.cancel()
        }
    }
}
