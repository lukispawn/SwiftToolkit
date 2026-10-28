import Loadable

struct Row: Identifiable, Sendable, Equatable {
    let id: Int
    let version: Int
    init(_ id: Int, version: Int = 0) { self.id = id; self.version = version }
}

actor ControlledCollectionSource: LoadableCollectionSource {
    typealias Item = Row
    typealias Cursor = Int
    typealias Query = String
    typealias Failure = TestFailure

    struct Call: Sendable, Equatable {
        let query: String?
        let cursor: Int?
        let direction: LoadableCollection.Direction
    }

    private(set) var calls: [Call] = []
    private var pending: [Int: CheckedContinuation<Result<Page, Failure>, Never>] = [:]
    private var observers: [(Int, CheckedContinuation<Void, Never>)] = []
    private(set) var cancelledCalls: Set<Int> = []

    func fetchPage(query: String?, cursor: Int?, direction: LoadableCollection.Direction) async throws(Failure) -> Page {
        let index = calls.count
        calls.append(Call(query: query, cursor: cursor, direction: direction))
        let result = await withCheckedContinuation { continuation in
            pending[index] = continuation
            let ready = observers.filter { calls.count >= $0.0 }
            observers.removeAll { calls.count >= $0.0 }
            ready.forEach { $0.1.resume() }
        }
        if Task.isCancelled { cancelledCalls.insert(index) }
        return try result.get()
    }

    func waitForCalls(_ count: Int) async {
        if calls.count >= count { return }
        await withCheckedContinuation { observers.append((count, $0)) }
    }

    func complete(_ index: Int, _ result: Result<Page, Failure>) {
        precondition(pending[index] != nil, "Complete only a request that has started")
        pending.removeValue(forKey: index)?.resume(returning: result)
    }
}
