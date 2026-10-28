import Foundation

/// Each subscriber has its own buffer. No task or subscription retains a store.
@MainActor
final class SnapshotChannel<Snapshot: Sendable> {
    private var continuations: [UUID: AsyncStream<Snapshot>.Continuation] = [:]

    func stream(
        initial: Snapshot,
        bufferingPolicy: AsyncStream<Snapshot>.Continuation.BufferingPolicy
    ) -> AsyncStream<Snapshot> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Snapshot>.makeStream(bufferingPolicy: bufferingPolicy)
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.continuations[id] = nil }
        }
        continuation.yield(initial)
        return stream
    }

    func yield(_ snapshot: Snapshot) {
        for continuation in continuations.values { continuation.yield(snapshot) }
    }

    deinit {
        for continuation in continuations.values { continuation.finish() }
    }
}
