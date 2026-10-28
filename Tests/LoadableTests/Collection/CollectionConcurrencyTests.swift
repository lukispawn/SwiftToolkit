import Observation
import Testing
@testable import Loadable

@MainActor
@Suite("Collection request ownership", .timeLimit(.minutes(1)))
struct CollectionConcurrencyTests {
    @Test(arguments: [true, false], [true, false])
    func staleCompletionCannotChangeCurrentRequest(succeeds: Bool, oldFinishesFirst: Bool) async throws {
        let source = ControlledCollectionSource()
        let sut = CollectionStore(source: source)
        sut.start(query: "A")
        await source.waitForCalls(1)
        let old = try #require(sut.requestTask)
        sut.start(query: "B")
        await source.waitForCalls(2)
        let current = try #require(sut.requestTask)
        if oldFinishesFirst {
            await source.complete(0, succeeds ? .success(.init(items: [Row(1)])) : .failure(.offline))
            _ = await old.result
            #expect(sut.snapshot.phase == .loading)
            #expect(sut.requestTask != nil)
        }
        await source.complete(1, .success(.init(items: [Row(2)])))
        _ = await current.result
        if !oldFinishesFirst {
            await source.complete(0, succeeds ? .success(.init(items: [Row(1)])) : .failure(.offline))
            _ = await old.result
        }
        #expect(sut.snapshot == .loaded([Row(2)], query: "B"))
    }

    @Test func refreshSupersedesPendingPage() async throws {
        let (sut, source) = try await seededCollection()
        sut.loadMore()
        await source.waitForCalls(2)
        let old = try #require(sut.requestTask)
        let refresh = Task { await sut.refresh() }
        await source.waitForCalls(3)
        await source.complete(2, .success(.init(items: [Row(9)])))
        await refresh.value
        await source.complete(1, .success(.init(items: [Row(2)])))
        _ = await old.result
        #expect(sut.items == [Row(9)])
    }

    @Test func cancellationFromOldCallerCannotCancelNewQuery() async throws {
        let source = ControlledCollectionSource()
        let sut = CollectionStore(source: source)
        let old = Task { try await sut.load(query: "A") }
        await source.waitForCalls(1)
        sut.start(query: "B")
        await source.waitForCalls(2)
        let current = try #require(sut.requestTask)
        old.cancel()
        await source.complete(0, .failure(.offline))
        _ = await old.result
        await source.complete(1, .success(.init(items: [Row(2)])))
        #expect(try await current.value == [Row(2)])
        #expect(sut.lastError == nil)
    }

    @Test func callerCancellationDoesNotPublishErrorOrData() async {
        let source = ControlledCollectionSource()
        let sut = CollectionStore(source: source)
        let caller = Task { try await sut.load() }
        await source.waitForCalls(1)
        caller.cancel()
        await source.complete(0, .success(.init(items: [Row(1)])))
        await #expect(throws: CancellationError.self) { try await caller.value }
        #expect(sut.snapshot == .idle)
        #expect(await source.cancelledCalls == [0])
    }

    @Test func preCancelledCallerDoesNotOpenSession() async {
        let source = ControlledCollectionSource()
        let sut = CollectionStore(source: source)
        let caller = Task { try await sut.load() }
        caller.cancel()
        await #expect(throws: CancellationError.self) { try await caller.value }
        #expect(await source.calls.isEmpty)
    }

    @Test func refreshSurvivesWaiterCancellation() async {
        let source = ControlledCollectionSource()
        let sut = CollectionStore(source: source)
        let waiter = Task { await sut.refresh() }
        await source.waitForCalls(1)
        waiter.cancel()
        await source.complete(0, .success(.init(items: [Row(1)])))
        await waiter.value
        #expect(sut.items == [Row(1)])
        #expect(await source.cancelledCalls.isEmpty)
    }

    @Test func storeDeallocatesDuringNoncooperativeFetch() async throws {
        let source = ControlledCollectionSource()
        var sut: CollectionStore? = CollectionStore(source: source)
        weak var weakStore = sut
        sut?.start()
        await source.waitForCalls(1)
        let task = try #require(sut?.requestTask)
        sut = nil
        #expect(weakStore == nil)
        await source.complete(0, .success(.init(items: [])))
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await source.cancelledCalls == [0])
    }

    @Test func cancelledBeforeExecutionDoesNotReachSource() async throws {
        let source = ControlledCollectionSource()
        let sut = CollectionStore(source: source)
        sut.start(query: "A")
        sut.start(query: "B")
        await source.waitForCalls(1)
        let request = try #require(sut.requestTask)
        await source.complete(0, .success(.init(items: [Row(2)])))
        _ = await request.result
        #expect(await source.calls.map(\.query) == ["B"])
    }

    @Test func freezingInvalidatesPendingPage() async throws {
        let (sut, source) = try await seededCollection()
        sut.loadMore()
        await source.waitForCalls(2)
        let request = try #require(sut.requestTask)
        sut.setConstantState(.loaded([Row(9)]))
        await source.complete(1, .success(.init(items: [Row(2)])))
        _ = await request.result
        #expect(sut.items == [Row(9)])
    }

    @Test func observationTracksCommandAvailabilityAfterCancel() async throws {
        let (sut, _) = try await seededCollection()
        await confirmation("Session cancellation invalidates observed availability") { changed in
            withObservationTracking { _ = sut.canLoadMore } onChange: { changed() }
            sut.cancel()
        }
        #expect(!sut.canLoadMore)
    }
}
