//
//  File.swift
//  
//
//  Created by Lukasz Zajdel on 21/12/2023.
//

import Foundation

/// Protocol for types that support loadable data management.
///
/// Provides a unified interface for stores that manage async data loading,
/// including state tracking, automatic refresh triggers, and task management.
///
/// Note: `reload()` is not part of this protocol because different stores return
/// different types (Model vs [Model]). Each store implements its own typed `reload()` method.
public protocol LoadableModelSupport {
    /// The current loading state of the data.
    @MainActor
    var loadState: LoadableState { get }

    /// Called when SwiftUI .task() modifier is triggered.
    ///
    /// Automatically loads data if not already loaded or in error state.
    func onTask() async

    /// Triggers a fire-and-forget refresh operation.
    ///
    /// Returns immediately without waiting for the refresh to complete.
    func refresh(setting: RefreshSettings) async throws
}

public enum RefreshDisposition<Model>: @unchecked Sendable {
    case provide(Result<Model, Error>)
    case proceed
}

/// Protocol for settings used in load operations.
///
/// Provides common configuration for both refresh and reload operations.
public protocol LoadSettings: Sendable {
    /// A human-readable reason for this load operation (used for logging/debugging).
    var reason: String { get }

    /// If true, resets the last loaded data when entering loading state.
    var resetLast: Bool { get }
}

/// Settings for fire-and-forget refresh operations.
///
/// Use with `refresh()` methods when you don't need to wait for completion.
/// Supports optional debouncing to batch rapid refresh requests.
///
/// **Example:**
/// ```swift
/// try await store.refresh(
///     setting: .init(
///         reason: "User tapped refresh",
///         debounce: false
///     )
/// )
/// ```
public struct RefreshSettings: LoadSettings, Sendable {
    /// A human-readable reason for this refresh (used for logging/debugging).
    public let reason: String

    /// If true, debounces the refresh to avoid rapid successive calls.
    public let debounce: Bool

    /// If true, resets the last loaded data when entering loading state.
    public let resetLast: Bool

    public init(
        reason: String = "Generic",
        debounce: Bool = false,
        resetLast: Bool = false
    ) {
        self.reason = reason
        self.debounce = debounce
        self.resetLast = resetLast
    }
}

/// Settings for wait-for-completion reload operations.
///
/// Use with `reload()` methods when you need to wait for the data and want
/// proper task cancellation support (e.g., with SwiftUI .task modifier).
///
/// Unlike RefreshSettings, ReloadSettings does not support debouncing - reload
/// operations always execute immediately.
///
/// **Example:**
/// ```swift
/// .task {
///     let data = try await store.reload(
///         setting: .init(reason: "View appeared")
///     )
///     // Use data here
/// }
/// ```
public struct ReloadSettings: LoadSettings, Sendable {
    /// A human-readable reason for this reload (used for logging/debugging).
    public let reason: String

    /// If true, resets the last loaded data when entering loading state.
    public let resetLast: Bool

    public init(
        reason: String = "Generic",
        resetLast: Bool = false
    ) {
        self.reason = reason
        self.resetLast = resetLast
    }
}

/// Automatic refresh triggers that can be enabled/disabled per store.
///
/// Configure which triggers are active via the store's Configuration.
///
/// **Example:**
/// ```swift
/// let config = Configuration(
///     refreshInterval: 60, // seconds
///     refreshTriggers: [.timer, .appForeground]
/// )
/// ```
public enum RefreshTrigger: String, CaseIterable, Sendable, Hashable {
    /// Periodically refreshes based on refreshInterval in Configuration.
    case timer

    /// Refreshes when network connectivity is restored (after being offline).
    case reachability

    /// Refreshes when app returns to foreground (iOS only).
    case appForeground

    /// Refreshes when system time changes significantly (iOS only).
    case significantTimeChange

    /// Controls whether onTask() refreshes already-loaded data.
    /// If disabled, onTask() only loads when data is not yet loaded.
    case refreshOnTask
}
