#if DEBUG
import Testing
@testable import Loadable

@Suite("Chat mock keyset source", .timeLimit(.minutes(1)))
struct ChatSourceTests {
    @Test func middleWindowExposesBothSequenceBoundaries() async throws {
        let source = LoadableChat.Source(seedCount: 90, pageSize: 10, delay: .zero)
        let page = try await source.fetchPage(query: .around(45), cursor: nil, direction: .next)
        #expect(page.items.map(\.sequence) == Array(40...49))
        #expect(page.previousCursor == .before(40))
        #expect(page.nextCursor == .after(49))
        #expect(page.totalCount == 90)
    }

    @Test func walkingBackwardsVisitsEveryMessageOnce() async throws {
        let source = LoadableChat.Source(seedCount: 31, pageSize: 7, delay: .zero)
        var page = try await source.fetchPage(query: .latest, cursor: nil, direction: .next)
        var items = page.items
        for _ in 0..<10 {
            guard let cursor = page.previousCursor else { break }
            page = try await source.fetchPage(query: .latest, cursor: cursor, direction: .previous)
            items = page.items + items
        }
        #expect(page.previousCursor == nil)
        #expect(items.map(\.sequence) == Array(1...31))
        #expect(Set(items.map(\.id)).count == 31)
    }

    @Test func cursorBoundariesRemainStableWhenNewMessagesArrive() async throws {
        let source = LoadableChat.Source(seedCount: 60, pageSize: 10, delay: .zero)
        let middle = try await source.fetchPage(query: .around(35), cursor: nil, direction: .next)
        let earlierCursor = try #require(middle.previousCursor)
        let laterCursor = try #require(middle.nextCursor)
        _ = try await source.receiveGenerated()
        _ = try await source.receiveGenerated()
        let earlier = try await source.fetchPage(query: .around(35), cursor: earlierCursor, direction: .previous)
        let later = try await source.fetchPage(query: .around(35), cursor: laterCursor, direction: .next)
        #expect(earlier.items.last?.sequence == middle.items.first!.sequence - 1)
        #expect(later.items.first?.sequence == middle.items.last!.sequence + 1)
        #expect(Set(earlier.items.map(\.id)).isDisjoint(with: middle.items.map(\.id)))
        #expect(Set(later.items.map(\.id)).isDisjoint(with: middle.items.map(\.id)))
        #expect(later.totalCount == 62)
    }

    @Test(arguments: [LoadableChat.Failure.initial, .older, .newer])
    func pageFailureRetriesTheSameCursorOnce(failure: LoadableChat.Failure) async throws {
        let source = LoadableChat.Source(seedCount: 90, failures: [failure], delay: .zero)
        let cursor: LoadableChat.Cursor?
        let direction: LoadableCollection.Direction
        switch failure {
        case .older: cursor = .before(40); direction = .previous
        case .newer: cursor = .after(51); direction = .next
        default: cursor = nil; direction = .next
        }
        await #expect(throws: failure) {
            try await source.fetchPage(query: .around(45), cursor: cursor, direction: direction)
        }
        let recovered = try await source.fetchPage(query: .around(45), cursor: cursor, direction: direction)
        #expect(!recovered.items.isEmpty)
        let calls = await source.calls
        #expect(calls.count == 2)
        #expect(calls[0] == calls[1])
    }

    @Test func sendFailureAndRepeatedClientIDNeverDuplicateDelivery() async throws {
        let source = LoadableChat.Source(seedCount: 2, failures: [.send], delay: .zero)
        await #expect(throws: LoadableChat.Failure.send) { try await source.send(id: "client-1", text: "Hello") }
        let sent = try await source.send(id: "client-1", text: "Hello")
        let repeated = try await source.send(id: "client-1", text: "Hello")
        #expect(sent == repeated)
        #expect(sent.sequence == 3)
        #expect(sent.sender == .me)
        #expect(await source.messageCount == 3)
        #expect(await source.sendAttempts == 3)
    }

    @Test func simultaneousRetriesWithSameIDProduceOneServerMessage() async throws {
        let clock = ControlledClock()
        let source = LoadableChat.Source(seedCount: 2, delay: .seconds(1), clock: clock)
        let first = Task { try await source.send(id: "same-id", text: "Hello") }
        let second = Task { try await source.send(id: "same-id", text: "Hello") }
        await clock.sleeps.waitForCalls(2)
        await clock.sleeps.complete(1, .success(()))
        await clock.sleeps.complete(0, .success(()))
        let a = try await first.value
        let b = try await second.value
        #expect(a == b)
        #expect(await source.messageCount == 3)
    }

    @Test func delayedPageIsAServerSnapshotBeforeAnIncomingMessage() async throws {
        let clock = ControlledClock()
        let source = LoadableChat.Source(seedCount: 10, pageSize: 5, delay: .seconds(1), clock: clock)
        let request = Task { try await source.fetchPage(query: .latest, cursor: nil, direction: .next) }
        await clock.sleeps.waitForCalls(1)
        let live = try await source.receiveGenerated()
        await clock.sleeps.complete(0, .success(()))
        let page = try await request.value
        #expect(live.sequence == 11)
        #expect(page.items.map(\.sequence) == Array(6...10))
        #expect(page.totalCount == 10)
        #expect(await source.messageCount == 11)
    }

    @Test func emptySourceAndInvalidPageSizeRemainUsable() async throws {
        let source = LoadableChat.Source(seedCount: -1, pageSize: 0, delay: .zero)
        let empty = try await source.fetchPage(query: .around(45), cursor: nil, direction: .next)
        #expect(empty.items.isEmpty)
        #expect(empty.previousCursor == nil)
        #expect(empty.nextCursor == nil)
        let message = try await source.receiveGenerated()
        #expect(message.sequence == 1)
        #expect(message.sender == .maya)
        let loaded = try await source.fetchPage(query: nil, cursor: nil, direction: .next)
        #expect(loaded.items == [message])
    }
}
#endif
