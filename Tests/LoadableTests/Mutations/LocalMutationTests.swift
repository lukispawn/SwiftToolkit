import Observation
import Testing
@testable import Loadable

@MainActor
@Suite("Authoritative local updates", .timeLimit(.minutes(1)))
struct LocalMutationTests {
    @Test(arguments: [true, false])
    func localValueInvalidatesSuspendedFetch(succeeds: Bool) async throws {
        let source = ControlledValueSource<Int, String>()
        let sut = LoadableValueStore(source: source)
        sut.start(query: "A")
        await source.waitForCalls(1)
        let old = try #require(sut.requestTask)
        sut.setValue(9)
        await source.complete(0, succeeds ? .success(1) : .failure(.offline))
        _ = await old.result
        #expect(sut.snapshot == .loaded(9, query: "A"))
    }

    @Test func localValueDiscardsRetryContext() async throws {
        let source = ControlledValueSource<Int, Never>()
        let sut = LoadableValueStore(source: source)
        sut.start()
        await source.waitForCalls(1)
        let old = try #require(sut.requestTask)
        await source.complete(0, .failure(.offline))
        _ = await old.result
        sut.setValue(9)
        sut.retry()
        #expect(sut.requestTask == nil)
        #expect(sut.snapshot == .loaded(9))
    }

    @Test func backgroundValueRefreshRetainsDataAndQuery() async throws {
        let source = ControlledValueSource<Int, String>()
        let sut = LoadableValueStore(source: source)
        sut.start(query: "A")
        await source.waitForCalls(1)
        let initial = try #require(sut.requestTask)
        await source.complete(0, .success(1))
        _ = await initial.result
        sut.refreshInBackground()
        #expect(sut.snapshot.phase == .refreshing)
        #expect(sut.value == 1)
        await source.waitForCalls(2)
        let refresh = try #require(sut.requestTask)
        await source.complete(1, .success(2))
        _ = await refresh.result
        #expect(sut.snapshot == .loaded(2, query: "A"))
        #expect(await source.queries == ["A", "A"])
    }

    @Test func backgroundCollectionRefreshRetainsDataAndQuery() async throws {
        let (sut, source) = try await seededCollection()
        sut.refreshInBackground()
        #expect(sut.items == [Row(1)])
        #expect(sut.snapshot.phase == .refreshing)
        await source.waitForCalls(2)
        let refresh = try #require(sut.requestTask)
        await source.complete(1, .failure(.offline))
        _ = await refresh.result
        #expect(sut.items == [Row(1)])
        #expect(await source.calls.last?.query == "A")
    }

    @Test(arguments: [true, false])
    func replacingItemsInvalidatesFetchAndAllPagination(succeeds: Bool) async throws {
        let (sut, source) = try await seededCollection(previous: 0)
        sut.loadMore()
        await source.waitForCalls(2)
        let old = try #require(sut.requestTask)
        sut.setItems([Row(9), Row(9, version: 1)], totalCount: 10)
        await source.complete(1, succeeds ? .success(.init(items: [Row(2)])) : .failure(.offline))
        _ = await old.result
        #expect(sut.snapshot == .loaded([Row(9, version: 1)], totalCount: 10, query: "A"))
        #expect(!sut.canLoadMore)
        #expect(!sut.canLoad(.previous))
    }

    @Test func updatingRowInvalidatesOlderPageButKeepsCursors() async throws {
        let (sut, source) = try await seededCollection(previous: 0)
        sut.loadMore()
        await source.waitForCalls(2)
        let old = try #require(sut.requestTask)
        #expect(sut.updateItem(Row(1, version: 1)))
        await source.complete(1, .success(.init(items: [Row(1), Row(2)])))
        _ = await old.result
        #expect(sut.items == [Row(1, version: 1)])
        #expect(sut.snapshot.nextCursor == 2)
        #expect(sut.snapshot.previousCursor == 0)
        #expect(sut.snapshot.totalCount == 100)
        #expect(sut.canLoadMore)
    }

    @Test func unknownRowDoesNotCancelPage() async throws {
        let (sut, source) = try await seededCollection()
        sut.loadMore()
        await source.waitForCalls(2)
        let request = try #require(sut.requestTask)
        #expect(!sut.updateItem(Row(999)))
        #expect(sut.removeItem(withID: 999) == nil)
        sut.appendItems([])
        await source.complete(1, .success(.init(items: [Row(2)])))
        #expect(try await request.value == [Row(1), Row(2)])
        #expect(await source.cancelledCalls.isEmpty)
    }

    @Test func removingRowClearsStaleOffsetsAndUnknownTotal() async throws {
        let (sut, _) = try await seededCollection(previous: 0)
        #expect(sut.removeItem(withID: 1) == Row(1))
        #expect(sut.items.isEmpty)
        #expect(sut.snapshot.hasLoaded)
        #expect(sut.snapshot.isEmpty)
        #expect(sut.snapshot.nextCursor == nil)
        #expect(sut.snapshot.previousCursor == nil)
        #expect(sut.snapshot.totalCount == nil)
    }

    @Test func appendedItemsMergeByIDAndInvalidatePagination() async throws {
        let (sut, _) = try await seededCollection()
        sut.appendItems([Row(1, version: 1), Row(2), Row(2, version: 2)])
        #expect(sut.items == [Row(1, version: 1), Row(2, version: 2)])
        #expect(sut.snapshot.nextCursor == nil)
        #expect(sut.snapshot.totalCount == nil)
        #expect(!sut.canLoadMore)
    }

    @Test func localMembershipChangeRequiresNewSessionBeforePagination() async throws {
        let (sut, source) = try await seededCollection()
        sut.setItems([Row(9)])
        sut.loadMore()
        #expect(sut.requestTask == nil)
        sut.refreshInBackground()
        await source.waitForCalls(2)
        let refresh = try #require(sut.requestTask)
        await source.complete(1, .success(.init(items: [Row(2)], nextCursor: 3)))
        _ = await refresh.result
        #expect(sut.canLoadMore)
        #expect(sut.items == [Row(2)])
    }

    @Test func constantsIgnoreMutationsAndBackgroundRefresh() async {
        let value = LoadableValueStore(constant: 1)
        value.setValue(2)
        value.refreshInBackground()
        #expect(value.value == 1)
        let list = LoadableCollectionStore(items: [Row(1)])
        list.setItems([Row(2)])
        list.appendItems([Row(2)])
        #expect(!list.updateItem(Row(1, version: 1)))
        #expect(list.removeItem(withID: 1) == nil)
        list.refreshInBackground()
        #expect(list.items == [Row(1)])
    }

    @Test func localUpdatesAreObservable() async throws {
        let (sut, _) = try await seededCollection()
        await confirmation("Local row change invalidates the read") { changed in
            withObservationTracking { _ = sut.items } onChange: { changed() }
            sut.updateItem(Row(1, version: 1))
        }
    }
}
