import Observation
import Testing
@testable import Loadable

/// Contract fixtures based on BluetoothKit's statistics and collection wrappers.
/// They intentionally do not import BluetoothKit or claim to migrate those screens.
@MainActor @Observable
private final class StatisticsFixture {
    let store: LoadableValueStore<ControlledValueSource<Int, Never>>
    var count: Int? { store.value }

    init(source: ControlledValueSource<Int, Never>) { store = .init(source: source) }
    func didPersist() { store.refreshInBackground() }
}

@MainActor @Observable
private final class SearchableListFixture {
    let store: LoadableCollectionStore<LoadableCollection.MappedSource<ControlledCollectionSource, Row>>
    let debouncer: LoadableQueryDebouncer<String>
    var rows: [Row] { store.items }

    init(clock: ControlledClock, source: ControlledCollectionSource) {
        let store = LoadableCollectionStore(source: source.mapItems { $0.sorted { $0.id < $1.id } })
        self.store = store
        debouncer = .init(delay: .milliseconds(300), clock: clock) { [weak store] query, mode in
            store?.start(query: query, force: mode == .immediate)
        }
    }
}

@MainActor
@Suite("Consumer migration contracts", .timeLimit(.minutes(1)))
struct ConsumerMigrationTests {
    @Test func persistenceEventRefreshesStatisticsWithoutClearingDisplayedValue() async throws {
        let source = ControlledValueSource<Int, Never>()
        let model = StatisticsFixture(source: source)
        model.store.startIfNeeded()
        await source.waitForCalls(1)
        let initial = try #require(model.store.requestTask)
        await source.complete(0, .success(10))
        _ = await initial.result
        model.didPersist()
        await source.waitForCalls(2)
        let refresh = try #require(model.store.requestTask)
        #expect(model.count == 10)
        await confirmation("Nested store updates observed by wrapper consumer") { changed in
            withObservationTracking { _ = model.count } onChange: { changed() }
            await source.complete(1, .success(11))
            _ = await refresh.result
        }
        #expect(model.count == 11)
    }

    @Test func delayedSearchSortsResultsAndExplicitSearchForcesSameQuery() async throws {
        let clock = ControlledClock()
        let source = ControlledCollectionSource()
        let model = SearchableListFixture(clock: clock, source: source)
        model.debouncer.submit("A")
        await clock.sleeps.waitForCalls(1)
        let scheduled = try #require(model.debouncer.scheduledTask)
        #expect(await source.calls.isEmpty)
        await clock.sleeps.complete(0, .success(()))
        await scheduled.value
        await source.waitForCalls(1)
        let initial = try #require(model.store.requestTask)
        await source.complete(0, .success(.init(items: [Row(2), Row(1)])))
        _ = await initial.result
        #expect(model.rows == [Row(1), Row(2)])
        model.debouncer.submitNow("A")
        await source.waitForCalls(2)
        let repeated = try #require(model.store.requestTask)
        await source.complete(1, .success(.init(items: [Row(3)])))
        _ = await repeated.result
        #expect(model.rows == [Row(3)])
        #expect(await source.calls.map(\.query) == ["A", "A"])
    }

    @Test func releasingWrapperCancelsItsPendingDebounce() async throws {
        let clock = ControlledClock()
        let source = ControlledCollectionSource()
        var model: SearchableListFixture? = .init(clock: clock, source: source)
        let weakModel = WeakReference(model)
        let weakStore = WeakReference(model?.store)
        model?.debouncer.submit("A")
        await clock.sleeps.waitForCalls(1)
        let scheduled = try #require(model?.debouncer.scheduledTask)
        model = nil
        #expect(weakModel.value == nil)
        #expect(weakStore.value == nil)
        await clock.sleeps.complete(0, .success(()))
        await scheduled.value
        #expect(await source.calls.isEmpty)
    }
}
