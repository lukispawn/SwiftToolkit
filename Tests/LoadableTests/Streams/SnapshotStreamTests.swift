import Testing
@testable import Loadable

@MainActor
@Suite("Snapshot subscriptions", .timeLimit(.minutes(1)))
struct SnapshotStreamTests {
    @Test func currentValueIsReplayedAndSubscribersAreIndependent() async {
        let sut = LoadableValueStore(source: ControlledValueSource<Int, Never>())
        sut.setValue(1)
        var first = sut.snapshots().makeAsyncIterator()
        var second = sut.snapshots().makeAsyncIterator()
        #expect(await first.next() == .loaded(1))
        #expect(await second.next() == .loaded(1))
        sut.setValue(2)
        #expect(await first.next() == .loaded(2))
        #expect(await second.next() == .loaded(2))
    }

    @Test func defaultBufferKeepsLatestSnapshot() async {
        let sut = LoadableValueStore(source: ControlledValueSource<Int, Never>())
        var iterator = sut.snapshots().makeAsyncIterator()
        sut.setValue(1)
        sut.setValue(2)
        #expect(await iterator.next() == .loaded(2))
    }

    @Test func unboundedSubscriptionPreservesLoadingTransitions() async throws {
        let source = ControlledValueSource<Int, Never>()
        let sut = LoadableValueStore(source: source)
        var iterator = sut.snapshots(bufferingPolicy: .unbounded).makeAsyncIterator()
        sut.start()
        await source.waitForCalls(1)
        let request = try #require(sut.requestTask)
        await source.complete(0, .success(1))
        _ = await request.result
        #expect(await iterator.next() == .idle)
        #expect(await iterator.next() == .loading)
        #expect(await iterator.next() == .loaded(1))
    }

    @Test func cancellingSubscriberDoesNotFinishOtherSubscriptions() async {
        let sut = LoadableValueStore(source: ControlledValueSource<Int, Never>())
        let first = sut.snapshots(bufferingPolicy: .bufferingNewest(0))
        var second = sut.snapshots().makeAsyncIterator()
        _ = await second.next()
        let waiter = Task {
            var iterator = first.makeAsyncIterator()
            return await iterator.next()
        }
        waiter.cancel()
        #expect(await waiter.value == nil)
        sut.setValue(9)
        #expect(await second.next() == .loaded(9))
    }

    @Test func releasingValueStoreFinishesStreamWithoutRetainingStore() async throws {
        var sut: LoadableValueStore? = LoadableValueStore(source: ControlledValueSource<Int, Never>())
        let weakStore = WeakReference(sut)
        var iterator = try #require(sut).snapshots(bufferingPolicy: .unbounded).makeAsyncIterator()
        sut = nil
        #expect(weakStore.value == nil)
        #expect(await iterator.next() == .idle)
        #expect(await iterator.next() == nil)
    }

    @Test func releasingCollectionStoreFinishesStream() async throws {
        var sut: CollectionStore? = CollectionStore(source: ControlledCollectionSource())
        let weakStore = WeakReference(sut)
        var iterator = try #require(sut).snapshots().makeAsyncIterator()
        sut = nil
        #expect(weakStore.value == nil)
        #expect(await iterator.next() == .idle)
        #expect(await iterator.next() == nil)
    }

    @Test func pagePublishesItemsCursorsAndPhaseTogether() async throws {
        let (sut, source) = try await seededCollection()
        var iterator = sut.snapshots(bufferingPolicy: .unbounded).makeAsyncIterator()
        _ = await iterator.next()
        sut.loadMore()
        await source.waitForCalls(2)
        let request = try #require(sut.requestTask)
        await source.complete(1, .success(.init(items: [Row(2)], nextCursor: 3, totalCount: 99)))
        _ = await request.result
        let loading = try #require(await iterator.next())
        #expect(loading.items == [Row(1)])
        #expect(loading.phase == .loadingPage(.next))
        let loaded = try #require(await iterator.next())
        #expect(loaded.items == [Row(1), Row(2)])
        #expect(loaded.phase == .idle)
        #expect(loaded.nextCursor == 3)
        #expect(loaded.totalCount == 99)
    }

    @Test func collectionSubscribersReceiveLocalChanges() async throws {
        let (sut, _) = try await seededCollection()
        var first = sut.snapshots().makeAsyncIterator()
        var second = sut.snapshots().makeAsyncIterator()
        _ = await first.next()
        _ = await second.next()
        sut.setItems([Row(9)])
        #expect(await first.next() == .loaded([Row(9)], query: "A"))
        #expect(await second.next() == .loaded([Row(9)], query: "A"))
    }
}
