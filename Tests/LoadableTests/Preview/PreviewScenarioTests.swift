#if DEBUG
import Testing
@testable import Loadable

@MainActor
@Suite("Interactive preview scenarios", .timeLimit(.minutes(1)))
struct PreviewScenarioTests {
    @Test func firstPageFailureCanRecoverOnRetry() async throws {
        let source = LoadableCollectionBasicDemoView.DataSource(behavior: .failsOnFirstPage, delay: .zero)
        await #expect(throws: DemoFailure.noConnection) {
            try await source.fetchPage(query: nil, cursor: nil, direction: .next)
        }
        let recovered = try await source.fetchPage(query: nil, cursor: nil, direction: .next)
        #expect(recovered.items.count == 15)
        #expect(recovered.nextCursor == 1)
    }

    @Test func nextPageFailureRecoversWithoutRefetchingFirstPage() async throws {
        let source = LoadableCollectionBasicDemoView.DataSource(behavior: .failsOnNextPage, delay: .zero)
        let first = try await source.fetchPage(query: nil, cursor: nil, direction: .next)
        await #expect(throws: DemoFailure.timeout) {
            try await source.fetchPage(query: nil, cursor: first.nextCursor, direction: .next)
        }
        let recovered = try await source.fetchPage(query: nil, cursor: first.nextCursor, direction: .next)
        #expect(Set(first.items.map(\.id)).isDisjoint(with: recovered.items.map(\.id)))
        #expect(recovered.nextCursor == 2)
    }

    @Test func emptyIntermediatePageHasContinuation() async throws {
        let source = LoadableCollectionBasicDemoView.DataSource(behavior: .emptyIntermediate, delay: .zero)
        let empty = try await source.fetchPage(query: nil, cursor: 1, direction: .next)
        #expect(empty.items.isEmpty)
        #expect(empty.nextCursor == 2)
        let next = try await source.fetchPage(query: nil, cursor: empty.nextCursor, direction: .next)
        #expect(!next.items.isEmpty)
    }

    @Test func bidirectionalDemoStartsInMiddleAndExposesBothCursors() async throws {
        let source = LoadableCollectionBasicDemoView.DataSource(behavior: .bidirectional, delay: .zero)
        let middle = try await source.fetchPage(query: nil, cursor: nil, direction: .next)
        #expect(middle.previousCursor == 1)
        #expect(middle.nextCursor == 3)
        let previous = try await source.fetchPage(query: nil, cursor: middle.previousCursor, direction: .previous)
        #expect(previous.previousCursor == 0)
        #expect(Set(middle.items.map(\.id)).isDisjoint(with: previous.items.map(\.id)))
    }

    @Test(arguments: [0, -1, 16])
    func singlePageDemoHasNoCursorAndClampsCount(count: Int) async throws {
        let source = LoadableCollectionSinglePageDemoView.DataSource(itemCount: count, delay: .zero)
        let page = try await source.fetchPage(query: nil, cursor: nil, direction: .next)
        #expect(page.items.count == max(0, count))
        #expect(page.nextCursor == nil)
    }

    @Test func searchMatchesAccentedNamesWithoutDiacriticsOrCase() async throws {
        let source = LoadableCollectionSearchDemoView.DataSource(delay: .zero)
        let page = try await source.fetchPage(query: "  GARCIA  ", cursor: nil, direction: .next)
        #expect(!page.items.isEmpty)
        #expect(page.items.allSatisfy { $0.title.contains("García") })
        let empty = try await source.fetchPage(query: "xyz", cursor: nil, direction: .next)
        #expect(empty.items.isEmpty)
        #expect(empty.totalCount == 0)
    }

    @Test func searchPaginatesTheFilteredResults() async throws {
        let source = LoadableCollectionSearchDemoView.DataSource(pageSize: 5, delay: .zero)
        let first = try await source.fetchPage(query: "Smith", cursor: nil, direction: .next)
        let cursor = try #require(first.nextCursor)
        let second = try await source.fetchPage(query: "Smith", cursor: cursor, direction: .next)
        #expect(first.items.count == 5)
        #expect(Set(first.items.map(\.id)).isDisjoint(with: second.items.map(\.id)))
        #expect(second.items.allSatisfy { $0.title.contains("Smith") })
        #expect(first.totalCount == second.totalCount)
    }

    @Test func searchGateTrimsInputAndCancelsPendingQuery() {
        let model = LoadableCollectionSearchDemoView.ViewModel(
            minimumLength: 2, debounce: .seconds(60), showsAllWhenEmpty: false,
            responseDelay: .zero
        )
        #expect(model.requirement == .tooShort(minimumLength: 2))
        model.text = "  Alice  "
        #expect(model.requirement == .satisfied(query: "Alice"))
        #expect(model.debouncer.pendingQuery == "Alice")
        model.text = " A "
        #expect(model.requirement == .tooShort(minimumLength: 2))
        #expect(!model.debouncer.isWaiting)
        #expect(model.store.requestTask == nil)
        model.stop()
    }

    @Test(arguments: [true, false])
    func searchEmptyQueryRespectsConfiguration(showsAll: Bool) {
        let model = LoadableCollectionSearchDemoView.ViewModel(
            minimumLength: 2, debounce: .seconds(60), showsAllWhenEmpty: showsAll,
            responseDelay: .zero
        )
        model.text = "  "
        #expect(model.requirement == (showsAll ? .satisfied(query: "") : .tooShort(minimumLength: 2)))
        #expect(model.debouncer.isWaiting == showsAll)
        model.stop()
    }

    @Test func immediateSearchAfterGateClosesCanRepeatPreviousQuery() async throws {
        let model = LoadableCollectionSearchDemoView.ViewModel(
            minimumLength: 2, debounce: .seconds(60), showsAllWhenEmpty: false,
            responseDelay: .zero
        )
        model.text = "Alice"
        model.submitNow()
        let first = try #require(model.store.requestTask)
        _ = await first.result
        model.text = "A"
        model.text = "Alice"
        model.submitNow()
        let repeated = try #require(model.store.requestTask)
        _ = await repeated.result
        #expect(!model.store.items.isEmpty)
        #expect(model.store.snapshot.query == "Alice")
        model.stop()
    }

    @Test func valueDemoFirstFailureRecoversAndRefreshIncrementsRevision() async throws {
        let source = LoadableValueDemoView.DataSource(behavior: .failsFirst, delay: .zero)
        await #expect(throws: DemoFailure.noConnection) { try await source.fetch(query: nil) }
        #expect(try await source.fetch(query: nil).revision == 1)
        #expect(try await source.fetch(query: nil).revision == 2)
    }

    @Test func valueDemoRefreshFailureIsOneShot() async throws {
        let source = LoadableValueDemoView.DataSource(behavior: .failsRefresh, delay: .zero)
        #expect(try await source.fetch(query: nil).revision == 1)
        await #expect(throws: DemoFailure.timeout) { try await source.fetch(query: nil) }
        #expect(try await source.fetch(query: nil).revision == 2)
    }

    @Test func cancelledDemoFetchPropagatesCancellation() async {
        let source = LoadableCollectionSearchDemoView.DataSource(delay: .zero)
        let request = Task { try await source.fetchPage(query: nil, cursor: nil, direction: .next) }
        request.cancel()
        await #expect(throws: CancellationError.self) { try await request.value }
    }
}
#endif
