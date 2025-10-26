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
public protocol LoadableModelSupport {
    /// The type of data this store loads.
    associatedtype LoadedData: Sendable

    /// The current loading state of the data.
    @MainActor
    var loadState: LoadableState { get }

    /// Called when SwiftUI .task() modifier is triggered.
    ///
    /// Automatically loads data if not already loaded or in error state.
    func onTask() async

    /// Triggers a fire-and-forget load operation.
    ///
    /// Returns immediately without waiting for the load to complete.
    /// Use this when you don't need the result immediately.
    ///
    /// - Parameter setting: Refresh settings (reason, debounce, resetLast)
    func loadInBackground(setting: RefreshSettings) async throws

    /// Loads data and waits for completion.
    ///
    /// This method blocks until the load completes and returns the loaded data.
    /// Respects structured concurrency and can be cancelled.
    ///
    /// - Parameter setting: Load settings (reason, resetLast)
    /// - Returns: The loaded data
    /// - Throws: Any error that occurred during loading
    @discardableResult
    func load(setting: ReloadSettings) async throws -> LoadedData

    /// Triggers a fire-and-forget refresh operation.
    ///
    /// Returns immediately without waiting for the refresh to complete.
    ///
    /// - Note: Deprecated. Use `loadInBackground(setting:)` instead.
    @available(*, deprecated, renamed: "loadInBackground")
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

    /// The debounce strategy to use for this refresh.
    public let debounceSettings: DebounceSettings

    /// Computed property for backward compatibility. Returns true if debouncing is enabled.
    public var debounce: Bool {
        debounceSettings.isDebouced
    }

    /// If true, resets the last loaded data when entering loading state.
    public let resetLast: Bool

    /// Initialize with Bool-based debounce (for backward compatibility).
    public init(
        reason: String = "Generic",
        debounce: Bool = false,
        resetLast: Bool = false
    ) {
        self.reason = reason
        self.debounceSettings = debounce ? .default : .none
        self.resetLast = resetLast
    }

    /// Initialize with DebounceSettings.
    public init(
        reason: String = "Generic",
        debounceSettings: DebounceSettings = .none,
        resetLast: Bool = false
    ) {
        self.reason = reason
        self.debounceSettings = debounceSettings
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

/// Debounce strategy for fire-and-forget load operations.
///
/// Controls whether and how to debounce rapid successive load requests.
///
/// **Example:**
/// ```swift
/// // No debounce - executes immediately
/// try await store.loadInBackground(
///     setting: .init(debounceSettings: .none)
/// )
///
/// // Use default debounce from Configuration
/// try await store.loadInBackground(
///     setting: .init(debounceSettings: .default)
/// )
///
/// // Custom debounce time
/// try await store.loadInBackground(
///     setting: .init(debounceSettings: .custom(1.0))
/// )
/// ```
public enum DebounceSettings: Sendable, CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .none:
            return "DebounceSettings.none"
        case .default:
            return "DebounceSettings.default"
        case .custom(let timeInterval):
            return "DebounceSettings.custom:\(timeInterval)"
        }
    }
    
    /// No debouncing - execute immediately.
    case none

    /// Use the debounce value from Configuration.debounceReloadValue.
    case `default`

    /// Use a custom debounce time interval.
    /// - Parameter: The debounce time in seconds
    case custom(TimeInterval)
    
    
    var isDebouced: Bool {
        switch self {
        case .none: return false
        case .default, .custom: return true
        }
    }
    
    var customIterval: TimeInterval? {
        if case .custom(let timeInterval) = self {
            return timeInterval
        }else{
            return nil
        }
    }
}
