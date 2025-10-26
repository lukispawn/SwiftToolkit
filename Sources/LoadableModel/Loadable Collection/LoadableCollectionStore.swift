//
//  LoadableCollectionStore.swift
//  SwiftDataTest
//
//  Created by Lukasz Zajdel on 07/11/2023.
//

import AsyncAlgorithms
import Combine
import Foundation
import SwiftToolkit
import os

#if os(iOS)
import UIKit
#endif

@Observable
public class LoadableCollectionStore<
    Model: Identifiable & Sendable,
    Cursor: Equatable & Sendable,
    Query: Equatable & Sendable
>: @unchecked Sendable, LoadableModelSupport where Model.ID: Sendable  {

    public typealias LoadedData = [Model]

    public enum Event: Sendable {
        case didFetch([Model])
        case didUpdateState(LoadedCollectionStatus<[Model], Cursor, Query>)
        case willAddItems([Model])
    }
    
    public struct Configuration: Sendable {
        var refreshInterval: TimeInterval?
        var debounceReloadValue: TimeInterval
        var itemRefreshThrottleInterval: TimeInterval
        var debug: Bool
        var prefix: String?
        var refreshTriggers: Set<RefreshTrigger>

        public init(
            refreshInterval: TimeInterval? = nil,
            debounceReloadValue: TimeInterval = 0.5,
            itemRefreshThrottleInterval: TimeInterval = 0.5,
            debug: Bool = false,
            prefix: String? = nil,
            refreshTriggers: Set<RefreshTrigger> = Set(RefreshTrigger.allCases)
        ) {
            self.refreshInterval = refreshInterval
            self.debounceReloadValue = debounceReloadValue
            self.itemRefreshThrottleInterval = itemRefreshThrottleInterval
            self.debug = debug
            self.prefix = prefix
            self.refreshTriggers = refreshTriggers
        }
    }
    
    @ObservationIgnored
    private var dataProvider: any LoadableCollectionProvider<Model, Cursor, Query>

    @ObservationIgnored
    private var modifierService: (any LoadableCollectionModifier<Model>)?
    
    @MainActor
    public private(set) var data: LoadedCollectionStatus<[Model], Cursor, Query> {
        didSet {
            Task {
                await eventsEmitter.emitEvent(.didUpdateState(data))
            }
            self.logger.info("[state] update state:\(data.debugStatus)")
        }
    }

    @MainActor
    public var loadState: LoadableState { data.state }

    private let eventsEmitter = EventStreamMultiplexer<Event>()

    /// Creates an async stream of store events.
    ///
    /// Events include data fetches, state updates, and item additions.
    ///
    /// - Returns: AsyncStream of Event instances
    public func eventsSequence(
    ) async ->  AsyncStream<Event> {
        await eventsEmitter.createEventStream()
    }

    /// Creates an async stream of store events.
    ///
    /// Events include data fetches, state updates, and item additions.
    ///
    /// - Returns: AsyncStream of Event instances
    public func eventsStream() async -> AsyncStream<Event>{
        await eventsEmitter.createEventStream()
    }
    
    @ObservationIgnored
    private(set) var lastSetQuery: Query?

    @ObservationIgnored
    private let loadBag = AsyncCancelBag()
    
    @ObservationIgnored
    private let coursorBag = AsyncCancelBag()
    
    @ObservationIgnored
    public let refreshBag = CombineCancelBag()
   
    @ObservationIgnored
    public let timerBag = CombineCancelBag()

    @ObservationIgnored
    public let crudBag = AsyncCancelBag()
    
    @ObservationIgnored
    private let debounceReload: DebounceAsync = .init()
    
    

    @ObservationIgnored
    public let configuration: Configuration
    
    @ObservationIgnored
    private var debounceReloadValue: TimeInterval {
        configuration.debounceReloadValue
    }

    @ObservationIgnored
    private var refreshInterval: TimeInterval? {
        configuration.refreshInterval
    }
    
    @ObservationIgnored
    private var itemRefreshThrottleInterval: TimeInterval {
        configuration.itemRefreshThrottleInterval
    }
    
    private let logger: LoggerWrapper
    
    
    // --------------

    /// Creates a store with a constant collection value that never changes.
    ///
    /// - Parameters:
    ///   - value: The constant collection to store
    ///   - modifierService: Optional service for item-level CRUD operations
    ///   - query: Optional query associated with this collection
    ///   - inMemory: If true, disables any persistence layer
    ///   - configuration: Store configuration for refresh triggers, debounce, etc.
    ///   - logger: Optional custom logger for debugging
    public convenience init(
        constant value: [Model],
        modifierService: (any LoadableCollectionModifier<Model>)? = nil,
        query: Query? = nil,
        inMemory: Bool = false,
        configuration: Configuration = .init(),
        logger: LoggerWrapper? = nil
    ) {
        self.init(
            dataProvider: DefaultCollectionProvider(value: value, configuration: .init(inMemory: inMemory)),
            modifierService: modifierService,
            data: .loaded(.init(value: value, query: query)),
            query: query,
            configuration: configuration,
            logger: logger
        )
    }
    
    /// Creates a store that always returns an error.
    ///
    /// Useful for testing error states or providing fallback error instances.
    ///
    /// - Parameters:
    ///   - error: The error to return
    ///   - query: Optional query associated with this collection
    ///   - inMemory: If true, disables any persistence layer
    ///   - configuration: Store configuration for refresh triggers, debounce, etc.
    ///   - logger: Optional custom logger for debugging
    public convenience init(
        constant error: Error,
        query: Query? = nil,
        inMemory: Bool = false,
        configuration: Configuration = .init(),
        logger: LoggerWrapper? = nil
    ) {
        self.init(
            dataProvider: DefaultCollectionProvider(error: error, configuration: .init(inMemory: inMemory)),
            modifierService: nil,
            data: .failed(error),
            query: query,
            configuration: configuration,
            logger: logger
        )
    }
    
    /// Creates a store with an async operation to fetch the collection.
    ///
    /// The operation closure does not receive the query parameter.
    ///
    /// - Parameters:
    ///   - operation: Async closure that fetches the collection
    ///   - modifierService: Optional service for item-level CRUD operations
    ///   - initial: Optional initial collection to display before first fetch
    ///   - query: Optional query associated with this collection
    ///   - inMemory: If true, disables any persistence layer
    ///   - configuration: Store configuration for refresh triggers, debounce, etc.
    ///   - logger: Optional custom logger for debugging
    public convenience init(
        operation: @escaping (() async throws -> [Model]),
        modifierService: (any LoadableCollectionModifier<Model>)? = nil,
        initial: [Model]? = nil,
        query: Query? = nil,
        inMemory: Bool = false,
        configuration: Configuration = .init(),
        logger: LoggerWrapper? = nil
    ) {
        self.init(
            dataProvider: DefaultCollectionProvider(
                operation: operation,
                configuration: .init(inMemory: inMemory)
            ),
            modifierService: modifierService,
            data: {
                if let initial {
                    return .loaded(.init(value: initial, query: query))
                } else {
                    return .notRequested
                }
            }(),
            query: query,
            configuration: configuration,
            logger: logger
        )
    }

    /// Creates a store with a query-aware async operation.
    ///
    /// The operation closure receives the current query parameter, allowing
    /// dynamic filtering or pagination based on the query.
    ///
    /// - Parameters:
    ///   - operation: Async closure that receives Query? and fetches the collection
    ///   - modifierService: Optional service for item-level CRUD operations
    ///   - initial: Optional initial collection to display before first fetch
    ///   - query: Optional initial query
    ///   - inMemory: If true, disables any persistence layer
    ///   - configuration: Store configuration for refresh triggers, debounce, etc.
    ///   - logger: Optional custom logger for debugging
    public convenience init(
        queryableOperation operation: @escaping ((Query?) async throws -> [Model]),
        modifierService: (any LoadableCollectionModifier<Model>)? = nil,
        initial: [Model]? = nil,
        query: Query? = nil,
        inMemory: Bool = false,
        configuration: Configuration = .init(),
        logger: LoggerWrapper? = nil
    ) {
        self.init(
            dataProvider: DefaultCollectionProvider(
                queryableOperation: operation,
                configuration: .init(inMemory: inMemory)
            ),
            modifierService: modifierService,
            data: {
                if let initial {
                    return .loaded(.init(value: initial, query: query))
                } else {
                    return .notRequested
                }
            }(),
            query: query,
            configuration: configuration,
            logger: logger
        )
    }

    /// Creates a store with a custom provider service.
    ///
    /// This is the designated initializer that allows full customization.
    ///
    /// - Parameters:
    ///   - dataProvider: Custom provider conforming to LoadableCollectionProvider
    ///   - modifierService: Optional service for item-level CRUD operations
    ///   - data: Initial data state (defaults to .notRequested)
    ///   - query: Optional initial query
    ///   - configuration: Store configuration for refresh triggers, debounce, etc.
    ///   - logger: Optional custom logger for debugging
    public init(
        dataProvider: any LoadableCollectionProvider<Model, Cursor, Query>,
        modifierService: (any LoadableCollectionModifier<Model>)? = nil,
        data: LoadedCollectionStatus<[Model], Cursor, Query> = .notRequested,
        query: Query? = nil,
        configuration: Configuration = .init(),
        logger: LoggerWrapper? = nil
    ) {
        self.dataProvider = dataProvider
        self.modifierService = modifierService
        _data = data
        
        self.lastSetQuery = query
        self.configuration = configuration

        self.logger = logger ?? .init(
            logger: .init(subsystem: "com.LoadableModel", category: "LoadableModel"),
            prefix: "[Loadable] [\(configuration.prefix ?? "\(Self.self)")]",
            enabled: configuration.debug
        )
        
        
        self.logger.info("[Init]")
        
        observeTimer()
        observeRefresh()
    }

    deinit {
        self.logger.info("[Deinit]")
        destroyObservers()
    }

    // --------------

    /// Called when SwiftUI .task() modifier is triggered.
    ///
    /// Automatically loads data if not already loaded. Uses the last set query.
    /// Respects the `refreshOnTask` trigger setting - if disabled, won't refresh
    /// already-loaded data.
    ///
    /// This method uses `load()` internally, so it properly respects task cancellation
    /// when the view disappears.
    ///
    /// - Note: Skips loading if already loading with same query
    public final func onTask() async {
        await onTask(query: nil, fireAndForget: nil)
    }

    /// Called when SwiftUI .task() modifier is triggered with optional query and fire-and-forget behavior.
    ///
    /// Automatically loads data with the specified query (or uses `lastSetQuery` if nil).
    /// Respects the `refreshOnTask` trigger setting - if disabled and already loaded
    /// with the same query, won't refresh.
    ///
    /// - Parameters:
    ///   - query: The query to use for loading. If nil, uses `lastSetQuery`.
    ///   - fireAndForget: Optional refresh settings for fire-and-forget behavior. If nil (default),
    ///                    uses `load()` which waits for completion and respects task cancellation.
    ///                    If provided, uses `loadInBackground()` for fire-and-forget behavior
    ///                    with optional debouncing.
    ///
    /// **Behavior:**
    /// - `fireAndForget: nil` → Uses `load()` (waits, cancellable by SwiftUI .task)
    /// - `fireAndForget: .init(...)` → Uses `loadInBackground()` (fire-and-forget, not cancellable)
    ///
    /// **Example:**
    /// ```swift
    /// // Standard: waits for completion, cancellable
    /// .task { await store.onTask() }
    /// .task(id: query) { await store.onTask(query: query) }
    ///
    /// // Fire-and-forget with debounce
    /// .task(id: query) {
    ///     await store.onTask(
    ///         query: query,
    ///         fireAndForget: .init(debounceSettings: .default)
    ///     )
    /// }
    /// ```
    ///
    /// - Note: Skips loading if already loading with same query
    public final func onTask(query: Query? = nil, fireAndForget setting: RefreshSettings?) async {
        let effectiveQuery = query ?? lastSetQuery

        self.logger.info("[onTask] status: \(await data.debugStatus)")

        if await self.data.isLoading(), await self.data.query == effectiveQuery {
            return
        }

        // Skip refresh if already loaded with same query and refreshOnTask trigger is disabled
        let isLoaded = await self.data.isLoaded()
        let currentQuery = await self.data.query
        if isLoaded, currentQuery == effectiveQuery, !configuration.refreshTriggers.contains(.refreshOnTask) {
            return
        }

        if let setting = setting {
            // Fire-and-forget with debounce
            try? await loadInBackground(query: effectiveQuery, setting: setting)
        } else {
            // Wait for completion, cancellable
            _ = try? await load(query: effectiveQuery, setting: ReloadSettings(reason: "onTask"))
        }
    }

    /// Called when SwiftUI .task() modifier is triggered with a specific query.
    ///
    /// - Parameters:
    ///   - query: The query to use for loading
    ///   - debounce: If true, uses debounced fire-and-forget; if false, waits for completion (cancellable)
    ///
    /// - Note: Deprecated. Use `onTask(query:fireAndForget:)` instead. Pass `fireAndForget` with
    ///         `debounceSettings` for fire-and-forget behavior, or `nil` for cancellable wait.
    @available(*, deprecated, message: "Use onTask(query:fireAndForget:) instead. Pass fireAndForget with debounceSettings for fire-and-forget behavior, or nil for cancellable wait.")
    public final func onTask(query: Query, debounce: Bool) async throws {
        let setting: RefreshSettings? = debounce ? .init(debounceSettings: .default) : nil
        await onTask(query: query, fireAndForget: setting)
    }

    /// Cancels all ongoing operations including loads, cursor loads, debounces, and observers.
    ///
    /// Useful for cleanup or when you need to stop all pending operations.
    public func cancel() async {
        self.logger.info("[Cancel]")
        
        refreshBag.cancel()
        timerBag.cancel()
        
        await crudBag.cancel()
        await loadBag.cancel()
        await coursorBag.cancel()
        await debounceReload.cancel()
        
    }

    private func destroyObservers() {
        self.logger.info("[Destroy observers]")
        
        refreshBag.cancel()
        timerBag.cancel()
        
        crudBag.cancelSync()
        loadBag.cancelSync()
        coursorBag.cancelSync()
        debounceReload.cancelSync()
    }

    // --------------

    @MainActor
    public final func updateSource(
        dataProvider: any LoadableCollectionProvider<Model, Cursor, Query>,
        query: Query? = nil,
        setting: RefreshSettings = .init(debounce: false, resetLast: true)
    ) async throws {
        self.dataProvider = dataProvider
        return try await self.loadInBackground(setting: setting)
    }

    @MainActor
    public final func updateSource(
        operation: @escaping (() async throws -> [Model]),
        query: Query? = nil,
        inMemory: Bool = false,
        setting: RefreshSettings = .init(debounce: false, resetLast: true)
    ) async throws {
        let provider = DefaultCollectionProvider<Model, Cursor, Query>(
            operation: operation,
            configuration: .init(inMemory: inMemory)
        )
        return try await updateSource(dataProvider: provider, query: query, setting: setting)
    }

    @MainActor
    public final func updateSource(
        queryableOperation operation: @escaping ((Query?) async throws -> [Model]),
        query: Query? = nil,
        inMemory: Bool = false,
        setting: RefreshSettings = .init(debounce: false, resetLast: true)
    ) async throws {
        let provider = DefaultCollectionProvider<Model, Cursor, Query>(
            queryableOperation: operation,
            configuration: .init(inMemory: inMemory)
        )
        return try await updateSource(dataProvider: provider, query: query, setting: setting)
    }

    @MainActor
    public final func updateSource(
        constant value: [Model],
        query: Query? = nil,
        inMemory: Bool = false,
        setting: RefreshSettings = .init(debounce: false, resetLast: true)
    ) async throws {
        let provider = DefaultCollectionProvider<Model, Cursor, Query>(
            value: value,
            configuration: .init(inMemory: inMemory)
        )
        return try await updateSource(dataProvider: provider, query: query, setting: setting)
    }

    @MainActor
    public final func updateSource(
        constant error: Error,
        query: Query? = nil,
        setting: RefreshSettings = .init(debounce: false, resetLast: true)
    ) async throws {
        let provider = DefaultCollectionProvider<Model, Cursor, Query>(
            error: error,
            configuration: .init(inMemory: false)
        )
        return try await updateSource(dataProvider: provider, query: query, setting: setting)
    }

    
    
    // ----------------------------------------
    
    /// Checks if the collection is currently loaded.
    ///
    /// - Returns: true if data is in the loaded state
    @MainActor
    public final func isLoaded() -> Bool {
        return self.data.isLoaded()
    }

    /// Checks if the collection is currently loading.
    ///
    /// - Returns: true if data is in the loading state
    @MainActor
    public final func isLoading() -> Bool {
        return self.data.isLoading()
    }
    
    @MainActor
    private final func cursorCandidate(type: LoadableArrayPageCursorType) -> Cursor? {
        switch type {
        case .next:
            return data.nextCursor()
        case .previous:
            return data.previousCursor()
        }
    }
    
    @MainActor
    private func validateCusorCandidate(_ candidate: Cursor, type: LoadableArrayPageCursorType) -> Bool {
        switch type {
        case .next:
            return dataProvider.nextPageAvailable(candidate)
        case .previous:
            return dataProvider.previousPageAvailable(candidate)
        }
    }
    
    /// Checks if a specific page is currently loading.
    ///
    /// - Parameter type: The page type (.next or .previous)
    /// - Returns: true if the specified page is loading
    @MainActor
    public final func isPageLoading(type: LoadableArrayPageCursorType) -> Bool {
        switch type {
        case .next:
            return data.isLoadingNext()
        case .previous:
            return data.isLoadingPrevious()
        }
    }
    
    /// Checks if loading a specific page is currently possible.
    ///
    /// Returns true only if:
    /// - Collection is loaded
    /// - The specified page is not already loading
    /// - A cursor exists for the specified page
    ///
    /// - Parameter type: The page type (.next or .previous)
    /// - Returns: true if the page can be loaded
    @MainActor
    public final func isPageLoadingEnabled(type: LoadableArrayPageCursorType) -> Bool {
        guard isLoaded() else { return false }
        guard isPageLoading(type: type) == false else { return false }
        return cursorCandidate(type: type) != nil
    }

    /// Checks if a cursor exists for the specified page.
    ///
    /// - Parameter type: The page type (.next or .previous)
    /// - Returns: true if a cursor exists
    @MainActor
    public final func isPageAvailable(type: LoadableArrayPageCursorType) -> Bool {
        cursorCandidate(type: type) != nil
    }
    
    /// Loads the next or previous page of items.
    ///
    /// Validates that the page is not currently loading and that a cursor exists
    /// before attempting to load.
    ///
    /// - Parameter type: The page type (.next or .previous)
    /// - Throws: Any error that occurred during page loading
    @MainActor
    public final func loadCoursor(type: LoadableArrayPageCursorType) async throws {
        guard isPageLoading(type: type) == false else { return }
        guard let candidate = cursorCandidate(type: type) else { return }
        guard validateCusorCandidate(candidate, type: type) else { return }
        try await executeLoadCursor(cursor: candidate, cursorType: type)
    }
}

extension LoadableCollectionStore {
    // MARK: - New Load API

    /// Triggers a fire-and-forget load operation using the last set query.
    ///
    /// This method returns immediately without waiting for the load to complete.
    /// See `loadInBackground(query:setting:)` for detailed documentation.
    ///
    /// - Parameter setting: Refresh settings including debounce strategy
    public func loadInBackground(
        setting: RefreshSettings = .init(debounceSettings: .none)
    ) async throws {
        try await loadInBackground(query: lastSetQuery, setting: setting)
    }

    /// Triggers a fire-and-forget load operation with a specific query.
    ///
    /// This method returns immediately without waiting for the load to complete.
    /// The load operation runs in a background Task that cannot be cancelled by
    /// the caller's task context.
    ///
    /// **Use this when:**
    /// - You want to trigger a load but don't need to wait for the result
    /// - The load is triggered by user action (pull-to-refresh, button tap)
    /// - You're in a context where blocking isn't acceptable
    /// - You want to batch rapid successive requests with debouncing
    ///
    /// **Debouncing behavior:**
    /// Configure via `RefreshSettings.debounceSettings`:
    /// - `.none`: Executes immediately, cancels any pending debounced loads
    /// - `.default`: Uses the debounce interval from Configuration (default: 0.5s)
    /// - `.custom(interval)`: Uses a custom debounce interval in seconds
    ///
    /// **Example:**
    /// ```swift
    /// Button("Refresh") {
    ///     Task {
    ///         let query = SearchQuery(text: "swift")
    ///         try? await store.loadInBackground(
    ///             query: query,
    ///             setting: .init(
    ///                 reason: "User tap",
    ///                 debounceSettings: .default
    ///             )
    ///         )
    ///         // Returns immediately, doesn't wait for completion
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - query: The query to use for fetching (nil for no query)
    ///   - setting: Refresh settings including debounce strategy
    /// - Note: Use `load(query:setting:)` if you need to wait for completion or want proper cancellation
    public func loadInBackground(
        query: Query?,
        setting: RefreshSettings = .init(debounceSettings: .none)
    ) async throws {
        if setting.debounceSettings.isDebouced {
            // Debounce needed - pass to reloadDebounce which handles .default and .custom
            self.logger.info("[loadInBackground] [debounce] reason: \(setting.reason) query:\(query.debugDescription)")
            await reloadDebounce(query: query, setting: setting, debounceInterval: setting.debounceSettings.customIterval ?? debounceReloadValue)
        } else {
            // No debounce - execute immediately
            self.logger.info("[loadInBackground] [immediate] reason: \(setting.reason) query:\(query.debugDescription)")
            await debounceReload.cancel()
            Task(priority: .userInitiated) {
                _ = try? await self.reloadForce(query: query, setting: setting)
            }
        }
    }

    /// Loads data using the last set query and waits for completion.
    ///
    /// See `load(query:setting:)` for detailed documentation.
    ///
    /// - Parameter setting: Load settings (reason, resetLast)
    /// - Returns: The loaded collection
    /// - Throws: Any error that occurred during loading
    @discardableResult
    public func load(
        setting: ReloadSettings = ReloadSettings()
    ) async throws -> [Model] {
        try await load(query: lastSetQuery, setting: setting)
    }

    /// Loads data with a specific query and waits for completion.
    ///
    /// This method waits for the load to complete and returns the loaded collection.
    /// The operation respects structured concurrency and can be cancelled when
    /// the caller's task is cancelled (e.g., SwiftUI .task modifier).
    ///
    /// **Use this when:**
    /// - You need the loaded data immediately after calling
    /// - You want proper task cancellation (SwiftUI .task, Task cancellation)
    /// - You're loading data as part of a larger sequential operation
    ///
    /// **Example:**
    /// ```swift
    /// .task(id: searchQuery) {
    ///     do {
    ///         let items = try await store.load(
    ///             query: searchQuery,
    ///             setting: .init(reason: "Search query changed")
    ///         )
    ///         // `items` is available here, and properly cancels if query changes
    ///     } catch {
    ///         print("Failed to load: \(error)")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - query: The query to use for fetching (nil for no query)
    ///   - setting: Load settings (reason, resetLast)
    /// - Returns: The loaded collection
    /// - Throws: Any error that occurred during loading
    /// - Note: This method cannot be debounced - it always executes immediately
    @discardableResult
    public func load(
        query: Query?,
        setting: ReloadSettings = ReloadSettings()
    ) async throws -> [Model] {
        self.logger.info("[load] reason: \(setting.reason) query:\(query.debugDescription)")
        return try await reloadForce(query: query, setting: setting)
    }

    

    private final func reloadForce(query: Query?, setting: any LoadSettings) async throws -> [Model] {
        self.logger.info("[reload] [force] reason: \(setting.reason) query:\(query.debugDescription)")
        self.lastSetQuery = query
        await debounceReload.cancel()
        return try await self.executeLoad(setting: setting, query: query)
    }
    
    private final func reloadDebounce(query: Query?, setting: RefreshSettings, debounceInterval: TimeInterval) async {
        self.lastSetQuery = query
        // Use default debounce from configuration
        self.logger.info("[reload] [debounce:\(setting.debounceSettings.debugDescription)] reason: \(setting.reason) query:\(query.debugDescription)")
        if await data.isNotRequested() == false {
            await loadBag.cancel()
            await MainActor.run {
                data.setIsLoading(cursor: nil, query: query, resetLast: setting.resetLast)
            }
            await debounceReload.schedule(after: debounceInterval) {
                _ = try? await self.executeLoad(setting: setting, query: query)
            }
        } else {
            self.logger.info("[reload] [debounce:\(setting.debounceSettings.debugDescription)] reason: \(setting.reason) | switch to force reload")
            Task(priority: .userInitiated) {
                _ = try? await self.reloadForce(query: query, setting: setting)
            }
        }
    }
}

extension LoadableCollectionStore {
    // MARK: - Deprecated Refresh/Reload API

    /// Triggers a fire-and-forget refresh operation using the last set query.
    ///
    /// See `refresh(query:setting:)` for detailed documentation.
    ///
    /// - Parameter setting: Refresh settings including debounce option
    /// - Note: Deprecated. Use `loadInBackground(setting:)` instead. RefreshSettings remains the same.
    @available(*, deprecated, renamed: "loadInBackground", message: "Use loadInBackground(setting:) instead. RefreshSettings remains the same.")
    public final func refresh(setting: RefreshSettings) async throws {
        try await loadInBackground(setting: setting)
    }

    /// Triggers a fire-and-forget refresh operation with a specific query.
    ///
    /// This method returns immediately without waiting for the refresh to complete.
    /// The refresh operation runs in a detached Task that cannot be cancelled by
    /// the caller's task context.
    ///
    /// **Use this when:**
    /// - You want to trigger a refresh but don't need to wait for the result
    /// - The refresh is triggered by user action (pull-to-refresh, button tap)
    /// - You're in a context where blocking isn't acceptable
    ///
    /// **Example:**
    /// ```swift
    /// Button("Refresh") {
    ///     Task {
    ///         let query = SearchQuery(text: "swift")
    ///         try? await store.refresh(query: query, setting: .init(reason: "User tap"))
    ///         // Returns immediately, doesn't wait for completion
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - query: The query to use for fetching (nil for no query)
    ///   - setting: Refresh settings including debounce option
    /// - Note: Deprecated. Use `loadInBackground(query:setting:)` instead. RefreshSettings remains the same.
    @available(*, deprecated, renamed: "loadInBackground", message: "Use loadInBackground(query:setting:) instead. RefreshSettings remains the same.")
    public final func refresh(query: Query?, setting: RefreshSettings) async throws {
        try await loadInBackground(query: query, setting: setting)
    }

    /// Triggers a reload operation using the last set query and waits for completion.
    ///
    /// See `reload(query:setting:)` for detailed documentation.
    ///
    /// - Parameter setting: Reload settings (no debounce option)
    /// - Returns: The loaded collection
    /// - Throws: Any error that occurred during loading
    /// - Note: Deprecated. Use `load(setting:)` for clearer API.
    @available(*, deprecated, renamed: "load", message: "Use load(setting:) for clearer API. LoadSettings matches the old ReloadSettings.")
    @discardableResult
    public final func reload(setting: ReloadSettings) async throws -> [Model] {
        try await reload(query: lastSetQuery, setting: setting)
    }

    /// Triggers a reload operation with a specific query and waits for completion.
    ///
    /// This method waits for the reload to complete and returns the loaded collection.
    /// The operation respects structured concurrency and can be cancelled when
    /// the caller's task is cancelled (e.g., SwiftUI .task modifier).
    ///
    /// **Use this when:**
    /// - You need the loaded data immediately after calling
    /// - You want proper task cancellation (SwiftUI .task, Task cancellation)
    /// - You're loading data as part of a larger sequential operation
    ///
    /// **Example:**
    /// ```swift
    /// .task(id: searchQuery) {
    ///     do {
    ///         let items = try await store.reload(
    ///             query: searchQuery,
    ///             setting: .init(reason: "Search query changed")
    ///         )
    ///         // `items` is available here, and properly cancels if query changes
    ///     } catch {
    ///         print("Failed to load: \(error)")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - query: The query to use for fetching (nil for no query)
    ///   - setting: Reload settings (no debounce option)
    /// - Returns: The loaded collection
    /// - Throws: Any error that occurred during loading
    /// - Note: Deprecated. Use `load(query:setting:)` for clearer API.
    @available(*, deprecated, renamed: "load", message: "Use load(query:setting:) for clearer API. LoadSettings matches the old ReloadSettings.")
    @discardableResult
    public final func reload(query: Query?, setting: ReloadSettings) async throws -> [Model] {
        return try await load(query: query, setting: setting)
    }
}

extension LoadableCollectionStore {
    // -------------
    @discardableResult
    private func executeLoad(
        setting: any LoadSettings,
        query: Query?
    ) async throws -> [Model] {
        self.lastSetQuery = query

        if case .provide(let providedResult) = await dataProvider.willLoad(previous: data, query: query) {
            switch providedResult {
            case .success(let model):
                await MainActor.run {
                    let info: LoadableCollectionInfo<[Model], Cursor, Query> = .init(
                        value: model.data,
                        query: query,
                        nextCursor: model.nextCursor,
                        previousCursor: model.previousCursor,
                        allCount: model.allCount,
                        info: model.info
                    )
                    self.data = .loaded(info)
                }
            case .failure(let error):
                await MainActor.run {
                    self.data = .failed(error)
                }
            }
            return try providedResult.get().data
        }
        
        await loadBag.cancel()
        await coursorBag.cancel()
        
        await MainActor.run {
            data.setIsLoading(cursor: nil, query: query, resetLast: setting.resetLast)
        }
        
        let task = Task.detached(priority: .userInitiated) { [self] in
            let startTime = Date()
            self.logger.info("[load] [start] reason: \(setting.reason)")
            do {
                try Task.checkCancellation()
                
                let value = try await dataProvider.load(query: query)

                try Task.checkCancellation()
                
                self.logger.info("[load] [end] reason: \(setting.reason) success | fetch time:\(abs(startTime.timeIntervalSinceNow))")

                let info = try await processFirstData(query: query, value: value)

                await MainActor.run {
                    data = .loaded(info)
                }
               
                await eventsEmitter.emitEvent(.didFetch(value.data))
                
                return value.data
            } catch {
                if let loadedData = await self.data.loadedData, Task.isCancelled {
                    self.logger.error("[load] [end] reason: \(setting.reason) isCancelled")
                    await MainActor.run {
                        data = .loaded(loadedData)
                    }
                    return loadedData.value
                }
                
                await MainActor.run {
                    self.logger.error("[load] [end] reason: \(setting.reason) fail:\(error) fetch time:\(abs(startTime.timeIntervalSinceNow))")
                    data = .failed(error)
                }
                
                throw error
            }
        }

        await loadBag.insert(task.eraseToAnyCancellable())
        
        return try await task.value
    }

    private func processFirstData(
        query: Query?,
        value: LoadableCollectionResult<Model, Cursor>
    ) async throws -> LoadableCollectionInfo<[Model], Cursor, Query> {
        let items = try await dataProvider.processContent(value.data)

        let nextCursor: Cursor?
        let previousCursor: Cursor?
        if let currentData = await data.loadedData {
            nextCursor = dataProvider.overridePageCursorAfterInitialFetch().contains(.next) ? currentData.nextCursor : value.nextCursor
            previousCursor = dataProvider.overridePageCursorAfterInitialFetch().contains(.previous) ? currentData.previousCursor : value.previousCursor
        } else {
            nextCursor = value.nextCursor
            previousCursor = value.previousCursor
        }
        
        self.logger.verbose("[load] [end] [process] loaded:\(items.count) | allCount:\(String(describing: value.allCount?.description))")

        let info: LoadableCollectionInfo<[Model], Cursor, Query> = .init(
            value: items,
            query: query,
            nextCursor: nextCursor,
            previousCursor: previousCursor,
            allCount: value.allCount,
            info: value.info
        )

        return info
    }

    // --------------

    @discardableResult
    private func executeLoadCursor(
        cursor: Cursor,
        cursorType type: LoadableArrayPageCursorType
    ) async throws -> [Model] {
        await coursorBag.cancel()
        
        await MainActor.run {
            data.setIsLoading(
                cursor: .init(cursor: cursor, type: type),
                query: data.query ?? lastSetQuery
            )
        }
        
        let task = Task.detached(priority: .userInitiated) { [self] in
            let startTime = Date()
            self.logger.info("[load next] [start] cursor:\(cursor)")

            do {
                try Task.checkCancellation()
                
                let value = try await dataProvider.loadCursor(cursor, type: type)

                try Task.checkCancellation()
                
                let info = try await processCursorData(
                    cursor: cursor,
                    query: data.query,
                    value: value,
                    cursorType: type
                )

                self.logger.info("[load next] [end] success | fetch items: \(value.data.count) merged: \(info.value.count) time:\(abs(startTime.timeIntervalSinceNow))")

                await MainActor.run {
                    self.data = .loaded(info)
                }
                
                return info.value

            } catch {
                self.logger.info("[load next] [end] fail:\(error) fetch time:\(abs(startTime.timeIntervalSinceNow))")

                if !Task.isCancelled {
                    await MainActor.run {
                        data = .failed(error)
                    }
                }
                
                throw error
            }
        }

        await coursorBag.insert(task.eraseToAnyCancellable())
        
        return try await task.value
    }

    private func processCursorData(
        cursor: Cursor,
        query: Query?,
        value: LoadableCollectionResult<Model, Cursor>,
        cursorType: LoadableArrayPageCursorType
    ) async throws -> LoadableCollectionInfo<[Model], Cursor, Query> {
        let previousData = await data.value ?? []
        let newData = value.data
        
        let finalData = self.dataProvider.mergeFromCursor(
            cursor: cursorType,
            existing: previousData,
            append: newData
        ) ?? self.defaultMerge(
            cursor: cursorType,
            existing: previousData,
            append: newData,
        )
        let processed = try await dataProvider.processContent(finalData)

        let nextCursor: Cursor?
        let previousCursor: Cursor?
        if let currentData = await data.loadedData {
            nextCursor = dataProvider.overridePageCursorAfterPageFetch(loadType: cursorType).contains(.next) ? currentData.nextCursor : value.nextCursor
            previousCursor = dataProvider.overridePageCursorAfterPageFetch(loadType: cursorType).contains(.previous) ? currentData.previousCursor : value.previousCursor
        } else {
            nextCursor = value.nextCursor
            previousCursor = value.previousCursor
        }
        
        let info: LoadableCollectionInfo<[Model], Cursor, Query> = .init(
            value: processed,
            query: query,
            nextCursor: nextCursor,
            previousCursor: previousCursor,
            allCount: finalData.count,
            info: value.info
        )
        
        return info
    }

    private func defaultMerge(
        cursor: LoadableArrayPageCursorType,
        existing: [Model],
        append: [Model]
    ) -> [Model] {
        var finalData = existing

        switch cursor {
        case .next:
            append.forEach { item in
                if let index = finalData.firstIndex(where: { $0.id == item.id }) {
                    finalData.remove(at: index)
                    finalData.insert(item, at: index)
                } else {
                    finalData.append(item)
                }
            }
        case .previous:
            append.reversed().forEach { item in
                if let index = finalData.firstIndex(where: { $0.id == item.id }) {
                    finalData.remove(at: index)
                    finalData.insert(item, at: index)
                } else {
                    finalData.insert(item, at: 0)
                }
            }
        }
    
        return finalData
    }

    // --------------
}

public extension LoadableCollectionStore {
    /// Refreshes a single item by fetching it from the server.
    ///
    /// Requires a modifierService to be configured. The refreshed item
    /// replaces the existing item in the local collection.
    ///
    /// - Parameter objectId: The ID of the item to refresh
    /// - Returns: The refreshed item
    /// - Throws: LoadableError.notSupported if no modifierService is configured,
    ///           or any error from the refresh operation
    @MainActor
    @discardableResult
    func refreshItem(objectId: Model.ID) async throws -> Model {
        guard let modifierService else {
            throw LoadableError.notSupported("refreshItem(objectId:) - no modifier service provided")
        }
        
        self.logger.info("[refresh item] begin id:\(objectId)")
        
        let task = Task {
            let model = try await modifierService.refreshItem(objectId)
            _ = await self.updateLocalItem(model)
            return model
        }
        await task.store(in: crudBag)
        
        do {
            let value = try await task.value
            self.logger.info("[refresh item] end success id:\(objectId)")
            return value
        } catch {
            self.logger.info("[refresh item] end failed id:\(objectId) error:\(error)")
            throw error
        }
    }

    
    /// Removes an item from both the server and local collection.
    ///
    /// Optimistically removes the item locally first, then calls the server.
    /// If the server call fails, restores the previous state and triggers a refresh.
    ///
    /// Requires a modifierService to be configured.
    ///
    /// - Parameter objectId: The ID of the item to remove
    /// - Throws: LoadableError.notSupported if no modifierService is configured,
    ///           or any error from the remove operation
    @MainActor
    func removeItem(objectId: Model.ID) async throws {
        guard let modifierService else {
            throw LoadableError.notSupported("removeItem(objectId:) - no modifier service provided")
        }
        
        self.logger.info("[remove item] begin id:\(objectId)")
        
        let id = objectId
        
        let task = Task {
            let previous = data
            removeLocalItem(withId: objectId)
            do {
                _ = try await modifierService.removeItem(id)
            } catch {
                data = previous
                Task {
                    try? await loadInBackground(
                        setting: RefreshSettings(
                            reason: "Delete Object Request fail",
                            debounceSettings: .default,
                            resetLast: false
                        )
                    )
                }
                throw error
            }
        }

        await task.store(in: crudBag)
        
        do {
            _ = try await task.value
            self.logger.info("[remove item] end success id:\(objectId)")
        } catch {
            self.logger.info("[remove item] end failed id:\(objectId) error:\(error)")
            throw error
        }
    }
}

public extension LoadableCollectionStore {
    /// Checks if item-level modifications are supported.
    ///
    /// - Returns: true if a modifierService is configured
    @MainActor
    final func isModificationSupported() -> Bool {
        return modifierService != nil
    }

    /// Sets or updates the modifier service for item-level operations.
    ///
    /// - Parameter modifierService: The modifier service to use
    @MainActor
    func setModifierService(_ modifierService: any LoadableCollectionModifier<Model>) {
        self.modifierService = modifierService
    }
}

extension LoadableCollectionStore {
    private func observeRefresh() {
        if configuration.refreshTriggers.contains(.reachability) {
            if let manager = LoadableReachabilityFactory.defaultManager {
                manager.start()
                manager.reachabilityChanged
                    .filter { $0 == .wifi || $0 == .cellular }
                    .removeDuplicates()
                    .sink(receiveValue: { [weak self] _ in
                        guard let self else { return }
                        Task {
                            if await self.data.isError() {
                                try? await self.loadInBackground(
                                    setting: RefreshSettings(
                                        reason: "Reachability changed",
                                        debounceSettings: .default,
                                        resetLast: false
                                    )
                                )
                            }
                        }

                    })
                    .store(in: refreshBag)
            }
        }

        #if os(iOS)

        Task {
            await MainActor.run {
                if configuration.refreshTriggers.contains(.appForeground) {
                    NotificationCenter.default.publisher(
                        for: UIApplication.willEnterForegroundNotification
                    ).sink(receiveValue: { [weak self] _ in
                        Task {
                            try? await self?.refresh(setting: .init(reason: "Will Enter Foreground notification", debounce: true, resetLast: false))
                        }
                    }).store(in: refreshBag)
                }

                if configuration.refreshTriggers.contains(.significantTimeChange) {
                    NotificationCenter.default.publisher(
                        for: UIApplication.significantTimeChangeNotification
                    ).sink(receiveValue: { [weak self] _ in
                        Task {
                            try? await self?.refresh(setting: .init(reason: "Significant Time Change notification", debounce: true, resetLast: false))
                        }
                    }).store(in: refreshBag)
                }
            }
        }

        #endif
    }
    
    private func observeTimer() {
        guard configuration.refreshTriggers.contains(.timer) else { return }

        if let refreshInterval {
            let intervalDuration = Duration.seconds(refreshInterval)
            let timer = AsyncTimerSequence(interval: intervalDuration, clock: .continuous)

            let task = Task { @MainActor in
                for await _ in timer {
                    if !self.data.isLoading() {
                        Task {
                            try? await self.loadInBackground(
                                setting: RefreshSettings(
                                    reason: "Timer",
                                    debounceSettings: .default,
                                    resetLast: false
                                )
                            )
                        }
                    }
                }
            }
            task.store(in: timerBag)
        }
    }
}

public extension LoadableCollectionStore {
    /// Replaces all items in the collection without triggering a fetch.
    ///
    /// Processes the items through the dataProvider's content processor.
    ///
    /// - Parameter items: The new collection of items
    @MainActor
    final func replaceAllItems(_ items: [Model]) async {
        let processed = try? await dataProvider.processContent(items)
        data.set(newValue: processed ?? items)
    }

    /// Updates an existing item in the local collection.
    ///
    /// If the item exists, replaces it and optionally moves it to a new index.
    ///
    /// - Parameters:
    ///   - item: The updated item
    ///   - newIndex: Optional new index for the item (uses original index if nil)
    /// - Returns: The index where the item was found, or nil if not found
    @MainActor
    @discardableResult
    final func updateLocalItem(_ item: Model, newIndex: Int? = nil) async -> Int? {
        var items = data.value ?? []
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
            if let newIndex {
                items.insert(item, at: newIndex)
            } else {
                items.insert(item, at: index)
            }
            await replaceAllItems(items)
            return index
        }
        return nil
    }

    /// Removes items at the specified indices from the local collection.
    ///
    /// - Parameter indexSet: The indices of items to remove
    @MainActor
    final func removeLocalItems(at indexSet: IndexSet) {
        data.delete(at: indexSet)
    }

    /// Removes an item by ID from the local collection.
    ///
    /// - Parameter objectId: The ID of the item to remove
    /// - Returns: The removed item, or nil if not found
    @MainActor
    @discardableResult
    final func removeLocalItem(withId objectId: Model.ID) -> Model? {
        if let index = getLocalItemIndex(withId: objectId) {
            let item = getLocalItem(withId: objectId)
            removeLocalItems(at: IndexSet(integer: index))
            return item
        } else {
            return nil
        }
    }

    /// Finds the index of an item by ID in the local collection.
    ///
    /// - Parameter objectId: The ID of the item to find
    /// - Returns: The index of the item, or nil if not found
    @MainActor
    final func getLocalItemIndex(withId objectId: Model.ID) -> Int? {
        return data.value?.firstIndex(where: { $0.id == objectId })
    }

    /// Gets an item at a specific index from the local collection.
    ///
    /// - Parameter index: The index of the item
    /// - Returns: The item at the specified index, or nil if out of bounds
    @MainActor
    final func getLocalItem(at index: Int) -> Model? {
        data.value?[index]
    }

    /// Gets an item by ID from the local collection.
    ///
    /// - Parameter objectId: The ID of the item to get
    /// - Returns: The item with the specified ID, or nil if not found
    @MainActor
    final func getLocalItem(withId objectId: Model.ID) -> Model? {
        if let index = getLocalItemIndex(withId: objectId) {
            return data.value![index]
        }
        return nil
    }

    /// Inserts an item at a specific index in the local collection.
    ///
    /// If an item with the same ID already exists, updates it and moves it to the new index.
    /// Emits a `.willAddItems` event before insertion.
    ///
    /// - Parameters:
    ///   - item: The item to insert
    ///   - index: The index where to insert the item
    @MainActor
    final func insertLocalItem(_ item: Model, at index: Int) async {
        if let _ = getLocalItemIndex(withId: item.id) {
            _ = await updateLocalItem(item, newIndex: index)
            return
        }
        var new = data.value ?? []
        new.insert(item, at: index)

        await eventsEmitter.emitEvent(.willAddItems([item]))
        await replaceAllItems(new)
    }

    /// Appends items to the end of the local collection.
    ///
    /// Emits a `.willAddItems` event before appending.
    ///
    /// - Parameter items: The items to append
    @MainActor
    final func appendLocalItems(_ items: [Model]) async {
        let current = data.value ?? []
        let new = current + items
        await eventsEmitter.emitEvent(.willAddItems(items))
        await replaceAllItems(new)
    }
}
