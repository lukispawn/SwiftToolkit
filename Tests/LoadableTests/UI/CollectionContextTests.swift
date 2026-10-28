import Observation
import Testing
@testable import Loadable

@MainActor
@Suite("Collection UI contexts", .timeLimit(.minutes(1)))
struct CollectionContextTests {
    @Test func frozenStoresHaveNoRequestActionsEvenWithCursorsAndErrors() async {
        let source = ControlledCollectionSource()
        let store = CollectionStore(source: source, constantSnapshot: .init(
            items: [Row(1)], phase: .failed(.offline, operation: .page(.next)), nextCursor: 2, hasLoaded: true))
        let context = LoadableUI.CollectionContext(store: store)
        #expect(!context.canRefresh)
        #expect(context.failure?.retry == nil)
        #expect(context.pagination.state == .failed)
        context.retry()
        context.pagination.retry()
        context.pagination.load()
        context.reload()
        context.startIfNeeded()
        await context.refresh()
        #expect(await source.calls.isEmpty)
    }

    @Test func frozenLoadedCursorsDoNotAdvertisePagination() {
        let store = CollectionStore(source: ControlledCollectionSource(),
                                    constantSnapshot: .loaded([Row(1)], nextCursor: 2, previousCursor: 0))
        let context = LoadableUI.CollectionContext(store: store)
        #expect(context.pagination.state == .hidden)
        #expect(context.pagination(.previous).state == .hidden)
    }

    @Test func injectedContextReadsLiveItemsAndMetadata() async throws {
        let (store, _) = try await seededCollection()
        let context = LoadableUI.CollectionContext(store: store)
        #expect(context.query == "A")
        #expect(context.totalCount == 100)
        store.setItems([Row(8)], totalCount: 1)
        #expect(context.items == [Row(8)])
        #expect(context.totalCount == 1)
        #expect(context.pagination.state == .hidden)
    }

    @Test func disabledAutomaticStartDoesNotCreateRequest() async {
        let source = ControlledCollectionSource()
        let context = LoadableUI.CollectionContext(store: CollectionStore(source: source),
                                                configuration: .init(startsAutomatically: false))
        context.startIfNeeded()
        #expect(await source.calls.isEmpty)
        #expect(context.presentation.state == .idle)
    }

    @Test func repeatedAutomaticStartDoesNotSupersedeRequest() async throws {
        let source = ControlledCollectionSource()
        let store = CollectionStore(source: source)
        let context = LoadableUI.CollectionContext(store: store)
        context.startIfNeeded()
        let request = try #require(store.requestTask)
        context.startIfNeeded()
        await source.waitForCalls(1)
        await source.complete(0, .success(.init(items: [Row(1)])))
        _ = await request.result
        context.startIfNeeded()
        #expect(await source.calls.count == 1)
    }

    @Test(arguments: [LoadableUI.Configuration.Pagination.manual, .disabled])
    func nonAutomaticModesIgnoreRowAppearance(mode: LoadableUI.Configuration.Pagination) async throws {
        let (store, source) = try await seededCollection()
        let context = LoadableUI.CollectionContext(store: store, configuration: .init(pagination: mode))
        context.itemAppeared(Row(1))
        #expect(store.requestTask == nil)
        #expect(await source.calls.count == 1)
        #expect(context.pagination.state == (mode == .disabled ? .hidden : .available))
    }

    @Test func automaticPrefetchAndRepeatedAppearancesUseOneRequest() async throws {
        let (store, source) = try await seededCollection()
        let context = LoadableUI.CollectionContext(store: store)
        context.itemAppeared(Row(999))
        #expect(store.requestTask == nil)
        context.itemAppeared(Row(1))
        let request = try #require(store.requestTask)
        context.itemAppeared(Row(1))
        #expect(context.pagination.state == .loading)
        await source.waitForCalls(2)
        await source.complete(1, .success(.init(items: [Row(2)])))
        _ = await request.result
        #expect(await source.calls.count == 2)
    }

    @Test(arguments: LoadableCollection.Direction.allCases)
    func manualPageActionRespectsDirectionAndRetry(direction: LoadableCollection.Direction) async throws {
        let (store, source) = try await seededCollection(next: 2, previous: 0)
        let context = LoadableUI.CollectionContext(store: store, configuration: .init(pagination: .manual))
        let pagination = context.pagination(direction)
        #expect(pagination.state == .available)
        pagination.load()
        let request = try #require(store.requestTask)
        #expect(pagination.state == .loading)
        await source.waitForCalls(2)
        await source.complete(1, .failure(.offline))
        _ = await request.result
        #expect(pagination.state == .failed)
        #expect(pagination.failure?.operation == .page(direction))
        #expect(pagination.failure?.retry != nil)
        #expect(context.refreshFailure == nil)
        #expect(context.presentation.state == .content)
        #expect(context.pagination(direction == .next ? .previous : .next).state == .hidden)
        pagination.retry()
        let retry = try #require(store.requestTask)
        #expect(pagination.failure == nil)
        await source.waitForCalls(3)
        await source.complete(2, .success(.init(items: [Row(2)])))
        _ = await retry.result
        let calls = await source.calls
        #expect(calls[1] == calls[2])
    }

    @Test func disabledPaginationSuppressesCommandsAndFailurePresentation() async throws {
        let (store, source) = try await seededCollection()
        let context = LoadableUI.CollectionContext(store: store, configuration: .init(pagination: .disabled))
        context.pagination.load()
        #expect(store.requestTask == nil)
        store.loadMore()
        let request = try #require(store.requestTask)
        await source.waitForCalls(2)
        await source.complete(1, .failure(.offline))
        _ = await request.result
        #expect(context.pagination.state == .hidden)
        #expect(context.pagination.failure == nil)
        context.pagination.retry()
        #expect(store.requestTask == nil)
    }

    @Test func refreshFailureIsSeparateFromPageFailuresAndRetainsRows() async throws {
        let (store, source) = try await seededCollection()
        let context = LoadableUI.CollectionContext(store: store)
        let refresh = Task { await context.refresh() }
        await source.waitForCalls(2)
        #expect(context.presentation.isRefreshing)
        #expect(context.items == [Row(1)])
        #expect(context.pagination.state == .hidden)
        await source.complete(1, .failure(.offline))
        await refresh.value
        #expect(context.refreshFailure?.error == .offline)
        #expect(context.refreshFailure?.retry != nil)
        #expect(context.items == [Row(1)])
        #expect(context.pagination.state == .hidden)
        store.cancel()
        #expect(context.refreshFailure?.retry == nil)
        context.retry()
        #expect(store.requestTask == nil)
    }

    @Test func disabledRefreshIsNoOp() async throws {
        let (store, source) = try await seededCollection()
        let context = LoadableUI.CollectionContext(store: store, configuration: .init(isRefreshable: false))
        #expect(!context.canRefresh)
        await context.refresh()
        #expect(await source.calls.count == 1)
    }

    @Test func endedSessionDoesNotAdvertiseLoadMoreDespiteSnapshotCursor() async throws {
        let (store, _) = try await seededCollection()
        let context = LoadableUI.CollectionContext(store: store)
        store.cancel()
        #expect(store.snapshot.nextCursor != nil)
        #expect(context.pagination.state == .hidden)
    }

    @Test func boundedEmptyContinuationStillOffersExplicitLoadMore() async throws {
        let source = ControlledCollectionSource()
        let store = CollectionStore(source: source, configuration: .init(emptyPageFetchLimit: 0))
        let context = LoadableUI.CollectionContext(store: store)
        context.startIfNeeded()
        let first = try #require(store.requestTask)
        await source.waitForCalls(1)
        await source.complete(0, .success(.init(items: [], nextCursor: 1)))
        _ = await first.result
        #expect(context.presentation.state == .content)
        #expect(context.pagination.state == .available)
        context.pagination.load()
        let next = try #require(store.requestTask)
        await source.waitForCalls(2)
        await source.complete(1, .success(.init(items: [Row(1)])))
        _ = await next.result
        #expect(context.items == [Row(1)])
        #expect(context.pagination.state == .hidden)
    }

    @Test func retryAvailabilityParticipatesInObservation() async throws {
        let source = ControlledCollectionSource()
        let store = CollectionStore(source: source)
        store.start()
        let request = try #require(store.requestTask)
        await source.waitForCalls(1)
        await confirmation("Retry availability changes with a failed request") { changed in
            withObservationTracking { _ = store.canRetry } onChange: { changed() }
            await source.complete(0, .failure(.offline))
            _ = await request.result
        }
        #expect(store.canRetry)
        let context = LoadableUI.CollectionContext(store: store)
        #expect(context.presentation.state == .failed)
        #expect(context.failure?.retry != nil)
        context.retry()
        let retry = try #require(store.requestTask)
        #expect(!store.canRetry)
        await source.waitForCalls(2)
        await source.complete(1, .success(.init(items: [])))
        _ = await retry.result
        #expect(context.presentation.state == .empty)
        #expect(!store.canRetry)
    }

    @Test func nestedContextChangesParticipateInObservation() async throws {
        let (store, source) = try await seededCollection()
        let context = LoadableUI.CollectionContext(store: store)
        await confirmation("Pagination context observes the injected store") { changed in
            withObservationTracking { _ = context.pagination.state } onChange: { changed() }
            context.itemAppeared(Row(1))
        }
        let request = try #require(store.requestTask)
        await source.waitForCalls(2)
        await source.complete(1, .success(.init(items: [Row(2)])))
        _ = await request.result
    }

    @Test func releasingContextDoesNotCancelSharedStore() async throws {
        let (store, source) = try await seededCollection()
        do {
            let context = LoadableUI.CollectionContext(store: store)
            context.pagination.load()
        }
        let request = try #require(store.requestTask)
        #expect(!request.isCancelled)
        await source.waitForCalls(2)
        await source.complete(1, .success(.init(items: [Row(2)])))
        _ = await request.result
        #expect(store.items == [Row(1), Row(2)])
    }
}
