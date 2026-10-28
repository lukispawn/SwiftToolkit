import Foundation
import Observation

@MainActor @Observable
public final class LoadableValueStore<Source: LoadableValueSource> {
    public typealias Value = Source.Value
    public typealias Query = Source.Query
    public typealias Failure = Source.Failure
    public typealias Snapshot = LoadableValue.Snapshot<Value, Failure, Query>

    public private(set) var snapshot: Snapshot {
        didSet { snapshotChannel.yield(snapshot) }
    }
    public var value: Value? { snapshot.value }
    public var lastError: Failure? { snapshot.phase.error }

    @ObservationIgnored private let source: Source
    @ObservationIgnored private var inFlight: RequestHandle<Value>?
    @ObservationIgnored private var hasSession = false
    @ObservationIgnored private var failedRequest: (query: Query?, retainingValue: Bool)?
    @ObservationIgnored private var isConstant = false
    @ObservationIgnored private let snapshotChannel = SnapshotChannel<Snapshot>()

    public init(source: Source) {
        self.source = source
        snapshot = .idle
    }

    public convenience init(source: Source, constantSnapshot: Snapshot) {
        self.init(source: source)
        setConstantState(constantSnapshot)
    }

    deinit { inFlight?.task.cancel() }

    /// Store-owned. New queries clear old data; the same query is ignored unless forced.
    public func start(query: Query? = nil, force: Bool = false) {
        guard !isConstant, force || !hasSession || snapshot.query != query else { return }
        begin(query: query, retainingValue: false)
    }

    public func startIfNeeded() {
        guard !isConstant, !snapshot.hasValue, inFlight == nil, lastError == nil else { return }
        begin(query: snapshot.query, retainingValue: false)
    }

    /// Store-owned reload, clearing the previous value immediately.
    public func reload() {
        guard !isConstant else { return }
        begin(query: snapshot.query, retainingValue: false)
    }

    /// Store-owned refresh. Cancelling its awaiting caller does not cancel the fetch.
    public func refresh() async {
        guard !isConstant else { return }
        let request = begin(query: snapshot.query, retainingValue: true)
        _ = await request.task.result
    }

    /// Retained, store-owned refresh for database events or other synchronous triggers.
    public func refreshInBackground() {
        guard !isConstant else { return }
        begin(query: snapshot.query, retainingValue: true)
    }

    /// Commits an authoritative local value and invalidates any older fetch.
    public func setValue(_ value: Value) {
        guard !isConstant else { return }
        cancelRequest()
        failedRequest = nil
        hasSession = true
        snapshot = .loaded(value, query: snapshot.query)
    }

    /// Independent subscribers receive the current snapshot immediately.
    /// The default buffer coalesces updates; use .unbounded when every transition matters.
    public func snapshots(
        bufferingPolicy: AsyncStream<Snapshot>.Continuation.BufferingPolicy = .bufferingNewest(1)
    ) -> AsyncStream<Snapshot> {
        snapshotChannel.stream(initial: snapshot, bufferingPolicy: bufferingPolicy)
    }

    /// Caller-owned load, suitable for .task(id:). Superseded loads throw CancellationError.
    @discardableResult
    public func load(query: Query? = nil, retainingValue: Bool = false) async throws -> Value {
        try Task.checkCancellation()
        if isConstant {
            if case .value(let value) = snapshot.content { return value }
            throw LoadableUsageError.constantHasNoValue
        }
        // Retaining data from a different query would mislabel it as current data.
        let request = begin(query: query, retainingValue: retainingValue && snapshot.query == query)
        return try await awaitRequest(request) { [weak self] id in self?.cancelRequest(id: id) }
    }

    public func retry() {
        guard !isConstant, inFlight == nil, let failedRequest else { return }
        begin(query: failedRequest.query, retainingValue: failedRequest.retainingValue)
    }

    public func cancelRequest() {
        guard let request = inFlight else { return }
        cancelRequest(id: request.id)
    }

    public func cancel() {
        cancelRequest()
        hasSession = false
        failedRequest = nil
    }

    public func setConstantState(_ snapshot: Snapshot) {
        cancel()
        isConstant = true
        self.snapshot = snapshot
    }

    // Internal barrier for deterministic engine tests; not part of the public API.
    var requestTask: Task<Value, any Error>? { inFlight?.task }

    @discardableResult
    private func begin(query: Query?, retainingValue: Bool) -> RequestHandle<Value> {
        cancelRequest()
        hasSession = true
        failedRequest = nil
        snapshot = Snapshot(
            content: retainingValue ? snapshot.content : .missing,
            phase: retainingValue && snapshot.hasValue ? .refreshing : .loading,
            query: query
        )
        let id = UUID()
        // Capture the source independently. Do not promote weak self across an await.
        let task = Task { [weak self, source] () throws -> Value in
            defer { self?.finish(id: id) }
            try Task.checkCancellation()
            guard self?.inFlight?.id == id else { throw CancellationError() }

            let result: Result<Value, Failure>
            do throws(Failure) { result = .success(try await source.fetch(query: query)) }
            catch { result = .failure(error) }

            try Task.checkCancellation()
            guard self?.inFlight?.id == id else { throw CancellationError() }
            switch result {
            case .success(let value):
                self?.snapshot = .loaded(value, query: query)
                return value
            case .failure(let error):
                if error is CancellationError { throw CancellationError() }
                self?.failedRequest = (query, retainingValue)
                self?.snapshot.phase = .failed(error)
                throw error
            }
        }
        let request = RequestHandle(id: id, task: task)
        inFlight = request
        return request
    }

    private func cancelRequest(id: UUID) {
        guard inFlight?.id == id else { return }
        inFlight?.task.cancel()
        finish(id: id)
    }

    private func finish(id: UUID) {
        guard inFlight?.id == id else { return }
        inFlight = nil
        if snapshot.phase.isLoading { snapshot.phase = .idle }
    }
}

public extension LoadableValueStore {
    convenience init<Value>(constant value: Value) where Source == LoadableValue.ConstantSource<Value> {
        self.init(source: .init(value), constantSnapshot: .loaded(value))
    }

    convenience init<Value, Failure>(operation: @escaping @Sendable () async throws(Failure) -> Value)
    where Source == LoadableValue.OperationSource<Value, Never, Failure> {
        self.init(source: .init { _ throws(Failure) in try await operation() })
    }
}
