import Testing
@testable import Loadable

typealias CollectionStore = LoadableCollectionStore<ControlledCollectionSource>

@MainActor
func seededCollection(
    next: Int? = 2, previous: Int? = nil,
    configuration: LoadableCollection.Configuration = .init()
) async throws -> (CollectionStore, ControlledCollectionSource) {
    let source = ControlledCollectionSource()
    let sut = CollectionStore(source: source, configuration: configuration)
    sut.start(query: "A")
    await source.waitForCalls(1)
    let request = try #require(sut.requestTask)
    await source.complete(0, .success(.init(items: [Row(1)], nextCursor: next,
                                           previousCursor: previous, totalCount: 100)))
    _ = await request.result
    return (sut, source)
}

@MainActor
@Suite("Collection behavior", .timeLimit(.minutes(1)))
struct CollectionStoreTests {
    @Test func startsIdle() {
        let sut = CollectionStore(source: ControlledCollectionSource())
        #expect(sut.snapshot == .idle)
        #expect(!sut.canLoadMore)
        #expect(!sut.snapshot.isEmpty)
    }

    @Test func loadReturnsFirstPageAndQuery() async throws {
        let source = ControlledCollectionSource()
        let sut = CollectionStore(source: source)
        let caller = Task { try await sut.load(query: "A") }
        await source.waitForCalls(1)
        await source.complete(0, .success(.init(items: [Row(1)])))
        #expect(try await caller.value == [Row(1)])
        #expect(sut.snapshot.query == "A")
        #expect(sut.snapshot.hasLoaded)
    }

    @Test func emptySuccessIsDistinctFromNotStarted() async throws {
        let sut = LoadableCollectionStore(items: [Row]())
        #expect(sut.snapshot.hasLoaded)
        #expect(sut.snapshot.isEmpty)
        #expect(try await sut.load() == [])
    }

    @Test func repeatedStartIsIgnoredButForceFetches() async throws {
        let (sut, source) = try await seededCollection()
        sut.start(query: "A")
        sut.startIfNeeded()
        sut.retry()
        #expect(sut.requestTask == nil)
        sut.start(query: "A", force: true)
        #expect(sut.items.isEmpty)
        await source.waitForCalls(2)
        let request = try #require(sut.requestTask)
        await source.complete(1, .success(.init(items: [Row(2)])))
        _ = await request.result
        #expect(await source.calls.count == 2)
    }

    @Test func newQueryClearsOldCursorsBeforeResponse() async throws {
        let (sut, source) = try await seededCollection(next: 42, previous: 10)
        sut.start(query: "B")
        #expect(sut.items.isEmpty)
        #expect(sut.snapshot.nextCursor == nil)
        #expect(sut.snapshot.previousCursor == nil)
        #expect(sut.snapshot.totalCount == nil)
        #expect(sut.snapshot.query == "B")
        await source.waitForCalls(2)
        let request = try #require(sut.requestTask)
        await source.complete(1, .failure(.offline))
        _ = await request.result
        sut.loadMore()
        #expect(!sut.canLoadMore)
        #expect(await source.calls.count == 2)
    }

    @Test(arguments: LoadableCollection.Direction.allCases)
    func pageUsesSessionQueryAndPreservesOppositeCursor(direction: LoadableCollection.Direction) async throws {
        let (sut, source) = try await seededCollection(next: 2, previous: 0)
        sut.loadPage(direction)
        await source.waitForCalls(2)
        let request = try #require(sut.requestTask)
        await source.complete(1, .success(.init(items: [Row(2)], nextCursor: 3, previousCursor: -1)))
        _ = await request.result
        #expect(await source.calls.last == .init(query: "A", cursor: direction == .next ? 2 : 0, direction: direction))
        #expect(sut.snapshot.nextCursor == (direction == .next ? 3 : 2))
        #expect(sut.snapshot.previousCursor == (direction == .next ? 0 : -1))
        #expect(sut.snapshot.totalCount == 100)
        #expect(sut.items == (direction == .next ? [Row(1), Row(2)] : [Row(2), Row(1)]))
    }

    @Test func loadMoreIsSerializedAgainstOtherCommands() async throws {
        let (sut, source) = try await seededCollection(next: 2, previous: 0)
        sut.loadMore()
        let request = try #require(sut.requestTask)
        sut.loadMore()
        sut.loadPage(.previous)
        sut.retry()
        sut.loadMoreIfNeeded(for: Row(1))
        await source.waitForCalls(2)
        await source.complete(1, .success(.init(items: [Row(2)])))
        _ = await request.result
        #expect(await source.calls.count == 2)
    }

    @Test func pageLoadingIsBlockedDuringRefresh() async throws {
        let (sut, source) = try await seededCollection()
        let refresh = Task { await sut.refresh() }
        await source.waitForCalls(2)
        #expect(sut.items == [Row(1)])
        #expect(sut.snapshot.phase == .refreshing)
        sut.loadMore()
        await source.complete(1, .success(.init(items: [Row(9)])))
        await refresh.value
        #expect(await source.calls.count == 2)
        #expect(sut.items == [Row(9)])
    }

    @Test(arguments: LoadableCollection.Direction.allCases)
    func retryRepeatsFailedPageAndPreservesItems(direction: LoadableCollection.Direction) async throws {
        let (sut, source) = try await seededCollection(next: 2, previous: 0)
        sut.loadPage(direction)
        await source.waitForCalls(2)
        let failed = try #require(sut.requestTask)
        await source.complete(1, .failure(.offline))
        _ = await failed.result
        #expect(sut.items == [Row(1)])
        #expect(sut.snapshot.phase == .failed(.offline, operation: .page(direction)))
        sut.retry()
        sut.retry()
        await source.waitForCalls(3)
        let retry = try #require(sut.requestTask)
        await source.complete(2, .success(.init(items: [Row(2)])))
        _ = await retry.result
        let calls = await source.calls
        #expect(calls[1] == calls[2])
        #expect(sut.items.count == 2)
        #expect(sut.lastError == nil)
    }

    @Test func retryRefreshReplacesRatherThanAppends() async throws {
        let (sut, source) = try await seededCollection()
        let refresh = Task { await sut.refresh() }
        await source.waitForCalls(2)
        await source.complete(1, .failure(.offline))
        await refresh.value
        #expect(sut.items == [Row(1)])
        #expect(sut.snapshot.phase == .failed(.offline, operation: .reload))
        sut.retry()
        await source.waitForCalls(3)
        let retry = try #require(sut.requestTask)
        await source.complete(2, .success(.init(items: [Row(9)], nextCursor: 10)))
        _ = await retry.result
        #expect(sut.items == [Row(9)])
        #expect(sut.snapshot.nextCursor == 10)
        #expect(await source.calls.map(\.cursor) == [nil, nil, nil])
    }

    @Test func missingCursorAndUnknownRowAreNoOps() async throws {
        let (sut, source) = try await seededCollection(next: nil)
        sut.loadMore()
        sut.loadPage(.previous)
        sut.loadMoreIfNeeded(for: Row(999))
        #expect(sut.requestTask == nil)
        #expect(await source.calls.count == 1)
    }

    @Test func cancelRequestKeepsSessionButCancelEndsIt() async throws {
        let (sut, source) = try await seededCollection()
        sut.loadMore()
        await source.waitForCalls(2)
        let old = try #require(sut.requestTask)
        sut.cancelRequest()
        #expect(sut.canLoadMore)
        #expect(sut.items == [Row(1)])
        sut.loadMore()
        await source.waitForCalls(3)
        let current = try #require(sut.requestTask)
        await source.complete(1, .success(.init(items: [Row(77)])))
        _ = await old.result
        await source.complete(2, .success(.init(items: [Row(2)], nextCursor: 3)))
        _ = await current.result
        sut.cancel()
        #expect(!sut.canLoadMore)
        sut.loadMore()
        #expect(sut.requestTask == nil)
        #expect(sut.items == [Row(1), Row(2)])
    }

    @Test func constantStateIsFrozen() async {
        let source = ControlledCollectionSource()
        let sut = CollectionStore(source: source, constantSnapshot: .loaded([Row(1)], nextCursor: 2))
        sut.start(force: true)
        sut.reload()
        sut.retry()
        sut.loadMore()
        await sut.refresh()
        #expect(!sut.canLoadMore)
        #expect(await source.calls.isEmpty)
        #expect(sut.items == [Row(1)])
    }

    @Test func operationSourceNeedsNoPagination() async throws {
        let sut = LoadableCollectionStore(operation: { [Row(1)] })
        #expect(try await sut.load() == [Row(1)])
        #expect(!sut.canLoadMore)
    }
}
