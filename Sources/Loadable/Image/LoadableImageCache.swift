import Foundation

/// In-memory image cache shared by `CachedImageSource`s.
///
/// Isolation: the actor owns the in-flight table, the slot queue and the `NSCache`.
/// `load` closures run outside the actor. Requests for the same `(namespace, key)` share one load;
/// the load is cancelled only when every waiter has cancelled. At most `maxConcurrentLoads` loads
/// run at once, the rest wait FIFO, and a cancelled queued load leaves the queue. Errors and
/// cancellations are never cached. The byte limit is a hint to `NSCache`, which the system may
/// also purge under memory pressure.
public actor LoadableImageCache {
    public static let shared = LoadableImageCache()

    public static var defaultByteLimit: Int {
        #if os(macOS)
        256 * 1024 * 1024
        #else
        64 * 1024 * 1024
        #endif
    }

    // Safety: all stored properties are immutable `let`s, so sharing across tasks is safe.
    private final class Entry: NSObject, @unchecked Sendable {
        let namespace: String
        let key: AnyHashable
        init(namespace: String, key: AnyHashable) {
            self.namespace = namespace
            self.key = key
        }
        override var hash: Int {
            var hasher = Hasher()
            hasher.combine(namespace)
            hasher.combine(key)
            return hasher.finalize()
        }
        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? Entry else { return false }
            return namespace == other.namespace && key == other.key
        }
    }

    private final class Box: Sendable {
        let value: LoadableImageValue
        init(_ value: LoadableImageValue) { self.value = value }
    }

    private struct Flight {
        let id: UUID
        let task: Task<LoadableImageValue, any Error>
        var waiters: Int
    }

    private struct SlotWaiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, any Error>
    }

    // Safety: Apple documents NSCache as safe to use from multiple threads, and `cache` is a `let`.
    private final class Storage: @unchecked Sendable {
        let cache = NSCache<Entry, Box>()
    }

    private nonisolated let storage = Storage()
    private var flights: [Entry: Flight] = [:]
    private var slotWaiters: [SlotWaiter] = []
    private var activeLoads = 0
    private let maxConcurrentLoads: Int

    public init(byteLimit: Int = LoadableImageCache.defaultByteLimit, maxConcurrentLoads: Int = 2) {
        storage.cache.totalCostLimit = byteLimit
        self.maxConcurrentLoads = max(1, maxConcurrentLoads)
    }

    public func image<Key: Hashable & Sendable>(
        for key: Key,
        namespace: String,
        load: @escaping @Sendable () async throws -> LoadableImageValue
    ) async throws -> LoadableImageValue {
        try Task.checkCancellation()
        let entry = Entry(namespace: namespace, key: AnyHashable(key))
        if let cached = storage.cache.object(forKey: entry) { return cached.value }

        let flightID: UUID
        let task: Task<LoadableImageValue, any Error>
        if var flight = flights[entry] {
            flight.waiters += 1
            flights[entry] = flight
            flightID = flight.id
            task = flight.task
        } else {
            flightID = UUID()
            task = Task { [self] in
                try await acquireSlot()
                defer { releaseSlot() }
                try Task.checkCancellation()
                let value = try await load()
                try Task.checkCancellation()
                storage.cache.setObject(Box(value), forKey: entry, cost: value.cost)
                return value
            }
            flights[entry] = Flight(id: flightID, task: task, waiters: 1)
            Task { [self] in
                _ = try? await task.value
                finish(entry, flightID: flightID)
            }
        }

        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            Task { await self.waiterCancelled(entry, flightID: flightID) }
        }
    }

    /// Synchronous lookup that never starts a load.
    public nonisolated func cachedImage<Key: Hashable & Sendable>(for key: Key, namespace: String) -> LoadableImageValue? {
        storage.cache.object(forKey: Entry(namespace: namespace, key: AnyHashable(key)))?.value
    }

    public func removeAll() {
        storage.cache.removeAllObjects()
    }

    // MARK: - Flights

    private func finish(_ entry: Entry, flightID: UUID) {
        if flights[entry]?.id == flightID { flights[entry] = nil }
    }

    private func waiterCancelled(_ entry: Entry, flightID: UUID) {
        guard var flight = flights[entry], flight.id == flightID else { return }
        flight.waiters -= 1
        if flight.waiters <= 0 {
            flights[entry] = nil
            flight.task.cancel()
        } else {
            flights[entry] = flight
        }
    }

    // MARK: - Concurrency limit

    private func acquireSlot() async throws {
        try Task.checkCancellation()
        if activeLoads < maxConcurrentLoads {
            activeLoads += 1
            return
        }
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                slotWaiters.append(SlotWaiter(id: id, continuation: continuation))
            }
        } onCancel: {
            Task { await self.cancelSlotWaiter(id) }
        }
    }

    private func releaseSlot() {
        if slotWaiters.isEmpty {
            activeLoads -= 1
        } else {
            // The slot passes straight to the next waiter, so activeLoads is unchanged.
            slotWaiters.removeFirst().continuation.resume()
        }
    }

    private func cancelSlotWaiter(_ id: UUID) {
        guard let index = slotWaiters.firstIndex(where: { $0.id == id }) else { return }
        slotWaiters.remove(at: index).continuation.resume(throwing: CancellationError())
    }
}
