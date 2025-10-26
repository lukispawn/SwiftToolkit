//
//  LoadedStore.swift
//  SwiftDataTest
//
//  Created by Lukasz Zajdel on 07/11/2023.
//

import AsyncAlgorithms
import Combine
import Foundation
import SwiftToolkit
import os
import SwiftUI

#if os(iOS)
import UIKit
#endif

@Observable
public class LoadableElementStore<Model: Sendable>: LoadableModelSupport, @unchecked Sendable {
    public enum Event: Sendable {
        case didFetch(Model)
        case didUpdateState(LoadedElementStatus<Model>)
    }

    public struct Configuration: Sendable {
        var refreshInterval: TimeInterval?
        var debounceReloadValue: TimeInterval
        var debug: Bool
        var prefix: String?
        var refreshTriggers: Set<RefreshTrigger>

        public init(
            refreshInterval: TimeInterval? = nil,
            debounceReloadValue: TimeInterval = 0.5,
            debug: Bool = false,
            prefix: String? = nil,
            refreshTriggers: Set<RefreshTrigger> = Set(RefreshTrigger.allCases)
        ) {
            self.refreshInterval = refreshInterval
            self.debounceReloadValue = debounceReloadValue
            self.debug = debug
            self.prefix = prefix
            self.refreshTriggers = refreshTriggers
        }
    }

    // @MainActor
    private var service: any LoadableElementProvider<Model>

    @MainActor
    public private(set) var data: LoadedElementStatus<Model> {
        didSet {
            Task {
                await eventsEmitter.emitEvent(.didUpdateState(data))
            }
            self.logger.info("[state] update state:\(data.debugStatus)")
        }
    }

    @MainActor
    public var loadState: LoadableState {
        data.state
    }

    private let eventsEmitter = EventStreamMultiplexer<Event>()

    /// Creates an async stream of store events.
    ///
    /// Events include data fetches and state updates.
    ///
    /// - Returns: AsyncStream of Event instances
    public func eventsSequence(
    ) async ->  AsyncStream<Event> {
        await eventsEmitter.createEventStream()
    }

    /// Creates an async stream of store events.
    ///
    /// Events include data fetches and state updates.
    ///
    /// - Returns: AsyncStream of Event instances
    public func eventsStream() async -> AsyncStream<Event>{
        await eventsEmitter.createEventStream()
    }

    @ObservationIgnored
    private let loadBag = AsyncCancelBag()

    @ObservationIgnored
    private let refreshBag = CombineCancelBag()

    @ObservationIgnored
    private let timerBag = CombineCancelBag()

    @ObservationIgnored
    let configuration: Configuration

    @ObservationIgnored
    private var debounceReloadValue: TimeInterval {
        configuration.debounceReloadValue
    }

    @ObservationIgnored
    private var refreshInterval: TimeInterval? {
        configuration.refreshInterval
    }

    private let logger: LoggerWrapper

    @ObservationIgnored
    private let debounceReload: DebounceAsync = .init()

    /// Creates a store with a constant value that never changes.
    ///
    /// - Parameters:
    ///   - value: The constant value to store
    ///   - inMemory: If true, disables any persistence layer
    ///   - configuration: Store configuration for refresh triggers, debounce, etc.
    ///   - logger: Optional custom logger for debugging
    public convenience init(
        constant value: Model,
        inMemory: Bool = false,
        configuration: Configuration = .init(),
        logger: LoggerWrapper? = nil
    ) {
        self.init(
            service: DefaultElementProvider(
                value: value,
                configuration: .init(inMemory: inMemory)
            ),
            data: .loaded(value),
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
    ///   - configuration: Store configuration for refresh triggers, debounce, etc.
    ///   - logger: Optional custom logger for debugging
    public convenience init(
        error: Error,
        configuration: Configuration = .init(),
        logger: LoggerWrapper? = nil
    ) {
        self.init(
            service: DefaultElementProvider(error: error),
            data: .failed(error),
            configuration: configuration,
            logger: logger
        )
    }

    /// Creates a store with an async operation to fetch data.
    ///
    /// - Parameters:
    ///   - operation: Async closure that fetches the data
    ///   - initial: Optional initial value to display before first fetch
    ///   - inMemory: If true, disables any persistence layer
    ///   - configuration: Store configuration for refresh triggers, debounce, etc.
    ///   - logger: Optional custom logger for debugging
    public convenience init(
        operation: @escaping (() async throws -> Model),
        initial: Model?,
        inMemory: Bool = false,
        configuration: Configuration = .init(),
        logger: LoggerWrapper? = nil
    ) {
        self.init(
            service: DefaultElementProvider(operation: operation, configuration: .init(inMemory: inMemory)),
            data: {
                if let initial {
                    return .loaded(initial)
                } else {
                    return .notRequested
                }
            }(),
            configuration: configuration,
            logger: logger
        )
    }

    /// Creates a store with a custom provider service.
    ///
    /// This is the designated initializer that allows full customization.
    ///
    /// - Parameters:
    ///   - service: Custom provider conforming to LoadableElementProvider
    ///   - data: Initial data state (defaults to .notRequested)
    ///   - configuration: Store configuration for refresh triggers, debounce, etc.
    ///   - logger: Optional custom logger for debugging
    public init(
        service: any LoadableElementProvider<Model>,
        data: LoadedElementStatus<Model> = .notRequested,
        configuration: Configuration = .init(),
        logger: LoggerWrapper? = nil
    ) {
        _service = service
        _data = data
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
    /// Automatically loads data if not already loaded or in error state.
    /// Respects the `refreshOnTask` trigger setting - if disabled, won't refresh
    /// already-loaded data.
    ///
    /// This method uses `reload()` internally, so it properly respects task cancellation
    /// when the view disappears.
    ///
    /// - Note: Skips loading if already in loading or error state
    @MainActor
    public final func onTask() async {
        self.logger.info("[onTask] status: \(data.debugStatus)")

        if self.data.isLoading() {
            return
        }
        if self.data.isError() {
            return
        }

        // Skip refresh if already loaded and refreshOnTask trigger is disabled
        if self.data.isLoaded() && !configuration.refreshTriggers.contains(.refreshOnTask) {
            return
        }

        _ = try? await reload(setting: .init(reason: "onTask"))
    }

    /// Cancels all ongoing operations including loads, debounces, and observers.
    ///
    /// Useful for cleanup or when you need to stop all pending operations.
    public func cancel() async {
        self.logger.info("[Cancel]")
        refreshBag.cancel()
        timerBag.cancel()
        await loadBag.cancel()
        await debounceReload.cancel()
    }

    private func destroyObservers() {
        self.logger.info("[Destroy observers]")

        refreshBag.cancel()
        timerBag.cancel()

        loadBag.cancelSync()
        debounceReload.cancelSync()
    }

    // --------------
}

public extension LoadableElementStore {
    
    /// Updates the data source and refreshes the data.
    ///
    /// - Parameters:
    ///   - source: New provider conforming to LoadableElementProvider
    ///   - setting: Refresh settings (debounce, resetLast, reason)
    @MainActor
    final func updateSource(
        source: any LoadableElementProvider<Model>,
        setting: RefreshSettings = .init(debounce: false, resetLast: true)
    ) async throws {
        self.service = source
        return try await self.refresh(setting: setting)
    }
    
    /// Updates the data source to use a new operation and refreshes the data.
    ///
    /// - Parameters:
    ///   - operation: New async closure that fetches the data
    ///   - inMemory: If true, disables any persistence layer
    ///   - setting: Refresh settings (debounce, resetLast, reason)
    @MainActor
    final func updateSource(
        operation: @escaping (() async throws -> Model),
        inMemory: Bool = false,
        setting: RefreshSettings = .init(debounce: false, resetLast: true)
    ) async throws {
        
        try await updateSource(
            source: DefaultElementProvider(operation: operation, configuration: .init(inMemory: inMemory)),
            setting: setting
        )
    }
    
    /// Updates the data source to a constant value and refreshes the data.
    ///
    /// - Parameters:
    ///   - value: New constant value to use
    ///   - inMemory: If true, disables any persistence layer
    ///   - setting: Refresh settings (debounce, resetLast, reason)
    @MainActor
    final func updateSource(
        constant value: Model,
        inMemory: Bool = false,
        setting: RefreshSettings = .init(debounce: false, resetLast: true)
    ) async throws {
        try await updateSource(
            source: DefaultElementProvider(value: value, configuration: .init(inMemory: inMemory)),
            setting: setting
        )
    }

    
    /// Updates the data source to always return an error and refreshes the data.
    ///
    /// - Parameters:
    ///   - error: The error to return
    ///   - setting: Refresh settings (debounce, resetLast, reason)
    @MainActor
    final func updateSource(
        error:  Error,
        setting: RefreshSettings = .init(debounce: false, resetLast: true)
    ) async throws {
        try await updateSource(
            source: DefaultElementProvider(error: error),
            setting: setting
        )
    }
}
public extension LoadableElementStore {
    

    /// Triggers a fire-and-forget refresh operation.
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
    ///         try? await store.refresh(setting: .init(reason: "User tap"))
    ///         // Returns immediately, doesn't wait for completion
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter setting: Refresh settings including debounce option
    /// - Note: Use `reload()` if you need to wait for completion or want proper cancellation
    final func refresh(setting: RefreshSettings) async throws {
        self.logger.info("[refresh] [\(setting.debounce ? "debounce" : "force")] reason: \(setting.reason)")

        if setting.debounce {
            await reloadDebounce(setting: setting)
        } else {
            await debounceReload.cancel()
            Task(priority: .userInitiated) {
                _ = try? await reloadForce(setting: setting)
            }
        }
    }

    /// Triggers a reload operation and waits for completion.
    ///
    /// This method waits for the reload to complete and returns the loaded data.
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
    /// .task {
    ///     do {
    ///         let data = try await store.reload(setting: .init(reason: "View appeared"))
    ///         // `data` is available here, and this properly cancels if view disappears
    ///     } catch {
    ///         print("Failed to load: \(error)")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter setting: Reload settings (no debounce option)
    /// - Returns: The loaded data
    /// - Throws: Any error that occurred during loading
    /// - Note: This method cannot be debounced - it always executes immediately
    @discardableResult
    final func reload(setting: ReloadSettings) async throws -> Model {
        self.logger.info("[reload] reason: \(setting.reason)")
        return try await reloadForce(setting: setting)
    }

    private final func reloadForce(setting: any LoadSettings) async throws -> Model {
        self.logger.info("[reload] [force]: \(setting.reason)")
        await debounceReload.cancel()
        return try await self.executeLoad(setting: setting)
    }

    private final func reloadDebounce(setting: RefreshSettings) async {
        self.logger.info("[reload] [debounce] reason: \(setting.reason)")

        if await data.isNotRequested() == false {
            await loadBag.cancel()
            await MainActor.run {
                data.setIsLoading(resetLast: setting.resetLast)
            }
            await debounceReload.schedule(after: debounceReloadValue) {
                _ = try? await self.executeLoad(setting: setting)
            }
        } else {
            self.logger.info("[reload] [debounce] reason: \(setting.reason) | switch to force reload")
            Task(priority: .userInitiated) {
                _ = try? await self.reloadForce(setting: setting)
            }
        }
    }
}

public extension LoadableElementStore {
    /// Manually sets the data without triggering a fetch operation.
    ///
    /// Updates the store's state to `.loaded` with the provided value.
    ///
    /// - Parameter value: The new data value to set
    @MainActor
    final func setData(_ value: Model) async {
        data.set(newValue: value)
    }
}

extension LoadableElementStore {
    @discardableResult
    private func executeLoad(setting: any LoadSettings) async throws -> Model {
        if case .provide(let providedResult) = await service.willLoad(previous: data) {
            await MainActor.run {
                switch providedResult {
                case .success(let model):
                    self.data = .loaded(model)
                case .failure(let error):
                    self.data = .failed(error)
                }
            }
            return try providedResult.get()
        }

        self.logger.info("[load] [shedule] reason:\(setting.reason)")

        await loadBag.cancel()
        
        await MainActor.run {
            data.setIsLoading(resetLast: setting.resetLast)
        }

        let task = Task.detached(priority: .userInitiated) { [self] in 
           
            //try await Task.sleep(nanoseconds: UInt64(5 * 1_000_000_000))
            //try Task.checkCancellation()
            
            let startTime = Date()
            self.logger.info("[load] [run] reason:\(setting.reason)")
            do {
                
                try Task.checkCancellation()
                
                let value = try await service.load()

                try Task.checkCancellation()

                self.logger.info("[load] [end] success | fetch time:\(abs(startTime.timeIntervalSinceNow))")

                await MainActor.run {
                    data = .loaded(value)
                }
                await eventsEmitter.emitEvent(.didFetch(value))

                return value

            } catch {
                if let existingValue = await self.data.value, Task.isCancelled {
                    await MainActor.run {
                        self.logger.error("[load] [end] isCancelled")
                        data = .loaded(existingValue)
                    }
                    return existingValue
                }

                await MainActor.run {
                    self.logger.error("[load] [end] fail:\(error) fetch time:\(abs(startTime.timeIntervalSinceNow))")
                    data = .failed(error)
                }

                throw error
            }
        }
       
        await loadBag.insert(task.eraseToAnyCancellable())
        
        return try await task.value
    }

}

extension LoadableElementStore {
    private func observeRefresh() {
        if configuration.refreshTriggers.contains(.reachability) {
            if let manager = LoadableReachabilityFactory.defaultManager {
                manager.start()
                manager.reachabilityChanged
                    .filter { $0 == .wifi || $0 == .cellular }
                    .removeDuplicates()
                    .sink(receiveValue: { [weak self] _ in
                        guard let self else { return }
                        Task { @MainActor in
                            if self.data.isError() {
                                try? await self.refresh(setting: .init(reason: "Reachability changed", debounce: true, resetLast: false))
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
                    // ...
                    if !self.data.isLoading() {
                        Task {
                            try? await self.refresh(setting: .init(reason: "Timer", debounce: true, resetLast: false))
                        }
                    }
                }
            }
            task.store(in: timerBag)
        }
    }
}
