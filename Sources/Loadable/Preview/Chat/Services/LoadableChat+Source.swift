#if DEBUG
import Foundation

extension LoadableChat {
    /// Local simulated server. Cursors are sequence boundaries, not mutable array offsets.
    actor Source: LoadableCollectionSource {
        typealias Item = Message
        typealias Query = LoadableChat.Query
        typealias Cursor = LoadableChat.Cursor

        struct Call: Sendable, Equatable {
            let query: Query?
            let cursor: Cursor?
            let direction: LoadableCollection.Direction
        }

        private let pageSize: Int
        private let failurePlan: Set<LoadableChat.Failure>
        private let sleep: @Sendable () async throws -> Void
        private var failuresUsed: Set<LoadableChat.Failure> = []
        private var messages: [Item]
        private(set) var calls: [Call] = []
        private(set) var sendAttempts = 0

        init(seedCount: Int = 90, pageSize: Int = 12, failures: Set<LoadableChat.Failure> = [],
             delay: Duration = .milliseconds(600)) {
            self.init(seedCount: seedCount, pageSize: pageSize, failures: failures,
                      sleep: { try await Task.sleep(for: delay) })
        }

        init<C: Clock>(seedCount: Int = 90, pageSize: Int = 12, failures: Set<LoadableChat.Failure> = [],
                       delay: C.Duration, clock: C) {
            self.init(seedCount: seedCount, pageSize: pageSize, failures: failures,
                      sleep: { try await clock.sleep(for: delay) })
        }

        private init(seedCount: Int, pageSize: Int, failures: Set<LoadableChat.Failure>,
                     sleep: @escaping @Sendable () async throws -> Void) {
            self.pageSize = max(1, pageSize)
            failurePlan = failures
            self.sleep = sleep
            messages = (0..<max(0, seedCount)).map { Item.generated($0 + 1) }
        }

        func fetchPage(query: Query?, cursor: Cursor?, direction: LoadableCollection.Direction) async throws -> Page {
            try Task.checkCancellation()
            calls.append(.init(query: query, cursor: cursor, direction: direction))
            let operation: LoadableChat.Failure = cursor == nil ? .initial : direction == .previous ? .older : .newer
            let shouldFail = consumeFailure(operation)
            // Capture a server response before suspension to exercise send/page overlap.
            let page = makePage(query: query, cursor: cursor)
            try await sleep()
            try Task.checkCancellation()
            if shouldFail { throw operation }
            return page
        }

        /// Reusing a client ID after cancellation or retry never creates a duplicate.
        func send(id: String, text: String) async throws -> Item {
            try Task.checkCancellation()
            sendAttempts += 1
            if let existing = messages.first(where: { $0.id == id }) { return existing }
            let shouldFail = consumeFailure(.send)
            try await sleep()
            try Task.checkCancellation()
            if let existing = messages.first(where: { $0.id == id }) { return existing }
            if shouldFail { throw LoadableChat.Failure.send }
            let sequence = (messages.last?.sequence ?? 0) + 1
            let message = Item(id: id, sequence: sequence, text: text, sender: .me,
                               sentAt: Item.baseDate.addingTimeInterval(Double(sequence * 180)))
            messages.append(message)
            return message
        }

        func receiveGenerated() throws -> Item {
            try Task.checkCancellation()
            let message = Item.generated((messages.last?.sequence ?? 0) + 1, sender: .maya)
            messages.append(message)
            return message
        }

        var messageCount: Int { messages.count }

        private func consumeFailure(_ operation: LoadableChat.Failure) -> Bool {
            failurePlan.contains(operation) && failuresUsed.insert(operation).inserted
        }

        private func makePage(query: Query?, cursor: Cursor?) -> Page {
            let items: [Item]
            switch cursor {
            case .before(let boundary):
                items = Array(messages.filter { $0.sequence < boundary }.suffix(pageSize))
            case .after(let boundary):
                items = Array(messages.filter { $0.sequence > boundary }.prefix(pageSize))
            case nil:
                switch query ?? .latest {
                case .latest: items = Array(messages.suffix(pageSize))
                case .around(let target):
                    let index = messages.firstIndex { $0.sequence >= target } ?? messages.count
                    let start = max(0, min(messages.count - pageSize, index - pageSize / 2))
                    items = Array(messages.dropFirst(start).prefix(pageSize))
                }
            }
            return Page(items: items,
                        nextCursor: items.last.flatMap { last in
                            messages.last.map { $0.sequence > last.sequence ? .after(last.sequence) : nil } ?? nil
                        },
                        previousCursor: items.first.flatMap { first in
                            messages.first.map { $0.sequence < first.sequence ? .before(first.sequence) : nil } ?? nil
                        }, totalCount: messages.count)
        }
    }
}
#endif
