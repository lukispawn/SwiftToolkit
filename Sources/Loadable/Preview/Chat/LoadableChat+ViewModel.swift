#if DEBUG
import Foundation
import Observation

extension LoadableChat {
    @MainActor @Observable
    final class ViewModel {
        let history: Store
        let source: Source
        let isFrozen: Bool
        var draft = ""
        var followsNewMessages = true
        private(set) var outbox: [Message] = []
        private(set) var eventError: String?
        @ObservationIgnored private let initialQuery: Query
        @ObservationIgnored private var localSequence = 0
        @ObservationIgnored private var operations: [UUID: Task<Void, Never>] = [:]
        @ObservationIgnored private var sendingTokens: [String: UUID] = [:]

        init(source: Source, window: Window = .middle, frozen: Store.Snapshot? = nil) {
            self.source = source
            initialQuery = window.query
            isFrozen = frozen != nil
            history = frozen.map { Store(source: source, constantSnapshot: $0) }
                ?? Store(source: source, configuration: .init(prefetchThreshold: 0))
        }

        convenience init(scenario: Scenario = .normal, window: Window = .middle,
                         latency: DemoLatency = .normal) {
            self.init(source: Source(seedCount: scenario.seedCount, failures: scenario.failures,
                                     delay: latency.duration), window: window)
        }

        convenience init(previewSnapshot: Store.Snapshot, outbox: [Message]) {
            self.init(source: Source(), window: .latest, frozen: previewSnapshot)
            self.outbox = outbox
        }

        deinit { for task in operations.values { task.cancel() } }
    }
}

// MARK: - Computed: Conversation

extension LoadableChat.ViewModel {
    var isAtLatestWindow: Bool { history.snapshot.hasLoaded && history.snapshot.nextCursor == nil }
    var canSend: Bool { !isFrozen && history.snapshot.hasLoaded && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var outsideWindowCount: Int {
        guard !isAtLatestWindow else { return 0 }
        let ids = Set(history.items.map(\.id))
        return outbox.filter { !ids.contains($0.id) }.count
    }

    /// A view projection, not a membership mutation of the paginated store.
    var timeline: [LoadableChat.Message] {
        guard isAtLatestWindow else { return history.items }
        var byID = Dictionary(uniqueKeysWithValues: history.items.map { ($0.id, $0) })
        for item in outbox where byID[item.id] == nil || item.delivery != .sent {
            byID[item.id] = item
        }
        return byID.values.sorted { $0.sequence < $1.sequence }
    }
}

// MARK: - Lifecycle

extension LoadableChat.ViewModel {
    func startIfNeeded() {
        guard !isFrozen, !history.snapshot.hasLoaded, !history.snapshot.phase.isLoading,
              history.lastError == nil else { return }
        history.start(query: history.snapshot.query ?? initialQuery, force: true)
    }

    func jumpToLatest() {
        guard !isFrozen else { return }
        followsNewMessages = true
        history.start(query: .latest, force: true)
    }
}

// MARK: - Composing and delivery

extension LoadableChat.ViewModel {
    func retryAction(for id: String) -> (() -> Void)? {
        guard !isFrozen else { return nil }
        return { [weak self] in _ = self?.retrySend(id: id) }
    }

    func generateDraft() {
        guard !isFrozen else { return }
        draft = LoadableChat.Message.generated(localSequence + 5, sender: .me).text
    }

    @discardableResult
    func sendDraft() -> Task<Void, Never>? {
        guard canSend else { return nil }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = ""
        localSequence += 1
        let item = LoadableChat.Message(id: "local-\(UUID().uuidString)", sequence: Int.max / 2 + localSequence,
                                       text: text, sender: .me, sentAt: Date(), delivery: .sending)
        outbox.append(item)
        return startSend(item)
    }

    @discardableResult
    func retrySend(id: String) -> Task<Void, Never>? {
        guard !isFrozen, sendingTokens[id] == nil,
              let index = outbox.firstIndex(where: { $0.id == id }),
              case .failed = outbox[index].delivery else { return nil }
        outbox[index].delivery = .sending
        return startSend(outbox[index])
    }
}

// MARK: - Incoming messages

extension LoadableChat.ViewModel {
    @discardableResult
    func receiveGenerated() -> Task<Void, Never>? {
        guard !isFrozen else { return nil }
        let operation = UUID()
        let task = Task { [weak self, source] in
            defer { self?.operations[operation] = nil }
            do {
                let item = try await source.receiveGenerated()
                guard !Task.isCancelled else { return }
                self?.outbox.append(item)
                self?.eventError = nil
            } catch {
                guard !Task.isCancelled else { return }
                self?.eventError = error.localizedDescription
            }
        }
        operations[operation] = task
        return task
    }
}

// MARK: - Cancellation

extension LoadableChat.ViewModel {
    func stop() {
        guard !isFrozen else { return }
        history.cancelRequest()
        for task in operations.values { task.cancel() }
        operations.removeAll()
        sendingTokens.removeAll()
        for index in outbox.indices where outbox[index].delivery == .sending {
            outbox[index].delivery = .failed("Sending was cancelled. Retry to continue.")
        }
    }
}

// MARK: - Delivery helpers

extension LoadableChat.ViewModel {
    private func startSend(_ message: LoadableChat.Message) -> Task<Void, Never> {
        let operation = UUID()
        sendingTokens[message.id] = operation
        let task = Task { [weak self, source] in
            defer {
                self?.operations[operation] = nil
                if self?.sendingTokens[message.id] == operation { self?.sendingTokens[message.id] = nil }
            }
            do {
                let delivered = try await source.send(id: message.id, text: message.text)
                guard !Task.isCancelled else { return }
                self?.replaceOutgoing(delivered)
            } catch {
                guard !Task.isCancelled else { return }
                self?.failOutgoing(id: message.id, error: error.localizedDescription)
            }
        }
        operations[operation] = task
        return task
    }

    private func replaceOutgoing(_ delivered: LoadableChat.Message) {
        guard let index = outbox.firstIndex(where: { $0.id == delivered.id }) else { return }
        outbox[index] = delivered
    }

    private func failOutgoing(id: String, error: String) {
        guard let index = outbox.firstIndex(where: { $0.id == id }) else { return }
        outbox[index].delivery = .failed(error)
    }
}
#endif
