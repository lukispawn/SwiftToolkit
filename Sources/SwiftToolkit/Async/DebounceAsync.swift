//
//  Task+Debounce.swift
//  FoundationToolkit
//
//  Created by Lukasz Zajdel on 30/05/2025.
//

import SwiftUI


extension DebounceAsync: Sendable {}

public final actor DebounceAsync {
    private var task: Task<Void, Never>? = nil
    
    public init() {}
    
    /// Debounce and execute the provided operation after a delay.
    /// - Parameters:
    ///   - delay: Delay in seconds.
    ///   - operation: The async operation to execute.
    public func schedule(after delay: TimeInterval, operation: @escaping @Sendable () async -> Void) {
        // Cancel any existing task
        task?.cancel()
        
        task = Task { [delay] in
            // Sleep for the specified delay
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            
            // Check for cancellation before running
            guard !Task.isCancelled else { return }
            
            // Execute the operation
            await operation()
        }
    }
    
    /// Cancel the currently scheduled task (if any)
    public func cancel() {
        task?.cancel()
    }
    
    public nonisolated func cancelSync() {
        Task { [weak self] in
            await self?.cancel()
        }
    }
}

 
