import Testing
@testable import Loadable

@MainActor
@Suite("Pagination boundaries", .timeLimit(.minutes(1)))
struct CollectionPaginationTests {
    @Test(arguments: LoadableCollection.Direction.allCases)
    func overlappingIDsUpdateInPlace(direction: LoadableCollection.Direction) async throws {
        let (sut, source) = try await seededCollection(next: 2, previous: 0)
        sut.loadPage(direction)
        await source.waitForCalls(2)
        let request = try #require(sut.requestTask)
        await source.complete(1, .success(.init(items: [Row(1, version: 1), Row(2), Row(2, version: 2)])))
        _ = await request.result
        #expect(sut.items == (direction == .next
            ? [Row(1, version: 1), Row(2, version: 2)]
            : [Row(2, version: 2), Row(1, version: 1)]))
    }

    @Test func initialPageAlsoDeduplicatesIDs() async throws {
        let sut = LoadableCollectionStore(operation: { [Row(1), Row(1, version: 1)] })
        #expect(try await sut.load() == [Row(1, version: 1)])
    }

    @Test func customMergeIsUsedForPages() async throws {
        let source = ControlledCollectionSource()
        let sut = CollectionStore(source: source, merge: { _, incoming, _ in incoming })
        sut.start()
        await source.waitForCalls(1)
        let first = try #require(sut.requestTask)
        await source.complete(0, .success(.init(items: [Row(1)], nextCursor: 2)))
        _ = await first.result
        sut.loadMore()
        await source.waitForCalls(2)
        let next = try #require(sut.requestTask)
        await source.complete(1, .success(.init(items: [Row(2)])))
        _ = await next.result
        #expect(sut.items == [Row(2)])
    }

    @Test func emptyIntermediatePagePreservesPrefixAndContinues() async throws {
        let (sut, source) = try await seededCollection()
        sut.loadMore()
        let request = try #require(sut.requestTask)
        await source.waitForCalls(2)
        await source.complete(1, .success(.init(items: [], nextCursor: 3)))
        await source.waitForCalls(3)
        #expect(sut.items == [Row(1)])
        #expect(sut.snapshot.phase == .loadingPage(.next))
        #expect(!sut.canLoadMore)
        await source.complete(2, .success(.init(items: [Row(2)])))
        _ = await request.result
        #expect(sut.items == [Row(1), Row(2)])
        #expect(!sut.canLoadMore)
    }

    @Test func retryAfterEmptyPageFailureUsesContinuationCursor() async throws {
        let (sut, source) = try await seededCollection()
        sut.loadMore()
        let request = try #require(sut.requestTask)
        await source.waitForCalls(2)
        await source.complete(1, .success(.init(items: [], nextCursor: 3)))
        await source.waitForCalls(3)
        await source.complete(2, .failure(.offline))
        _ = await request.result
        sut.retry()
        await source.waitForCalls(4)
        let retry = try #require(sut.requestTask)
        await source.complete(3, .success(.init(items: [Row(2)])))
        _ = await retry.result
        #expect(await source.calls.map(\.cursor) == [nil, 2, 3, 3])
        #expect(sut.items == [Row(1), Row(2)])
    }

    @Test(arguments: [0, 1, 3])
    func emptyPageLimitBoundsAutomaticFetching(limit: Int) async throws {
        let source = ControlledCollectionSource()
        let sut = CollectionStore(source: source, configuration: .init(emptyPageFetchLimit: limit))
        sut.start()
        let request = try #require(sut.requestTask)
        for index in 0...limit {
            await source.waitForCalls(index + 1)
            await source.complete(index, .success(.init(items: [], nextCursor: index + 1)))
        }
        _ = await request.result
        #expect(await source.calls.count == limit + 1)
        #expect(sut.canLoadMore)
        #expect(!sut.snapshot.isEmpty)
    }

    @Test(arguments: [true, false])
    func repeatedAndCyclicCursorsStopAutomaticFetching(cycle: Bool) async throws {
        let source = ControlledCollectionSource()
        let sut = CollectionStore(source: source)
        sut.start()
        let request = try #require(sut.requestTask)
        let cursors = cycle ? [1, 2, 1] : [1, 1]
        for (index, cursor) in cursors.enumerated() {
            await source.waitForCalls(index + 1)
            await source.complete(index, .success(.init(items: [], nextCursor: cursor)))
        }
        _ = await request.result
        #expect(await source.calls.count == cursors.count)
        #expect(sut.canLoadMore)
    }

    @Test func terminalEmptyPagePreservesListAndTotalCount() async throws {
        let (sut, source) = try await seededCollection()
        sut.loadMore()
        await source.waitForCalls(2)
        let request = try #require(sut.requestTask)
        await source.complete(1, .success(.init(items: [])))
        _ = await request.result
        #expect(sut.items == [Row(1)])
        #expect(sut.snapshot.totalCount == 100)
        #expect(!sut.canLoadMore)
        #expect(!sut.snapshot.isEmpty)
    }

    @Test(arguments: [0, 1, 3])
    func lastRowTriggersPrefetchEvenForSmallPages(threshold: Int) async throws {
        let (sut, source) = try await seededCollection(configuration: .init(prefetchThreshold: threshold))
        sut.loadMoreIfNeeded(for: Row(1))
        await source.waitForCalls(2)
        let request = try #require(sut.requestTask)
        await source.complete(1, .success(.init(items: [Row(2)], nextCursor: 3)))
        _ = await request.result
        sut.loadMoreIfNeeded(for: Row(2))
        await source.waitForCalls(3)
        let next = try #require(sut.requestTask)
        await source.complete(2, .success(.init(items: [Row(3)])))
        _ = await next.result
        #expect(sut.items == [Row(1), Row(2), Row(3)])
    }

    @Test func beforeThresholdIsNoOp() async throws {
        let source = ControlledCollectionSource()
        let sut = CollectionStore(source: source, configuration: .init(prefetchThreshold: 1))
        sut.start()
        await source.waitForCalls(1)
        let request = try #require(sut.requestTask)
        await source.complete(0, .success(.init(items: (1...10).map { Row($0) }, nextCursor: 2)))
        _ = await request.result
        sut.loadMoreIfNeeded(for: Row(1))
        #expect(sut.requestTask == nil)
    }

    @Test func configurationClampsNegativeValues() {
        let configuration = LoadableCollection.Configuration(prefetchThreshold: -1, emptyPageFetchLimit: -1)
        #expect(configuration.prefetchThreshold == 0)
        #expect(configuration.emptyPageFetchLimit == 0)
    }

    @Test(arguments: [0, 1])
    func totalCountFactoriesRespectFirstPage(firstPage: Int) {
        let first = LoadableCollection.Page(items: [Row(1)], page: firstPage, firstPage: firstPage, pageSize: 10, totalCount: 11)
        let last = LoadableCollection.Page(items: [Row(2)], page: firstPage + 1, firstPage: firstPage, pageSize: 10, totalCount: 11)
        #expect(first.nextCursor == firstPage + 1)
        #expect(last.nextCursor == nil)
        #expect(last.totalCount == 11)
    }

    @Test(arguments: [0, -1])
    func invalidPageSizeDoesNotContinue(pageSize: Int) {
        let page = LoadableCollection.Page(items: [Row(1)], page: 0, pageSize: pageSize)
        #expect(page.nextCursor == nil)
    }
}
