//
//  AsyncLock.swift
//  APIConnectKit
//
//  Created by Lukasz Zajdel on 09/05/2025.
//
import Foundation

public final actor AsyncLock<Action: Sendable, ErrorType: Error> {
    private var activeTask: Task<Action, ErrorType>?

    public init() {}

    /// Executes the action, ensuring that only one instance is running at a time.
    public func perform(
        _ action: @escaping @Sendable () async throws -> Action
    ) async throws -> Action where ErrorType == Error {
        // If there's an active task, wait for it
        if let activeTask {
            return try await activeTask.value
        }

        // Create a new task to perform the action
        let task = Task {
            defer { activeTask = nil } // Ensure the task is cleared after completion
            return try await action()
        }

        activeTask = task
        return try await task.value
    }
    
    /// Executes the action without error handling.
    public func performNonThrowing(
        _ action: @escaping @Sendable () async -> Action
    ) async -> Action where ErrorType == Never {
        // If there's an active task, wait for it
        if let activeTask {
            return await activeTask.value
        }

        // Create a new task to perform the action
        let task = Task {
            defer { activeTask = nil } // Ensure the task is cleared after completion
            return await action()
        }

        activeTask = task
        return await task.value
    }

    /// Cancels the active task if any.
    public func cancel() {
        activeTask?.cancel()
        activeTask = nil
    }

    /// Checks if an action is currently being performed.
    public var isActive: Bool {
        activeTask != nil
    }
}
