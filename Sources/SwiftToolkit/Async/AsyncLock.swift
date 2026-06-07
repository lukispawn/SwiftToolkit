//
//  AsyncLock.swift
//  SwiftToolkit
//
//  Created by Lukasz Zajdel on 09/05/2025.
//
import Foundation

public final actor AsyncLock<Action: Sendable, ErrorType: Error> {
    private var activeTask: Task<Action, ErrorType>?
    // Identifies the task currently owning the lock. Cleanup compares against this so a
    // finishing *stale* task (e.g. one already superseded via `cancel()` + a new `perform`)
    // cannot clobber a newer active task.
    private var activeToken: UUID?

    public init() {}

    /// Executes the action, ensuring that only one instance is running at a time.
    public func perform(
        _ action: @escaping @Sendable () async throws -> Action
    ) async throws -> Action where ErrorType == Error {
        // If there's an active task, coalesce onto it.
        if let activeTask {
            return try await activeTask.value
        }

        let token = UUID()
        let task = Task {
            try await action()
        }
        activeTask = task
        activeToken = token

        // Clear on *every* exit (success, failure, cancellation) so the lock never gets
        // stuck, but only if we are still the active task. The previous implementation put
        // `defer { activeTask = nil }` inside the `Task`, which could nil out a newer task
        // installed after a `cancel()` — letting a later caller start a second execution.
        defer { clearIfActive(token) }

        return try await task.value
    }

    /// Executes the action without error handling.
    public func performNonThrowing(
        _ action: @escaping @Sendable () async -> Action
    ) async -> Action where ErrorType == Never {
        // If there's an active task, coalesce onto it.
        if let activeTask {
            return await activeTask.value
        }

        let token = UUID()
        let task = Task {
            await action()
        }
        activeTask = task
        activeToken = token

        defer { clearIfActive(token) }

        return await task.value
    }

    /// Clears the active task only if `token` still owns the lock.
    private func clearIfActive(_ token: UUID) {
        guard activeToken == token else { return }
        activeTask = nil
        activeToken = nil
    }

    /// Cancels the active task if any.
    public func cancel() {
        activeTask?.cancel()
        activeTask = nil
        activeToken = nil
    }

    /// Checks if an action is currently being performed.
    public var isActive: Bool {
        activeTask != nil
    }
}
