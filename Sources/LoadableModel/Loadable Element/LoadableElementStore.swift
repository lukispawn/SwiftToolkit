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

        public init(
            refreshInterval: TimeInterval? = nil,
            debounceReloadValue: TimeInterval = 0.5,
            debug: Bool = false,
            prefix: String? = nil
        ) {
            self.refreshInterval = refreshInterval
            self.debounceReloadValue = debounceReloadValue
            self.debug = debug
            self.prefix = prefix
        }
    }

    // @MainActor
    private var service: any LoadableElementProvider<Model>

    @MainActor
    public private(set) var data: LoadedElementStatus<Model> {
        didSet {
            Task {
                await eventsEmitter.send(.didUpdateState(data))
            }
            self.logger.info("[state] update state:\(data.debugStatus)")
        }
    }

    @MainActor
    public var loadState: LoadableState {
        data.state
    }

    private let eventsEmitter = MulticastAsyncStream<Event>()

    public func eventsSequence(
    ) async ->  AsyncStream<Event> {
        await eventsEmitter.subscribe()
    }
    
    public func eventsStream() async -> AsyncStream<Event>{
        await eventsEmitter.subscribe()
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

    @MainActor
    public final func onTask() async {
        self.logger.info("[onTask] status: \(data.debugStatus)")

        if self.data.isLoading() {
            return
        }
        if self.data.isError() {
            return
        }

        try? await refresh(setting: .init(reason: "onTask", debounce: false))
    }

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
    
    @MainActor
    final func updateSource(
        source: any LoadableElementProvider<Model>,
        setting: RefreshSettings = .init(debounce: false, resetLast: true)
    ) async throws {
        self.service = source
        return try await self.refresh(setting: setting)
    }
    
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

    private final func reloadForce(setting: RefreshSettings) async throws -> Model {
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
            _ = try? await self.reloadForce(setting: setting)
        }
    }
}

public extension LoadableElementStore {
    @MainActor
    final func setData(_ value: Model) async {
        data.set(newValue: value)
    }
}

extension LoadableElementStore {
    @discardableResult
    private func executeLoad(setting: RefreshSettings) async throws -> Model {
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
                await eventsEmitter.send(.didFetch(value))

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

        #if os(iOS)

        Task {
            await MainActor.run {
                NotificationCenter.default.publisher(
                    for: UIApplication.willEnterForegroundNotification
                ).sink(receiveValue: { [weak self] _ in
                    Task {
                        try? await self?.refresh(setting: .init(reason: "Will Enter Foreground notification", debounce: true, resetLast: false))
                    }
                }).store(in: refreshBag)

                NotificationCenter.default.publisher(
                    for: UIApplication.significantTimeChangeNotification
                ).sink(receiveValue: { [weak self] _ in
                    Task {
                        try? await self?.refresh(setting: .init(reason: "Significant Time Change notification", debounce: true, resetLast: false))
                    }
                }).store(in: refreshBag)
            }
        }

        #endif
    }

    private func observeTimer() {
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
