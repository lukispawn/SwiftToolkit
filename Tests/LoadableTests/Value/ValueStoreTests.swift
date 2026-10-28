import Observation
import Testing
@testable import Loadable

@MainActor
@Suite("Value loading", .timeLimit(.minutes(1)))
struct ValueStoreTests {
    @Test func startsIdle() {
        let sut = LoadableValueStore(source: ControlledValueSource<Int, Never>())
        #expect(sut.snapshot == .idle)
        #expect(!sut.snapshot.hasValue)
    }

    @Test func loadReturnsValue() async throws {
        let source = ControlledValueSource<Int, String>()
        let sut = LoadableValueStore(source: source)
        let caller = Task { try await sut.load(query: "A") }
        await source.waitForCalls(1)
        #expect(sut.snapshot.phase == .loading)
        await source.complete(0, .success(42))
        #expect(try await caller.value == 42)
        #expect(sut.snapshot == .loaded(42, query: "A"))
    }

    @Test func failureIsStoredAndThrown() async {
        let source = ControlledValueSource<Int, Never>()
        let sut = LoadableValueStore(source: source)
        let caller = Task { try await sut.load() }
        await source.waitForCalls(1)
        await source.complete(0, .failure(.offline))
        await #expect(throws: TestFailure.offline) { try await caller.value }
        #expect(sut.lastError == .offline)
        #expect(!sut.snapshot.hasValue)
    }

    @Test func loadedNilIsDifferentFromMissing() async throws {
        let sut = LoadableValueStore(constant: Optional<Int>.none)
        #expect(sut.snapshot.hasValue)
        if case .some(.none) = sut.value {} else { Issue.record("Expected loaded nil") }
        #expect(try await sut.load() == nil)
    }

    @Test func doesNotRequireEquatableOrIdentifiable() async throws {
        struct Payload: Sendable { let number: Int }
        let sut = LoadableValueStore(operation: { Payload(number: 7) })
        #expect(try await sut.load().number == 7)
    }

    @Test func refreshKeepsValueEvenAfterFailure() async throws {
        let source = ControlledValueSource<Int, Never>()
        let sut = LoadableValueStore(source: source)
        sut.start()
        await source.waitForCalls(1)
        let first = try #require(sut.requestTask)
        await source.complete(0, .success(1))
        _ = await first.result
        let refresh = Task { await sut.refresh() }
        await source.waitForCalls(2)
        #expect(sut.value == 1)
        #expect(sut.snapshot.phase == .refreshing)
        await source.complete(1, .failure(.offline))
        await refresh.value
        #expect(sut.value == 1)
        #expect(sut.lastError == .offline)
        sut.retry()
        await source.waitForCalls(3)
        let retry = try #require(sut.requestTask)
        #expect(sut.value == 1)
        await source.complete(2, .success(2))
        _ = await retry.result
        #expect(sut.snapshot == .loaded(2))
    }

    @Test func reloadClearsPreviousValue() async throws {
        let source = ControlledValueSource<Int, Never>()
        let sut = LoadableValueStore(source: source)
        sut.start()
        await source.waitForCalls(1)
        let first = try #require(sut.requestTask)
        await source.complete(0, .success(1))
        _ = await first.result
        sut.reload()
        #expect(!sut.snapshot.hasValue)
        #expect(sut.snapshot.phase == .loading)
        await source.waitForCalls(2)
        let second = try #require(sut.requestTask)
        await source.complete(1, .success(2))
        _ = await second.result
        #expect(sut.value == 2)
    }

    @Test func retryKeepsFailedQuery() async throws {
        let source = ControlledValueSource<Int, String>()
        let sut = LoadableValueStore(source: source)
        sut.start(query: "A")
        await source.waitForCalls(1)
        let first = try #require(sut.requestTask)
        await source.complete(0, .failure(.offline))
        _ = await first.result
        sut.retry()
        sut.retry()
        await source.waitForCalls(2)
        let retry = try #require(sut.requestTask)
        await source.complete(1, .success(9))
        _ = await retry.result
        #expect(await source.queries == ["A", "A"])
        #expect(sut.value == 9)
    }

    @Test func repeatedStartAndRetryWithoutFailureAreNoOps() async throws {
        let source = ControlledValueSource<Int, String>()
        let sut = LoadableValueStore(source: source)
        sut.retry()
        sut.start(query: "A")
        let first = try #require(sut.requestTask)
        sut.start(query: "A")
        await source.waitForCalls(1)
        await source.complete(0, .success(1))
        _ = await first.result
        sut.start(query: "A")
        sut.startIfNeeded()
        sut.retry()
        #expect(sut.requestTask == nil)
        #expect(await source.queries == ["A"])
    }

    @Test func frozenSnapshotIgnoresCommands() async throws {
        let source = ControlledValueSource<Int, Never>()
        let sut = LoadableValueStore(source: source, constantSnapshot: .loaded(5))
        sut.start(force: true)
        sut.reload()
        sut.retry()
        await sut.refresh()
        #expect(try await sut.load() == 5)
        #expect(await source.queries.isEmpty)
        #expect(sut.snapshot == .loaded(5))
    }

    @Test func frozenLoadingHasNoValueToReturn() async {
        let sut = LoadableValueStore(source: ControlledValueSource<Int, Never>(), constantSnapshot: .loading)
        await #expect(throws: LoadableUsageError.self) { try await sut.load() }
    }

    @Test func observationTracksNestedStoreReads() async {
        let model = NestedValueModel()
        await confirmation("Nested snapshot read is tracked") { changed in
            withObservationTracking { _ = model.store.value } onChange: { changed() }
            model.store.setConstantState(.loaded(8))
        }
    }
}

@MainActor @Observable
private final class NestedValueModel {
    let store = LoadableValueStore(source: ControlledValueSource<Int, Never>())
}
