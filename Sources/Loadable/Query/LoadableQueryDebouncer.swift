import Foundation
import Observation

/// Query scheduling is independent from fetching. Commit closures should capture
/// their owning model/store weakly when that owner also retains the debouncer.
@MainActor @Observable
public final class LoadableQueryDebouncer<Query: Sendable & Equatable> {
    public enum Submission: Sendable, Equatable {
        case debounced
        case immediate
    }

    public private(set) var pendingQuery: Query?
    public var isWaiting: Bool { pendingQuery != nil }

    @ObservationIgnored private let sleep: @Sendable () async throws -> Void
    @ObservationIgnored private let onCommit: @MainActor (Query, Submission) -> Void
    @ObservationIgnored private var pendingTask: Task<Void, Never>?
    @ObservationIgnored private var pendingID: UUID?

    public convenience init(
        delay: Duration = .milliseconds(400),
        onCommit: @escaping @MainActor (Query, Submission) -> Void
    ) {
        self.init(delay: delay, clock: ContinuousClock(), onCommit: onCommit)
    }

    public init<C: Clock>(
        delay: C.Duration, clock: C,
        onCommit: @escaping @MainActor (Query, Submission) -> Void
    ) {
        self.sleep = { try await clock.sleep(for: delay) }
        self.onCommit = onCommit
    }

    deinit { pendingTask?.cancel() }

    public func submit(_ query: Query) {
        cancelPending()
        let id = UUID()
        pendingID = id
        pendingQuery = query
        pendingTask = Task { [weak self, sleep] in
            guard !Task.isCancelled, self?.pendingID == id else { return }
            do { try await sleep() }
            catch {
                if self?.pendingID == id { self?.cancelPending() }
                return
            }
            guard !Task.isCancelled, self?.pendingID == id else { return }
            self?.pendingTask = nil
            self?.pendingID = nil
            self?.pendingQuery = nil
            self?.onCommit(query, .debounced)
        }
    }

    public func submitNow(_ query: Query) {
        cancelPending()
        onCommit(query, .immediate)
    }

    public func cancelPending() {
        pendingTask?.cancel()
        pendingTask = nil
        pendingID = nil
        pendingQuery = nil
    }

    var scheduledTask: Task<Void, Never>? { pendingTask }
}
