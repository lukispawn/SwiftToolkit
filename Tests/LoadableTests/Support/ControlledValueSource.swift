import Loadable

enum TestFailure: Error, Equatable {
    case offline
    case rejected
}

/// Deliberately ignores cancellation until the test supplies a result.
actor ControlledValueSource<Value: Sendable, Query: Sendable & Equatable>: LoadableValueSource {
    typealias Failure = TestFailure
    private(set) var queries: [Query?] = []
    private var pending: [Int: CheckedContinuation<Result<Value, Failure>, Never>] = [:]
    private var observers: [(Int, CheckedContinuation<Void, Never>)] = []
    private(set) var cancelledCalls: Set<Int> = []

    func fetch(query: Query?) async throws(Failure) -> Value {
        let index = queries.count
        queries.append(query)
        let result = await withCheckedContinuation { continuation in
            pending[index] = continuation
            let ready = observers.filter { queries.count >= $0.0 }
            observers.removeAll { queries.count >= $0.0 }
            ready.forEach { $0.1.resume() }
        }
        if Task.isCancelled { cancelledCalls.insert(index) }
        return try result.get()
    }

    func waitForCalls(_ count: Int) async {
        if queries.count >= count { return }
        await withCheckedContinuation { observers.append((count, $0)) }
    }

    func complete(_ index: Int, _ result: Result<Value, Failure>) {
        precondition(pending[index] != nil, "Complete only a request that has started")
        pending.removeValue(forKey: index)?.resume(returning: result)
    }
}
