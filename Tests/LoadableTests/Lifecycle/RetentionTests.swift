import Testing
@testable import Loadable

@MainActor
@Suite("Retention and query boundaries", .timeLimit(.minutes(1)))
struct RetentionTests {
    @Test func sourceCancellationIsNotAUserFacingValueError() async {
        let sut = LoadableValueStore(operation: { () async throws -> Int in throw CancellationError() })
        await #expect(throws: CancellationError.self) { try await sut.load() }
        #expect(sut.lastError == nil)
        #expect(!sut.snapshot.phase.isLoading)
    }

    @Test func sourceCancellationIsNotAUserFacingCollectionError() async {
        let sut = LoadableCollectionStore(operation: { () async throws -> [Row] in throw CancellationError() })
        await #expect(throws: CancellationError.self) { try await sut.load() }
        #expect(sut.lastError == nil)
        #expect(!sut.snapshot.phase.isLoading)
    }

    @Test func reloadClearsCollectionAndMetadata() async throws {
        let (sut, source) = try await seededCollection(previous: 0)
        sut.reload()
        #expect(sut.items.isEmpty)
        #expect(sut.snapshot.phase == .loading)
        #expect(sut.snapshot.nextCursor == nil)
        #expect(sut.snapshot.previousCursor == nil)
        #expect(sut.snapshot.totalCount == nil)
        await source.waitForCalls(2)
        let request = try #require(sut.requestTask)
        await source.complete(1, .success(.init(items: [Row(9)])))
        _ = await request.result
    }

    @Test func serverCanUpdateTotalCountOnLaterPage() async throws {
        let (sut, source) = try await seededCollection()
        sut.loadMore()
        await source.waitForCalls(2)
        let request = try #require(sut.requestTask)
        await source.complete(1, .success(.init(items: [Row(2)], totalCount: 99)))
        _ = await request.result
        #expect(sut.snapshot.totalCount == 99)
        #expect(sut.items.count == 2)
    }

    @Test func retainingValueCannotMixDifferentQueries() async throws {
        let source = ControlledValueSource<Int, String>()
        let sut = LoadableValueStore(source: source)
        sut.start(query: "A")
        await source.waitForCalls(1)
        let first = try #require(sut.requestTask)
        await source.complete(0, .success(1))
        _ = await first.result
        let caller = Task { try await sut.load(query: "B", retainingValue: true) }
        await source.waitForCalls(2)
        #expect(!sut.snapshot.hasValue)
        await source.complete(1, .success(2))
        #expect(try await caller.value == 2)
    }

    @Test func retainingCollectionCannotMixDifferentQueries() async throws {
        let (sut, source) = try await seededCollection()
        let caller = Task { try await sut.load(query: "B", retainingItems: true) }
        await source.waitForCalls(2)
        #expect(sut.items.isEmpty)
        #expect(sut.snapshot.nextCursor == nil)
        await source.complete(1, .success(.init(items: [Row(2)])))
        #expect(try await caller.value == [Row(2)])
    }

    @Test func cancellingRefreshPreservesValueWithoutFailure() async throws {
        let source = ControlledValueSource<Int, Never>()
        let sut = LoadableValueStore(source: source)
        sut.start()
        await source.waitForCalls(1)
        let first = try #require(sut.requestTask)
        await source.complete(0, .success(1))
        _ = await first.result
        let caller = Task { try await sut.load(retainingValue: true) }
        await source.waitForCalls(2)
        #expect(sut.snapshot.phase == .refreshing)
        caller.cancel()
        await source.complete(1, .failure(.offline))
        await #expect(throws: CancellationError.self) { try await caller.value }
        #expect(sut.snapshot == .loaded(1))
    }

    @Test func cancellingRefreshPreservesCollectionWithoutFailure() async throws {
        let (sut, source) = try await seededCollection()
        let before = sut.snapshot
        let caller = Task { try await sut.load(query: "A", retainingItems: true) }
        await source.waitForCalls(2)
        #expect(sut.snapshot.phase == .refreshing)
        caller.cancel()
        await source.complete(1, .failure(.offline))
        await #expect(throws: CancellationError.self) { try await caller.value }
        #expect(sut.snapshot == before)
    }

    @Test func refreshAfterCancelKeepsLastQuery() async throws {
        let (sut, source) = try await seededCollection()
        sut.cancel()
        let waiter = Task { await sut.refresh() }
        await source.waitForCalls(2)
        await source.complete(1, .success(.init(items: [Row(2)])))
        await waiter.value
        #expect(await source.calls.last?.query == "A")
        #expect(await source.calls.last?.cursor == nil)
    }

    @Test func previousEmptyPagesContinueInPreviousDirection() async throws {
        let (sut, source) = try await seededCollection(previous: 0)
        sut.loadPage(.previous)
        let request = try #require(sut.requestTask)
        await source.waitForCalls(2)
        await source.complete(1, .success(.init(items: [], previousCursor: -1)))
        await source.waitForCalls(3)
        await source.complete(2, .success(.init(items: [Row(0)])))
        _ = await request.result
        #expect(sut.items == [Row(0), Row(1)])
        #expect(await source.calls.map(\.direction) == [.next, .previous, .previous])
        #expect(sut.snapshot.nextCursor == 2)
    }

    @Test func refreshReplacesAllPreviouslyLoadedPages() async throws {
        let (sut, source) = try await seededCollection()
        sut.loadMore()
        await source.waitForCalls(2)
        let next = try #require(sut.requestTask)
        await source.complete(1, .success(.init(items: [Row(2)])))
        _ = await next.result
        let refresh = Task { await sut.refresh() }
        await source.waitForCalls(3)
        #expect(sut.items == [Row(1), Row(2)])
        await source.complete(2, .success(.init(items: [Row(9)], totalCount: 1)))
        await refresh.value
        #expect(sut.items == [Row(9)])
        #expect(sut.snapshot.totalCount == 1)
    }
}
