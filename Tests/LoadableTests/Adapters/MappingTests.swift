import Testing
@testable import Loadable

@MainActor
@Suite("Asynchronous source transformations", .timeLimit(.minutes(1)))
struct MappingTests {
    @Test func valueMappingPreservesQueryAndCanChangeType() async throws {
        let base = ControlledValueSource<Int, String>()
        let sut = LoadableValueStore(source: base.mapValue { String($0) })
        let caller = Task { try await sut.load(query: "A") }
        await base.waitForCalls(1)
        await base.complete(0, .success(42))
        #expect(try await caller.value == "42")
        #expect(sut.snapshot.query == "A")
        #expect(await base.queries == ["A"])
    }

    @Test func sourceFailureDoesNotRunTransformation() async {
        let base = ControlledValueSource<Int, Never>()
        let transform = ControlledValueSource<String, Int>()
        let sut = LoadableValueStore(source: base.mapValue { try await transform.fetch(query: $0) })
        let caller = Task { try await sut.load() }
        await base.waitForCalls(1)
        await base.complete(0, .failure(.offline))
        await #expect(throws: TestFailure.offline) { try await caller.value }
        #expect(await transform.queries.isEmpty)
        #expect(sut.lastError as? TestFailure == .offline)
    }

    @Test func transformFailureIsStoredAndThrown() async {
        let sut = LoadableValueStore(source: LoadableValue.ConstantSource(1).mapValue { _ -> Int in
            throw TestFailure.rejected
        })
        await #expect(throws: TestFailure.rejected) { try await sut.load() }
        #expect(sut.lastError as? TestFailure == .rejected)
    }

    @Test func cancelledBaseResultDoesNotStartTransformation() async {
        let base = ControlledValueSource<Int, Never>()
        let transform = ControlledValueSource<String, Int>()
        let mapped = base.mapValue { try await transform.fetch(query: $0) }
        let caller = Task { try await mapped.fetch(query: nil) }
        await base.waitForCalls(1)
        caller.cancel()
        await base.complete(0, .success(1))
        await #expect(throws: CancellationError.self) { try await caller.value }
        #expect(await transform.queries.isEmpty)
    }

    @Test(arguments: [true, false])
    func staleValueTransformationCannotPublish(succeeds: Bool) async throws {
        let base = ControlledValueSource<Int, String>()
        let transform = ControlledValueSource<String, Int>()
        let sut = LoadableValueStore(source: base.mapValue { try await transform.fetch(query: $0) })
        sut.start(query: "A")
        await base.waitForCalls(1)
        let old = try #require(sut.requestTask)
        await base.complete(0, .success(1))
        await transform.waitForCalls(1)
        sut.start(query: "B")
        await base.waitForCalls(2)
        let current = try #require(sut.requestTask)
        await base.complete(1, .success(2))
        await transform.waitForCalls(2)
        await transform.complete(1, .success("new"))
        _ = await current.result
        await transform.complete(0, succeeds ? .success("old") : .failure(.rejected))
        _ = await old.result
        #expect(sut.value == "new")
        #expect(sut.snapshot.query == "B")
        #expect(sut.lastError == nil)
    }

    @Test func mappingKeepsPageMetadataAndPassesCursorAndDirection() async throws {
        let base = ControlledCollectionSource()
        let sut = LoadableCollectionStore(source: base.mapItems { rows in
            rows.map { Row($0.id, version: $0.version + 10) }
        })
        sut.start(query: "A")
        await base.waitForCalls(1)
        let first = try #require(sut.requestTask)
        await base.complete(0, .success(.init(items: [Row(1)], nextCursor: 2, previousCursor: 0, totalCount: 100)))
        _ = await first.result
        #expect(sut.items == [Row(1, version: 10)])
        #expect(sut.snapshot.totalCount == 100)
        #expect(sut.snapshot.nextCursor == 2)
        sut.loadPage(.previous)
        await base.waitForCalls(2)
        let previous = try #require(sut.requestTask)
        await base.complete(1, .success(.init(items: [Row(0)], previousCursor: -1)))
        _ = await previous.result
        #expect(await base.calls.last == .init(query: "A", cursor: 0, direction: .previous))
        #expect(sut.items == [Row(0, version: 10), Row(1, version: 10)])
    }

    @Test func filteredEmptyPageContinuesWithoutLosingServerCount() async throws {
        let base = ControlledCollectionSource()
        let sut = LoadableCollectionStore(source: base.mapItems { $0.filter { $0.version > 0 } })
        sut.start()
        let request = try #require(sut.requestTask)
        await base.waitForCalls(1)
        await base.complete(0, .success(.init(items: [Row(1)], nextCursor: 2, totalCount: 100)))
        await base.waitForCalls(2)
        await base.complete(1, .success(.init(items: [Row(2, version: 1)])))
        _ = await request.result
        #expect(sut.items == [Row(2, version: 1)])
        #expect(sut.snapshot.totalCount == 100)
    }

    @Test(arguments: [true, false])
    func stalePageTransformationCannotPublish(succeeds: Bool) async throws {
        let base = ControlledCollectionSource()
        let transform = ControlledValueSource<[Row], Int>()
        let sut = LoadableCollectionStore(source: base.mapItems { rows in
            try await transform.fetch(query: rows.first?.id)
        })
        sut.start(query: "A")
        await base.waitForCalls(1)
        let old = try #require(sut.requestTask)
        await base.complete(0, .success(.init(items: [Row(1)])))
        await transform.waitForCalls(1)
        sut.start(query: "B")
        await base.waitForCalls(2)
        let current = try #require(sut.requestTask)
        await base.complete(1, .success(.init(items: [Row(2)])))
        await transform.waitForCalls(2)
        await transform.complete(1, .success([Row(2)]))
        _ = await current.result
        await transform.complete(0, succeeds ? .success([Row(1)]) : .failure(.rejected))
        _ = await old.result
        #expect(sut.items == [Row(2)])
        #expect(sut.snapshot.query == "B")
        #expect(sut.lastError == nil)
    }
}
