import Observation
import Testing
@testable import Loadable

@MainActor
private func finishEdgePage(_ store: CollectionStore, _ source: ControlledCollectionSource,
                            call: Int, page: CollectionStore.Page) async throws {
    let request = try #require(store.requestTask)
    await source.waitForCalls(call + 1)
    await source.complete(call, .success(page))
    _ = try await request.value
}

@MainActor
private func edgePage(_ direction: LoadableCollection.Direction, id: Int?, cursor: Int?) -> CollectionStore.Page {
    .init(items: id.map { [Row($0)] } ?? [], nextCursor: direction == .next ? cursor : nil,
          previousCursor: direction == .previous ? cursor : nil)
}

@MainActor
@Suite("Automatic pagination edges", .timeLimit(.minutes(1)))
struct AutomaticPaginationTests {
    typealias Gate = LoadableUI.AutomaticPagination<ControlledCollectionSource>

    @Test(arguments: LoadableCollection.Direction.allCases)
    func visibleEdgesLoadTheirDirectionAndDeduplicateCallbacks(direction: LoadableCollection.Direction) async throws {
        let (store, source) = try await seededCollection(next: 2, previous: 0)
        let context = LoadableUI.CollectionContext(store: store).pagination(direction)
        var gate = Gate()
        var callbacks = 0
        #expect(gate.loadIfNeeded(context, isVisible: false) == false)
        #expect(store.requestTask == nil)
        #expect(gate.loadIfNeeded(context, isVisible: true, willLoad: { callbacks += 1 }) == true)
        #expect(gate.loadIfNeeded(context, isVisible: true, willLoad: { callbacks += 1 }) == false)
        #expect(callbacks == 1)
        try await finishEdgePage(store, source, call: 1, page: edgePage(direction, id: direction == .next ? 2 : 0, cursor: nil))
        #expect(await source.calls.last?.direction == direction)
        #expect(await source.calls.last?.cursor == (direction == .next ? 2 : 0))
        #expect(gate.loadIfNeeded(context, isVisible: true) == false)
    }

    @Test(arguments: LoadableCollection.Direction.allCases)
    func movingBoundaryAllowsAnotherVisiblePage(direction: LoadableCollection.Direction) async throws {
        let (store, source) = try await seededCollection(next: 2, previous: 0)
        let context = LoadableUI.CollectionContext(store: store).pagination(direction)
        var gate = Gate()
        #expect(gate.loadIfNeeded(context, isVisible: true) == true)
        try await finishEdgePage(store, source, call: 1, page: edgePage(direction, id: direction == .next ? 2 : 0,
                                                                     cursor: direction == .next ? 3 : -1))
        #expect(!gate.needsManualContinuation(context))
        #expect(gate.loadIfNeeded(context, isVisible: false) == false)
        #expect(gate.loadIfNeeded(context, isVisible: true) == true)
        try await finishEdgePage(store, source, call: 2, page: edgePage(direction, id: direction == .next ? 3 : -1, cursor: nil))
        #expect(await source.calls.count == 3)
    }

    @Test(arguments: LoadableCollection.Direction.allCases, [false, true])
    func emptyOrOverlappingPagesRequireManualContinuation(direction: LoadableCollection.Direction, overlaps: Bool) async throws {
        let (store, source) = try await seededCollection(next: 2, previous: 0,
                                                        configuration: .init(emptyPageFetchLimit: 0))
        let context = LoadableUI.CollectionContext(store: store).pagination(direction)
        var gate = Gate()
        #expect(gate.loadIfNeeded(context, isVisible: true) == true)
        try await finishEdgePage(store, source, call: 1,
                                 page: edgePage(direction, id: overlaps ? 1 : nil, cursor: direction == .next ? 3 : -1))
        #expect(gate.needsManualContinuation(context))
        #expect(gate.loadIfNeeded(context, isVisible: true) == false)
        #expect(store.requestTask == nil)

        gate.recordRequest(context)
        context.load()
        try await finishEdgePage(store, source, call: 2,
                                 page: edgePage(direction, id: direction == .next ? 2 : 0, cursor: direction == .next ? 4 : -2))
        #expect(!gate.needsManualContinuation(context))
        #expect(gate.loadIfNeeded(context, isVisible: true) == true)
        try await finishEdgePage(store, source, call: 3,
                                 page: edgePage(direction, id: direction == .next ? 3 : -1, cursor: nil))
    }

    @Test(arguments: LoadableCollection.Direction.allCases, [false, true])
    func repeatedAndCyclicCursorsStopEvenWhenRowsProgress(direction: LoadableCollection.Direction, cycle: Bool) async throws {
        let (store, source) = try await seededCollection(next: 2, previous: 0)
        let context = LoadableUI.CollectionContext(store: store).pagination(direction)
        let original = direction == .next ? 2 : 0
        var gate = Gate()
        #expect(gate.loadIfNeeded(context, isVisible: true) == true)
        try await finishEdgePage(store, source, call: 1,
                                 page: edgePage(direction, id: direction == .next ? 2 : 0,
                                                cursor: cycle ? (direction == .next ? 3 : -1) : original))
        if cycle {
            #expect(gate.loadIfNeeded(context, isVisible: true) == true)
            try await finishEdgePage(store, source, call: 2,
                                     page: edgePage(direction, id: direction == .next ? 3 : -1, cursor: original))
        }
        #expect(gate.needsManualContinuation(context))
        #expect(gate.loadIfNeeded(context, isVisible: true) == false)
        #expect(store.requestTask == nil)
    }

    @Test(arguments: LoadableCollection.Direction.allCases)
    func oppositeEdgeProgressCannotUnblockAnEmptyPage(direction: LoadableCollection.Direction) async throws {
        let (store, source) = try await seededCollection(next: 2, previous: 0,
                                                        configuration: .init(emptyPageFetchLimit: 0))
        let context = LoadableUI.CollectionContext(store: store).pagination(direction)
        var gate = Gate()
        #expect(gate.loadIfNeeded(context, isVisible: true) == true)
        try await finishEdgePage(store, source, call: 1,
                                 page: edgePage(direction, id: nil, cursor: direction == .next ? 3 : -1))
        let opposite: LoadableCollection.Direction = direction == .next ? .previous : .next
        store.loadPage(opposite)
        try await finishEdgePage(store, source, call: 2,
                                 page: edgePage(opposite, id: opposite == .next ? 2 : 0, cursor: opposite == .next ? 3 : -1))
        #expect(gate.needsManualContinuation(context))
        #expect(gate.loadIfNeeded(context, isVisible: true) == false)
    }

    @Test(arguments: [LoadableUI.Configuration.Pagination.manual, .disabled])
    func manualAndDisabledPoliciesNeverAutoLoad(policy: LoadableUI.Configuration.Pagination) async throws {
        let (store, source) = try await seededCollection()
        let context = LoadableUI.CollectionContext(store: store, configuration: .init(pagination: policy)).pagination
        var gate = Gate()
        #expect(gate.loadIfNeeded(context, isVisible: true) == false)
        #expect(store.requestTask == nil)
        #expect(await source.calls.count == 1)
    }

    @Test(arguments: LoadableCollection.Direction.allCases)
    func failuresRequireExplicitRetryBeforeAutoLoadingCanResume(direction: LoadableCollection.Direction) async throws {
        let (store, source) = try await seededCollection(next: 2, previous: 0)
        let context = LoadableUI.CollectionContext(store: store).pagination(direction)
        var gate = Gate()
        #expect(gate.loadIfNeeded(context, isVisible: true) == true)
        let failed = try #require(store.requestTask)
        await source.waitForCalls(2)
        await source.complete(1, .failure(.offline))
        _ = await failed.result
        #expect(gate.loadIfNeeded(context, isVisible: true) == false)
        #expect(context.state == .failed)
        gate.recordRequest(context)
        context.retry()
        try await finishEdgePage(store, source, call: 2,
                                 page: edgePage(direction, id: direction == .next ? 2 : 0, cursor: direction == .next ? 3 : -1))
        #expect(gate.loadIfNeeded(context, isVisible: true) == true)
        try await finishEdgePage(store, source, call: 3, page: edgePage(direction, id: direction == .next ? 3 : -1, cursor: nil))
        let calls = await source.calls
        #expect(calls[1] == calls[2])
    }

    @Test(arguments: [false, true])
    func reloadAndRefreshResetReusedQueryAndCursorHistory(retaining: Bool) async throws {
        let (store, source) = try await seededCollection(configuration: .init(emptyPageFetchLimit: 0))
        let context = LoadableUI.CollectionContext(store: store).pagination
        var gate = Gate()
        #expect(gate.loadIfNeeded(context, isVisible: true) == true)
        try await finishEdgePage(store, source, call: 1, page: .init(items: [], nextCursor: 3))
        #expect(gate.needsManualContinuation(context))
        let oldSession = context.sessionID
        if retaining { store.refreshInBackground() } else { store.reload() }
        try await finishEdgePage(store, source, call: 2, page: .init(items: [Row(1)], nextCursor: 2))
        #expect(context.sessionID != oldSession)
        #expect(store.snapshot.query == "A")
        #expect(!gate.needsManualContinuation(context))
        #expect(gate.loadIfNeeded(context, isVisible: true) == true)
        try await finishEdgePage(store, source, call: 3, page: .init(items: [Row(2)]))
    }

    @Test func cancelledRequestsNeedManualContinuationAndIgnoreLateResults() async throws {
        let (store, source) = try await seededCollection()
        let context = LoadableUI.CollectionContext(store: store).pagination
        var gate = Gate()
        #expect(gate.loadIfNeeded(context, isVisible: true) == true)
        let cancelled = try #require(store.requestTask)
        await source.waitForCalls(2)
        store.cancelRequest()
        #expect(gate.loadIfNeeded(context, isVisible: true) == false)
        gate.recordRequest(context)
        context.load()
        let replacement = try #require(store.requestTask)
        await source.waitForCalls(3)
        await source.complete(1, .success(.init(items: [Row(99)])))
        _ = await cancelled.result
        #expect(context.state == .loading)
        await source.complete(2, .success(.init(items: [Row(2)], nextCursor: 3)))
        _ = try await replacement.value
        #expect(store.items == [Row(1), Row(2)])
        #expect(!gate.needsManualContinuation(context))
    }

    @Test(arguments: [false, true])
    func endedAndFrozenSessionsNeverAutoLoad(frozen: Bool) async throws {
        let (store, source) = try await seededCollection()
        if frozen { store.setConstantState(store.snapshot) } else { store.cancel() }
        let context = LoadableUI.CollectionContext(store: store).pagination
        var gate = Gate()
        #expect(gate.loadIfNeeded(context, isVisible: true) == false)
        #expect(store.requestTask == nil)
        #expect(await source.calls.count == 1)
    }

    @Test func headerAndFooterKeepIndependentHistoryButShareOneRequest() async throws {
        let (store, source) = try await seededCollection(next: 2, previous: 0)
        let context = LoadableUI.CollectionContext(store: store)
        var header = Gate()
        var footer = Gate()
        #expect(header.loadIfNeeded(context.pagination(.previous), isVisible: true) == true)
        #expect(footer.loadIfNeeded(context.pagination, isVisible: true) == false)
        try await finishEdgePage(store, source, call: 1, page: .init(items: [Row(0)], previousCursor: -1))
        #expect(footer.loadIfNeeded(context.pagination, isVisible: true) == true)
        try await finishEdgePage(store, source, call: 2, page: .init(items: [Row(2)], nextCursor: 3))
        #expect(!header.needsManualContinuation(context.pagination(.previous)))
        #expect(!footer.needsManualContinuation(context.pagination))
        #expect(store.items == [Row(0), Row(1), Row(2)])
    }

    @Test func emptyPageFollowupLimitCannotBecomeAnUnboundedVisibilityLoop() async throws {
        let (store, source) = try await seededCollection(configuration: .init(emptyPageFetchLimit: 2))
        let context = LoadableUI.CollectionContext(store: store).pagination
        var gate = Gate()
        #expect(gate.loadIfNeeded(context, isVisible: true) == true)
        let request = try #require(store.requestTask)
        for call in 1...3 {
            await source.waitForCalls(call + 1)
            await source.complete(call, .success(.init(items: [], nextCursor: call + 2)))
        }
        _ = try await request.value
        #expect(gate.needsManualContinuation(context))
        #expect(gate.loadIfNeeded(context, isVisible: true) == false)
        #expect(await source.calls.count == 4)
    }

    @Test func sessionResetIsObservableEvenWhenSnapshotValuesAreReused() async throws {
        let (store, source) = try await seededCollection()
        let context = LoadableUI.CollectionContext(store: store).pagination
        await confirmation("A new session invalidates the edge view") { changed in
            withObservationTracking { _ = context.sessionID } onChange: { changed() }
            store.refreshInBackground()
        }
        try await finishEdgePage(store, source, call: 1, page: .init(items: [Row(1)], nextCursor: 2))
    }
}
