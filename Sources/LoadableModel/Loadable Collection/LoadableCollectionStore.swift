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
>: @unchecked Sendable where Model.ID: Sendable  {
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
        
        public init(
            refreshInterval: TimeInterval? = nil,
            debounceReloadValue: TimeInterval = 0.5,
            itemRefreshThrottleInterval: TimeInterval = 0.5,
            debug: Bool = false,
            prefix: String? = nil
        ) {
            self.refreshInterval = refreshInterval
            self.debounceReloadValue = debounceReloadValue
            self.itemRefreshThrottleInterval = itemRefreshThrottleInterval
            self.debug = debug
            self.prefix = prefix
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
                await eventsEmitter.send(.didUpdateState(data))
            }
            self.logger.info("[state] update state:\(data.debugStatus)")
        }
    }
    
    @MainActor
    public var loadState: LoadableState { data.state }

    private let eventsEmitter = MulticastAsyncStream<Event>()
    
    public func eventsSequence(
    ) async ->  any AsyncSequence<Event, Never> {
        await eventsEmitter.subscribe()
    }
    public func eventsStream() async -> AsyncStream<Event>{
        await eventsEmitter.subscribe()
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

    public final func onTask() async {
        self.logger.info("[onTask] status: \(await data.debugStatus)")

        if await self.data.isLoading(), await self.data.query == lastSetQuery {
            return
        }
        
        try? await refresh(query: lastSetQuery, setting: .init(reason: "onTask", debounce: false))
    }

    public final func onTask(query: Query, debounce: Bool) async throws {
        self.logger.info("[onTask] status: \(await data.debugStatus)")
        
        if await self.data.isLoading(), await self.data.query == query {
            return
        }
        
        try? await refresh(query: lastSetQuery, setting: .init(reason: "onTask(query:)", debounce: debounce))
    }

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
        return try await self.refresh(setting: setting)
    }
    
    public final func refresh(setting: RefreshSettings) async throws {
        try await refresh(query: lastSetQuery, setting: setting)
    }
    
    public final func refresh(query: Query?, setting: RefreshSettings) async throws {
        self.logger.info("[refresh] [\(setting.debounce ? "debounce" : "force")] reason: \(setting.reason) state:\(await data.debugStatus)")

        if setting.debounce {
            await reloadDebounce(query: query, setting: setting)
        } else {
            await debounceReload.cancel()
            Task(priority: .userInitiated) {
                _ = try? await reloadForce(query: query, setting: setting)
            }
        }
    }
    
    private final func reloadForce(query: Query?, setting: RefreshSettings) async throws -> [Model] {
        self.logger.info("[reload] [force] reason: \(setting.reason) query:\(query.debugDescription)")
        self.lastSetQuery = query
        await debounceReload.cancel()
        return try await self.executeLoad(setting: setting, query: query)
    }
    
    private final func reloadDebounce(query: Query?, setting: RefreshSettings) async {
        self.logger.info("[reload] [debounce] reason: \(setting.reason) query:\(query.debugDescription)")
        self.lastSetQuery = query
        if await data.isNotRequested() == false {
            await loadBag.cancel()
            await MainActor.run {
                data.setIsLoading(cursor: nil, query: query, resetLast: setting.resetLast)
            }
            
            await debounceReload.schedule(after: debounceReloadValue) {
                _ = try? await self.executeLoad(setting: setting, query: query)
            }
        } else {
            self.logger.info("[reload] [debounce] reason: \(setting.reason) | switch to force reload")
            _ = try? await self.reloadForce(query: query, setting: setting)
        }
    }
    
    // ----------------------------------------
    
    @MainActor
    public final func isLoaded() -> Bool {
        return self.data.isLoaded()
    }

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
    
    @MainActor
    public final func isPageLoading(type: LoadableArrayPageCursorType) -> Bool {
        switch type {
        case .next:
            return data.isLoadingNext()
        case .previous:
            return data.isLoadingPrevious()
        }
    }
    
    @MainActor
    public final func isPageLoadingEnabled(type: LoadableArrayPageCursorType) -> Bool {
        guard isLoaded() else { return false }
        guard isPageLoading(type: type) == false else { return false }
        return cursorCandidate(type: type) != nil
    }

    @MainActor
    public final func isPageAvailable(type: LoadableArrayPageCursorType) -> Bool {
        cursorCandidate(type: type) != nil
    }
    
    @MainActor
    public final func loadCoursor(type: LoadableArrayPageCursorType) async throws {
        guard isPageLoading(type: type) == false else { return }
        guard let candidate = cursorCandidate(type: type) else { return }
        guard validateCusorCandidate(candidate, type: type) else { return }
        try await executeLoadCursor(cursor: candidate, cursorType: type)
    }
}

extension LoadableCollectionStore {
    // -------------
    @discardableResult
    private func executeLoad(
        setting: RefreshSettings,
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
               
                await eventsEmitter.send(.didFetch(value.data))
                
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
                    try? await refresh(setting: .init(reason: "Delete Object Request fail", debounce: true, resetLast: false))
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
    @MainActor
    final func isModificationSupported() -> Bool {
        return modifierService != nil
    }
    
    @MainActor
    func setModifierService(_ modifierService: any LoadableCollectionModifier<Model>) {
        self.modifierService = modifierService
    }
}

extension LoadableCollectionStore {
    private func observeRefresh() {
        if let manager = LoadableReachabilityFactory.defaultManager {
            manager.start()
            manager.reachabilityChanged
                .filter { $0 == .wifi || $0 == .cellular }
                .removeDuplicates()
                .sink(receiveValue: { [weak self] _ in
                    guard let self else { return }
                    Task {
                        if await self.data.isError() {
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
                    self?.reload(reason: "Will Enter Foreground notification", debounce: true)
                }).store(in: refreshBag)

                NotificationCenter.default.publisher(
                    for: UIApplication.significantTimeChangeNotification
                ).sink(receiveValue: { [weak self] _ in
                    self?.reload(reason: "Significant Time Change notification", debounce: true)
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

public extension LoadableCollectionStore {
    @MainActor
    final func replaceAllItems(_ items: [Model]) async {
        let processed = try? await dataProvider.processContent(items)
        data.set(newValue: processed ?? items)
    }

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

    @MainActor
    final func removeLocalItems(at indexSet: IndexSet) {
        data.delete(at: indexSet)
    }

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

    @MainActor
    final func getLocalItemIndex(withId objectId: Model.ID) -> Int? {
        return data.value?.firstIndex(where: { $0.id == objectId })
    }

    @MainActor
    final func getLocalItem(at index: Int) -> Model? {
        data.value?[index]
    }

    @MainActor
    final func getLocalItem(withId objectId: Model.ID) -> Model? {
        if let index = getLocalItemIndex(withId: objectId) {
            return data.value![index]
        }
        return nil
    }

    @MainActor
    final func insertLocalItem(_ item: Model, at index: Int) async {
        if let _ = getLocalItemIndex(withId: item.id) {
            _ = await updateLocalItem(item, newIndex: index)
            return
        }
        var new = data.value ?? []
        new.insert(item, at: index)
        
        await eventsEmitter.send(.willAddItems([item]))
        await replaceAllItems(new)
    }

    @MainActor
    final func appendLocalItems(_ items: [Model]) async {
        let current = data.value ?? []
        let new = current + items
        await eventsEmitter.send(.willAddItems(items))
        await replaceAllItems(new)
    }
}
