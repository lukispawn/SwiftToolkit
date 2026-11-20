import Foundation
import Testing
@testable import Loadable

private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    var count: Int { lock.withLock { value } }
    func hit() { lock.withLock { value += 1 } }
}

/// Newest version first, then by ID.
private let byVersionThenID: @Sendable ([Row]) -> [Row] = { rows in
    rows.sorted { ($0.version, $1.id) > ($1.version, $0.id) }
}
private let byID: @Sendable ([Row]) -> [Row] = { $0.sorted { $0.id < $1.id } }
private let clampTo3: @Sendable ([Row]) -> [Row] = { Array($0.prefix(3)) }

@MainActor
@Suite("Collection normalization hook", .timeLimit(.minutes(1)))
struct CollectionNormalizationTests {
    private typealias Store = LoadableCollectionStore<ControlledCollectionSource>

    private func loaded(
        normalize: Store.Normalize?, first: [Row], next: Int? = 2, previous: Int? = nil, totalCount: Int? = 100
    ) async throws -> (Store, ControlledCollectionSource) {
        let source = ControlledCollectionSource()
        let sut = Store(source: source, normalize: normalize)
        sut.start(query: "A")
        await source.waitForCalls(1)
        let request = try #require(sut.requestTask)
        await source.complete(0, .success(.init(items: first, nextCursor: next,
                                               previousCursor: previous, totalCount: totalCount)))
        _ = await request.result
        return (sut, source)
    }

    @Test func defaultKeepsSourceOrder() async throws {
        let (sut, _) = try await loaded(normalize: nil, first: [Row(3), Row(1), Row(2)])
        #expect(sut.items == [Row(3), Row(1), Row(2)])
        sut.setItems([Row(2), Row(1)])
        #expect(sut.items == [Row(2), Row(1)])
    }

    @Test func firstPageIsNormalizedAndKeepsCursorsAndTotal() async throws {
        let (sut, _) = try await loaded(normalize: byID, first: [Row(3), Row(1), Row(2)],
                                        previous: 0, totalCount: 9)
        #expect(sut.items == [Row(1), Row(2), Row(3)])
        #expect(sut.snapshot.nextCursor == 2)
        #expect(sut.snapshot.previousCursor == 0)
        #expect(sut.snapshot.totalCount == 9)
    }

    @Test func mergedNextPageIsNormalizedAcrossThePageBoundary() async throws {
        let (sut, source) = try await loaded(normalize: byID, first: [Row(3), Row(4)], next: 2)
        sut.loadMore()
        await source.waitForCalls(2)
        let request = try #require(sut.requestTask)
        await source.complete(1, .success(.init(items: [Row(5), Row(1)], nextCursor: nil, totalCount: 100)))
        _ = await request.result
        #expect(sut.items == [Row(1), Row(3), Row(4), Row(5)])
        #expect(await source.calls.last?.cursor == 2)
        #expect(!sut.canLoadMore)
    }

    @Test func clampKeepsServerCursorsAndTotalCount() async throws {
        let (sut, source) = try await loaded(normalize: clampTo3, first: [Row(1), Row(2), Row(3), Row(4)],
                                             next: 2, totalCount: 40)
        // Clamp changes the row count but never the server's view of the list.
        #expect(sut.items.count == 3)
        #expect(sut.snapshot.totalCount == 40)
        #expect(sut.snapshot.nextCursor == 2)
        #expect(sut.canLoadMore)
        sut.loadMore()
        await source.waitForCalls(2)
        let request = try #require(sut.requestTask)
        await source.complete(1, .success(.init(items: [Row(5), Row(6)], nextCursor: 3, totalCount: 41)))
        _ = await request.result
        #expect(sut.items == [Row(1), Row(2), Row(3)])
        #expect(sut.snapshot.totalCount == 41)
        #expect(sut.snapshot.nextCursor == 3)
        #expect(await source.calls.map(\.cursor) == [nil, 2])
    }

    @Test func setItemsAndAppendItemsAreNormalizedAndInvalidateCursors() async throws {
        let (sut, _) = try await loaded(normalize: byID, first: [Row(1)])
        sut.setItems([Row(5), Row(2), Row(4)], totalCount: 3)
        #expect(sut.items == [Row(2), Row(4), Row(5)])
        #expect(sut.snapshot.totalCount == 3)
        #expect(sut.snapshot.nextCursor == nil)
        sut.appendItems([Row(3), Row(1), Row(4, version: 1)])
        #expect(sut.items == [Row(1), Row(2), Row(3), Row(4, version: 1), Row(5)])
        #expect(sut.snapshot.totalCount == nil)
    }

    @Test func removeItemKeepsTheRemainderNormalized() async throws {
        let (sut, _) = try await loaded(normalize: clampTo3, first: [Row(1), Row(2), Row(3)])
        sut.setItems([Row(1), Row(2), Row(3)])
        let removed = sut.removeItem(withID: 2)
        #expect(removed == Row(2))
        #expect(sut.items == [Row(1), Row(3)])
        #expect(sut.removeItem(withID: 99) == nil)
    }

    @Test func updateItemMovesTheRowWhenTheSortKeyChanges() async throws {
        let (sut, _) = try await loaded(normalize: byVersionThenID, first: [Row(1), Row(2), Row(3)],
                                        previous: 0, totalCount: 7)
        #expect(sut.items == [Row(1), Row(2), Row(3)])
        #expect(sut.updateItem(Row(3, version: 5)))
        #expect(sut.items == [Row(3, version: 5), Row(1), Row(2)])
        // Cursors and server total are untouched by a local update.
        #expect(sut.snapshot.nextCursor == 2)
        #expect(sut.snapshot.previousCursor == 0)
        #expect(sut.snapshot.totalCount == 7)
        #expect(sut.snapshot.phase == .idle)
    }

    @Test func updateItemWithoutHookKeepsPosition() async throws {
        let (sut, _) = try await loaded(normalize: nil, first: [Row(1), Row(2), Row(3)])
        #expect(sut.updateItem(Row(3, version: 5)))
        #expect(sut.items == [Row(1), Row(2), Row(3, version: 5)])
    }

    @Test func ineffectiveMutationsDoNotRunTheHook() async throws {
        let counter = CallCounter()
        let (sut, _) = try await loaded(normalize: { counter.hit(); return $0 }, first: [Row(1)])
        let afterLoad = counter.count
        #expect(afterLoad == 1)
        #expect(!sut.updateItem(Row(99)))
        #expect(sut.removeItem(withID: 99) == nil)
        sut.appendItems([])
        #expect(counter.count == afterLoad)
        let constant = Store(source: ControlledCollectionSource(), normalize: { counter.hit(); return $0 })
        constant.setConstantState(.loaded([Row(2), Row(1)]))
        constant.setItems([Row(3)])
        #expect(constant.items == [Row(2), Row(1)])
        #expect(counter.count == afterLoad)
    }

    @Test func reloadRetainingItemsNormalizesTheReplacement() async throws {
        let (sut, source) = try await loaded(normalize: byID, first: [Row(2), Row(1)])
        sut.refreshInBackground()
        await source.waitForCalls(2)
        let request = try #require(sut.requestTask)
        await source.complete(1, .success(.init(items: [Row(9), Row(7), Row(8)], nextCursor: 4, totalCount: 3)))
        _ = await request.result
        #expect(sut.items == [Row(7), Row(8), Row(9)])
        #expect(sut.snapshot.totalCount == 3)
    }
}
