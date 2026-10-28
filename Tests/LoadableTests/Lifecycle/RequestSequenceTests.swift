import Testing
@testable import Loadable

private let completionOrders = [
    [0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]
]

@MainActor
@Suite("Request sequence invariants", .timeLimit(.minutes(1)))
struct RequestSequenceTests {
    @Test(arguments: completionOrders, [true, false])
    func valueKeepsLatestQueryForEveryCompletionOrder(order: [Int], oldRequestsSucceed: Bool) async throws {
        let source = ControlledValueSource<Int, String>()
        let sut = LoadableValueStore(source: source)
        var requests: [Task<Int, any Error>] = []
        for index in 0..<3 {
            sut.start(query: String(index))
            await source.waitForCalls(index + 1)
            requests.append(try #require(sut.requestTask))
        }
        for index in order {
            await source.complete(index, index == 2 || oldRequestsSucceed ? .success(index) : .failure(.offline))
            _ = await requests[index].result
            #expect(sut.snapshot.query == "2")
            #expect(sut.lastError == nil)
            if sut.snapshot.hasValue { #expect(sut.value == 2) }
        }
        #expect(sut.snapshot == .loaded(2, query: "2"))
    }

    @Test(arguments: completionOrders, [true, false])
    func collectionKeepsLatestQueryForEveryCompletionOrder(order: [Int], oldRequestsSucceed: Bool) async throws {
        let source = ControlledCollectionSource()
        let sut = CollectionStore(source: source)
        var requests: [Task<[Row], any Error>] = []
        for index in 0..<3 {
            sut.start(query: String(index))
            await source.waitForCalls(index + 1)
            requests.append(try #require(sut.requestTask))
        }
        for index in order {
            await source.complete(index, index == 2 || oldRequestsSucceed
                                  ? .success(.init(items: [Row(index)], nextCursor: index + 1)) : .failure(.offline))
            _ = await requests[index].result
            #expect(sut.snapshot.query == "2")
            #expect(sut.lastError == nil)
            #expect(sut.items.isEmpty || sut.items == [Row(2)])
        }
        #expect(sut.snapshot == .loaded([Row(2)], nextCursor: 3, query: "2"))
    }

    @Test func cooperativeValueCancellationResetsStateWithoutError() async throws {
        let probe = CancellationProbe()
        let sut = LoadableValueStore(source: CooperativeValueSource(probe: probe))
        sut.start()
        await probe.waitUntilStarted()
        let request = try #require(sut.requestTask)
        sut.cancel()
        await #expect(throws: CancellationError.self) { try await request.value }
        #expect(!sut.snapshot.phase.isLoading)
        #expect(sut.lastError == nil)
    }

    @Test func cooperativeCollectionCancellationResetsStateWithoutError() async throws {
        let probe = CancellationProbe()
        let sut = LoadableCollectionStore(source: CooperativePageSource(probe: probe))
        sut.start()
        await probe.waitUntilStarted()
        let request = try #require(sut.requestTask)
        sut.cancel()
        await #expect(throws: CancellationError.self) { try await request.value }
        #expect(!sut.snapshot.phase.isLoading)
        #expect(sut.lastError == nil)
    }
}
