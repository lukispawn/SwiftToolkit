//
//  AsyncThrottler.swift
//  FoundationToolkit
//
//  Created by Lukasz Zajdel on 24/12/2024.
//

import Foundation
import AsyncAlgorithms

public final actor tocheck__AsyncThrottler<Key: Hashable & Sendable, Result: Sendable> {

    private struct PendingOperations: Sendable {
        let operation: @Sendable () async throws -> Result
        var continuations: [CheckedContinuation<Result, Error>]
        
        init(operation: @escaping @Sendable () async throws -> Result, continuation: CheckedContinuation<Result, Error>) {
            self.operation = operation
            self.continuations = [continuation]
        }
        
        mutating func addContinuation(_ continuation: CheckedContinuation<Result, Error>) {
            continuations.append(continuation)
        }
        
        func executeAndNotifyAll() async {
            do {
                let result = try await operation()
                for continuation in continuations {
                    continuation.resume(returning: result)
                }
            } catch {
                for continuation in continuations {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private actor KeySpecificThrottler {
        let channel: AsyncChannel<PendingOperations>
        let processingTask: Task<Void, Never>
        var logger: LoggerWrapper?

        init(key: Key, throttleInterval: TimeInterval, logger: LoggerWrapper?) {
            self.channel = AsyncChannel<PendingOperations>()
            self.logger = logger
            
            let intervalDuration = Duration.seconds(throttleInterval)
            
            self.processingTask = Task { [channel, logger] in
                logger?.debug("[AsyncThrottler<\(String(describing: key))>] Starting processing task with interval \(intervalDuration).")
                
                // FIXED: Combine all continuations instead of discarding operations
                let throttledOperations = channel.throttle(
                    for: intervalDuration,
                    clock: .continuous
                ) { (accumulated: PendingOperations?, latest: PendingOperations) async -> PendingOperations in
                    if let accumulated = accumulated {
                        // Combine all continuations - everyone gets the result
                        var combined = latest
                        combined.continuations.append(contentsOf: accumulated.continuations)
                        logger?.debug("[AsyncThrottler<\(String(describing: key))>] Combining \(accumulated.continuations.count) + \(latest.continuations.count) operations.")
                        return combined
                    } else {
                        logger?.debug("[AsyncThrottler<\(String(describing: key))>] First operation with \(latest.continuations.count) callers.")
                        return latest
                    }
                }
                
                for await pendingOperations in throttledOperations {
                    if Task.isCancelled {
                        logger?.debug("[AsyncThrottler<\(String(describing: key))>] Processing task cancelled. Exiting.")
                        break
                    }
                    
                    logger?.debug("[AsyncThrottler<\(String(describing: key))>] Executing operation for \(pendingOperations.continuations.count) callers.")
                    await pendingOperations.executeAndNotifyAll()
                }
                logger?.debug("[AsyncThrottler<\(String(describing: key))>] Processing task finished.")
            }
        }
        
        func send(operation: PendingOperations) async {
            await channel.send(operation)
        }
        
        func cancelProcessing() {
            logger?.debug("[AsyncThrottler] Cancelling processing task for a key.")
            channel.finish()
            processingTask.cancel()
        }
    }
    
    private var keyThrottlers: [Key: KeySpecificThrottler] = [:]
    private let defaultThrottleInterval: TimeInterval
    private let logger: LoggerWrapper?

    public init(defaultThrottleInterval: TimeInterval = 0.5, logger: LoggerWrapper? = nil) {
        self.defaultThrottleInterval = defaultThrottleInterval
        self.logger = logger
        self.logger?.debug("[AsyncThrottler] Initialized with default interval \(defaultThrottleInterval)s.")
    }
    
    /// Schedules an operation for a given key and returns the result.
    /// If multiple operations are scheduled for the same key during the interval,
    /// only one operation will be executed, and all callers will receive the same result.
    ///
    /// - Parameters:
    ///   - key: The key to associate with this operation.
    ///   - throttleInterval: Optional specific interval for this key. Uses default if nil.
    ///   - operation: The async operation to perform that returns Result.
    /// - Returns: The result of the executed operation.
    public func schedule(
        forKey key: Key,
        throttleInterval: TimeInterval? = nil,
        operation: @escaping @Sendable () async throws -> Result
    ) async throws -> Result {
        let interval = throttleInterval ?? defaultThrottleInterval
        
        return try await withCheckedThrowingContinuation { continuation in
            let pendingOp = PendingOperations(operation: operation, continuation: continuation)
            
            Task {
                if let existingThrottler = keyThrottlers[key] {
                    logger?.debug("[AsyncThrottler] Sending operation to existing throttler for key \(String(describing: key)).")
                    await existingThrottler.send(operation: pendingOp)
                } else {
                    logger?.debug("[AsyncThrottler] Creating new throttler for key \(String(describing: key)) with interval \(interval)s.")
                    let newThrottler = KeySpecificThrottler(key: key, throttleInterval: interval, logger: logger)
                    self.setKeyThrottler(key: key, throttler: newThrottler)
                    await newThrottler.send(operation: pendingOp)
                }
            }
        }
    }
    
    private func setKeyThrottler(key: Key, throttler: KeySpecificThrottler) {
        keyThrottlers[key] = throttler
    }
    
    /// Cancels all scheduled operations and processing for a specific key.
    public func cancel(forKey key: Key) {
        logger?.debug("[AsyncThrottler] Cancelling operations for key \(String(describing: key)).")
        if let throttler = keyThrottlers.removeValue(forKey: key) {
            Task {
                await throttler.cancelProcessing()
            }
        }
    }
    
    /// Cancels all scheduled operations and processing for all keys.
    public func cancelAll() {
        logger?.debug("[AsyncThrottler] Cancelling all operations.")
        let allThrottlers = keyThrottlers
        keyThrottlers.removeAll()
        for throttler in allThrottlers.values {
            Task {
                await throttler.cancelProcessing()
            }
        }
    }
    
    public nonisolated func cancelAllSync() {
        Task { [weak self] in
            await self?.cancelAll()
        }
    }
}
