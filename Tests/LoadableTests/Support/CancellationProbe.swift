import Loadable

/// Cancellation-aware suspension with an explicit registration barrier; no clock involved.
actor CancellationProbe {
    private var pending: CheckedContinuation<Void, any Error>?
    private var started = false
    private var observers: [CheckedContinuation<Void, Never>] = []

    func suspend() async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                started = true
                if Task.isCancelled { continuation.resume(throwing: CancellationError()) }
                else { pending = continuation }
                observers.forEach { $0.resume() }
                observers.removeAll()
            }
        } onCancel: {
            Task { await self.cancel() }
        }
    }

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { observers.append($0) }
    }

    private func cancel() {
        pending?.resume(throwing: CancellationError())
        pending = nil
    }
}

struct CooperativeValueSource: LoadableValueSource {
    typealias Value = Int
    typealias Query = Never
    let probe: CancellationProbe
    func fetch(query: Never?) async throws -> Int {
        try await probe.suspend()
        return 1
    }
}

struct CooperativePageSource: LoadableCollectionSource {
    typealias Item = Row
    typealias Cursor = Never
    typealias Query = Never
    let probe: CancellationProbe
    func fetchPage(query: Never?, cursor: Never?, direction: LoadableCollection.Direction) async throws -> Page {
        try await probe.suspend()
        return .init(items: [])
    }
}
