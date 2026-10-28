import Observation
import Testing
@testable import Loadable

@MainActor @Observable
private final class MultiStoreModel: LoadableStateProviding {
    let value: LoadableValueStore<ControlledValueSource<String, String>>
    let collection: CollectionStore

    var loadableState: LoadableState { .merge(stores: [value, collection]) }

    init(valueSource: ControlledValueSource<String, String>, collectionSource: ControlledCollectionSource) {
        value = .init(source: valueSource)
        collection = .init(source: collectionSource)
    }
}

@MainActor @Observable
private final class StateProvider: LoadableStateProviding {
    var loadableState: LoadableState = .idle
}

@MainActor
@Suite("Aggregated state Observation and lifecycle", .timeLimit(.minutes(1)))
struct StateObservationTests {
    @Test(arguments: [true, false])
    func viewModelTracksBothHeterogeneousStoresUntilAllAreReady(valueFirst: Bool) async throws {
        let valueSource = ControlledValueSource<String, String>()
        let collectionSource = ControlledCollectionSource()
        let model = MultiStoreModel(valueSource: valueSource, collectionSource: collectionSource)
        #expect(model.loadableState.phase == .idle)
        model.value.start(query: "A")
        model.collection.start(query: "A")
        let valueTask = try #require(model.value.requestTask)
        let collectionTask = try #require(model.collection.requestTask)
        await valueSource.waitForCalls(1)
        await collectionSource.waitForCalls(1)
        await confirmation("First completion reaches aggregate through nested Observation") { changed in
            withObservationTracking { _ = model.loadableState.phase } onChange: { changed() }
            if valueFirst {
                await valueSource.complete(0, .success("Profile"))
                _ = await valueTask.result
            } else {
                await collectionSource.complete(0, .success(.init(items: [])))
                _ = await collectionTask.result
            }
        }
        #expect(model.loadableState.phase == .loading)
        #expect(model.loadableState.loadedStoreCount == 1)
        await confirmation("Second completion makes the entire screen ready") { changed in
            withObservationTracking { _ = model.loadableState.hasLoaded } onChange: { changed() }
            if valueFirst {
                await collectionSource.complete(0, .success(.init(items: [])))
                _ = await collectionTask.result
            } else {
                await valueSource.complete(0, .success("Profile"))
                _ = await valueTask.result
            }
        }
        #expect(model.loadableState.phase == .loaded)
        #expect(model.loadableState.storeCount == 2)
        #expect(model.loadableState.loadedStoreCount == 2)
    }

    @Test func heterogeneousReadIsEagerEvenWhenFirstProviderDeterminesPhase() async {
        let first = StateProvider()
        let second = StateProvider()
        first.loadableState = .init(hasLoaded: false, error: TestFailure.offline)
        await confirmation("Later providers remain observed behind a blocking failure") { changed in
            withObservationTracking { _ = LoadableState.merge(stores: [first, second]).phase }
                onChange: { changed() }
            second.loadableState = .loaded
        }
        let state = LoadableState.merge(stores: [first, second])
        #expect(state.phase == .failed)
        #expect(state.loadedStoreCount == 1)
    }

    @Test func nestedGroupsParticipateInObservationWithoutSubscriptions() async {
        let a = StateProvider()
        let b = StateProvider()
        let c = StateProvider()
        a.loadableState = .loaded
        b.loadableState = .loaded
        await confirmation("Nested merge reads all source properties") { changed in
            withObservationTracking {
                _ = LoadableState.merge([.merge(stores: [a, b]), c.loadableState]).hasLoaded
            } onChange: { changed() }
            c.loadableState = .loaded
        }
        #expect(LoadableState.merge([.merge(stores: [a, b]), c.loadableState]).phase == .loaded)
    }

    @Test func retainedRefreshAndPageFailuresKeepWholeScreenReady() async throws {
        let (collection, collectionSource) = try await seededCollection(next: 2)
        let source = ControlledValueSource<String, String>()
        let value = LoadableValueStore(source: source)
        value.setValue("Profile")
        var state: LoadableState { .merge(stores: [value, collection]) }
        #expect(state.phase == .loaded)
        value.refreshInBackground()
        let refresh = try #require(value.requestTask)
        await source.waitForCalls(1)
        #expect(state.phase == .loaded)
        #expect(state.isRefreshing)
        collection.loadMore()
        let page = try #require(collection.requestTask)
        await collectionSource.waitForCalls(2)
        #expect(state.isLoadingPage)
        await source.complete(0, .failure(.offline))
        _ = await refresh.result
        await collectionSource.complete(1, .failure(.rejected))
        _ = await page.result
        #expect(state.phase == .loaded)
        #expect(!state.isLoading)
        #expect(state.errors.count == 2)
        #expect(state.blockingFailures.isEmpty)
        #expect(state.failures.map(\.operation) == [.load, .page(.next)])
    }

    @Test func firstLoadFailureRetryAndNewQueryUpdateWholeScreen() async throws {
        let (collection, _) = try await seededCollection()
        let source = ControlledValueSource<String, String>()
        let value = LoadableValueStore(source: source)
        var state: LoadableState { .merge(stores: [value, collection]) }
        value.start(query: "A")
        let first = try #require(value.requestTask)
        await source.waitForCalls(1)
        await source.complete(0, .failure(.offline))
        _ = await first.result
        #expect(state.phase == .failed)
        #expect(state.loadedStoreCount == 1)
        value.retry()
        let retry = try #require(value.requestTask)
        await source.waitForCalls(2)
        #expect(state.phase == .loading)
        await source.complete(1, .success("Profile A"))
        _ = await retry.result
        #expect(state.phase == .loaded)
        value.start(query: "B")
        let replacement = try #require(value.requestTask)
        #expect(state.phase == .loading)
        #expect(!state.hasLoaded)
        await source.waitForCalls(3)
        await source.complete(2, .success("Profile B"))
        _ = await replacement.result
        #expect(state.phase == .loaded)
    }

    @Test func cancellationBeforeInitialResultLeavesGroupIdleAndIgnoresStaleSuccess() async throws {
        let source = ControlledValueSource<String, String>()
        let value = LoadableValueStore(source: source)
        let ready = LoadableCollectionStore(items: [Row]())
        value.start()
        let old = try #require(value.requestTask)
        await source.waitForCalls(1)
        value.cancel()
        #expect(LoadableState.merge(stores: [value, ready]).phase == .idle)
        await source.complete(0, .success("Cancelled"))
        _ = await old.result
        #expect(LoadableState.merge(stores: [value, ready]).phase == .idle)
        #expect(!value.loadableState.hasLoaded)
    }

    @Test func observingActivityStillWorksWhenPhaseRemainsLoaded() async {
        let a = StateProvider()
        let b = StateProvider()
        a.loadableState = .loaded
        b.loadableState = .loaded
        await confirmation("Background activity changes are independently observable") { changed in
            withObservationTracking { _ = LoadableState.merge(stores: [a, b]).isRefreshing }
                onChange: { changed() }
            b.loadableState = .init(hasLoaded: true, activity: .refreshing)
        }
        #expect(LoadableState.merge(stores: [a, b]).phase == .loaded)
    }

    @Test func returnedStateIsASnapshotAndDoesNotRetainProviders() {
        var provider: StateProvider? = .init()
        provider?.loadableState = .loaded
        let weakProvider = WeakReference(provider)
        let captured = LoadableState.merge(stores: [provider!])
        provider?.loadableState = .loading
        #expect(captured.phase == .loaded)
        provider = nil
        #expect(weakProvider.value == nil)
        #expect(captured.phase == .loaded)
    }

    @Test func constantOptionalNilAndEmptyCollectionMakeAReadyGroup() async {
        let value = LoadableValueStore(constant: String?.none)
        let items = LoadableCollectionStore(items: [Row]())
        #expect(value.loadableState.hasLoaded)
        #expect(items.loadableState.hasLoaded)
        let state = LoadableState.merge(stores: [value, items])
        #expect(state.phase == .loaded)
        #expect(state.loadedStoreCount == 2)
        value.reload()
        await items.refresh()
        #expect(LoadableState.merge(stores: [value, items]).phase == .loaded)
    }

    @Test func mergeDoesNotStartRequestsAndAnEmptyProviderGroupIsIdle() async {
        let valueSource = ControlledValueSource<String, String>()
        let collectionSource = ControlledCollectionSource()
        let model = MultiStoreModel(valueSource: valueSource, collectionSource: collectionSource)
        #expect(model.loadableState.phase == .idle)
        #expect(LoadableState.merge(stores: []).phase == .idle)
        #expect(model.value.requestTask == nil)
        #expect(model.collection.requestTask == nil)
        #expect(await valueSource.queries.isEmpty)
        #expect(await collectionSource.calls.isEmpty)
    }
}
