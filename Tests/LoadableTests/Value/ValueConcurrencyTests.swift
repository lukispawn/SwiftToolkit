import Testing
@testable import Loadable

@MainActor
@Suite("Value request ownership", .timeLimit(.minutes(1)))
struct ValueConcurrencyTests {
    @Test(arguments: [true, false])
    func staleResultCannotOverwriteNewerRequest(succeeds: Bool) async throws {
        let source = ControlledValueSource<Int, String>()
        let sut = LoadableValueStore(source: source)
        sut.start(query: "A")
        await source.waitForCalls(1)
        let old = try #require(sut.requestTask)
        sut.start(query: "B")
        await source.waitForCalls(2)
        let current = try #require(sut.requestTask)
        await source.complete(1, .success(2))
        _ = await current.result
        await source.complete(0, succeeds ? .success(1) : .failure(.offline))
        _ = await old.result
        #expect(sut.snapshot == .loaded(2, query: "B"))
    }

    @Test(arguments: [true, false])
    func staleCleanupCannotFinishNewRequest(succeeds: Bool) async throws {
        let source = ControlledValueSource<Int, String>()
        let sut = LoadableValueStore(source: source)
        sut.start(query: "A")
        await source.waitForCalls(1)
        let old = try #require(sut.requestTask)
        sut.start(query: "B")
        await source.waitForCalls(2)
        let current = try #require(sut.requestTask)
        await source.complete(0, succeeds ? .success(1) : .failure(.offline))
        _ = await old.result
        #expect(sut.snapshot.phase == .loading)
        #expect(sut.requestTask != nil)
        await source.complete(1, .success(2))
        _ = await current.result
    }

    @Test func cancelledCallerCancelsItsFetch() async {
        let source = ControlledValueSource<Int, Never>()
        let sut = LoadableValueStore(source: source)
        let caller = Task { try await sut.load() }
        await source.waitForCalls(1)
        caller.cancel()
        await source.complete(0, .success(1))
        await #expect(throws: CancellationError.self) { try await caller.value }
        #expect(sut.snapshot == .idle)
        #expect(await source.cancelledCalls == [0])
    }

    @Test func alreadyCancelledCallerDoesNotStartRequest() async {
        let source = ControlledValueSource<Int, Never>()
        let sut = LoadableValueStore(source: source)
        let caller = Task { try await sut.load() }
        caller.cancel()
        await #expect(throws: CancellationError.self) { try await caller.value }
        #expect(await source.queries.isEmpty)
        #expect(sut.snapshot == .idle)
    }

    @Test func cancellingOldCallerCannotCancelNewRequest() async throws {
        let source = ControlledValueSource<Int, String>()
        let sut = LoadableValueStore(source: source)
        let caller = Task { try await sut.load(query: "A") }
        await source.waitForCalls(1)
        sut.start(query: "B")
        await source.waitForCalls(2)
        let current = try #require(sut.requestTask)
        caller.cancel()
        await source.complete(0, .success(1))
        _ = await caller.result
        #expect(sut.snapshot.phase == .loading)
        await source.complete(1, .success(2))
        #expect(try await current.value == 2)
        #expect(sut.snapshot == .loaded(2, query: "B"))
    }

    @Test func refreshOutlivesCancelledWaiter() async {
        let source = ControlledValueSource<Int, Never>()
        let sut = LoadableValueStore(source: source)
        let waiter = Task { await sut.refresh() }
        await source.waitForCalls(1)
        waiter.cancel()
        await source.complete(0, .success(3))
        await waiter.value
        #expect(sut.value == 3)
        #expect(await source.cancelledCalls.isEmpty)
    }

    @Test func invalidatedBeforeStartDoesNotReachSource() async throws {
        let source = ControlledValueSource<Int, String>()
        let sut = LoadableValueStore(source: source)
        sut.start(query: "A")
        sut.start(query: "B")
        await source.waitForCalls(1)
        let current = try #require(sut.requestTask)
        await source.complete(0, .success(2))
        _ = await current.result
        #expect(await source.queries == ["B"])
    }

    @Test func storeDeallocatesDuringNoncooperativeFetch() async throws {
        let source = ControlledValueSource<Int, Never>()
        var sut: LoadableValueStore? = LoadableValueStore(source: source)
        weak var weakStore = sut
        sut?.start()
        await source.waitForCalls(1)
        let request = try #require(sut?.requestTask)
        sut = nil
        #expect(weakStore == nil)
        await source.complete(0, .success(1))
        await #expect(throws: CancellationError.self) { try await request.value }
        #expect(await source.cancelledCalls == [0])
    }

    @Test func constantStateInvalidatesPendingFetch() async throws {
        let source = ControlledValueSource<Int, Never>()
        let sut = LoadableValueStore(source: source)
        sut.start()
        await source.waitForCalls(1)
        let pending = try #require(sut.requestTask)
        sut.setConstantState(.loaded(8))
        await source.complete(0, .success(1))
        _ = await pending.result
        #expect(sut.snapshot == .loaded(8))
    }

    @Test func cancelAllowsStartingAgain() async throws {
        let source = ControlledValueSource<Int, Never>()
        let sut = LoadableValueStore(source: source)
        sut.start()
        await source.waitForCalls(1)
        let old = try #require(sut.requestTask)
        sut.cancel()
        #expect(sut.snapshot == .idle)
        sut.startIfNeeded()
        await source.waitForCalls(2)
        let current = try #require(sut.requestTask)
        await source.complete(0, .failure(.offline))
        _ = await old.result
        await source.complete(1, .success(3))
        _ = await current.result
        #expect(sut.value == 3)
    }
}
